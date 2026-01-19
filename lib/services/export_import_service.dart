import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_selector/file_selector.dart';
import 'package:hive/hive.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/diagnosis_model.dart';

class ExportImportService {
  static const int formatVersion = 1;

  static String _safe(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  static Future<Directory> _tmpDir() async {
    final d = await getTemporaryDirectory();
    final dir = Directory(p.join(d.path, 'irida_export'));
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    return dir;
  }

  static Map<String, dynamic> _manifest({required String appVersion, required int count}) {
    return {
      'formatVersion': formatVersion.toString(),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'appVersion': appVersion,
      'diagnosesCount': count,
      'notes': 'IRIDA export v1 (cropped images only)',
    };
  }

  static int _toInt(dynamic v, {int def = 0}) {
    if (v == null) return def;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? def;
  }

  static String _toStr(dynamic v, {String def = ''}) {
    if (v == null) return def;
    return v.toString();
  }

  static int _toMillis(dynamic v) {
    if (v == null) return DateTime.now().millisecondsSinceEpoch;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is DateTime) return v.toUtc().millisecondsSinceEpoch;
    final s = v.toString();
    final dt = DateTime.tryParse(s);
    if (dt != null) return dt.toUtc().millisecondsSinceEpoch;
    return int.tryParse(s) ?? DateTime.now().millisecondsSinceEpoch;
  }

  static DateTime _millisToLocal(dynamic v) {
    final ms = _toInt(v, def: DateTime.now().millisecondsSinceEpoch);
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }

  /// Export: сохраняем diagnoses.json + images/<id>/left.jpg|right.jpg
  /// Важно: age/date берём из Diagnosis как есть — типы подгоним на следующем шаге под твою модель.
  static Future<String> exportZip({required String appVersion}) async {
    final box = Hive.box<Diagnosis>('diagnoses');
    final all = box.values.toList().cast<Diagnosis>();

    final tmp = await _tmpDir();
    final imagesDir = Directory(p.join(tmp.path, 'images'));
    imagesDir.createSync(recursive: true);

    final items = <Map<String, dynamic>>[];

    for (final d in all) {
      final idSafe = _safe(d.id.toString());

      final leftSrc = File(d.leftEyeImagePath);
      final rightSrc = File(d.rightEyeImagePath);

      final dstDir = Directory(p.join(imagesDir.path, idSafe));
      dstDir.createSync(recursive: true);

      final leftDst = File(p.join(dstDir.path, 'left.jpg'));
      final rightDst = File(p.join(dstDir.path, 'right.jpg'));

      if (leftSrc.existsSync()) leftDst.writeAsBytesSync(leftSrc.readAsBytesSync(), flush: true);
      if (rightSrc.existsSync()) rightDst.writeAsBytesSync(rightSrc.readAsBytesSync(), flush: true);

      // В JSON всегда кладём dateMillis (int) и age как строку (универсально).
      final dynamic ageDyn = (d as dynamic).age;
      final dynamic dateDyn = ((d as dynamic).dateTime ?? (d as dynamic).date);

      items.add({
        'id': d.id.toString(),
        'dateMillis': _toMillis(dateDyn),
        'age': _toStr(ageDyn),
        'gender': d.gender.name,
        'leftEyeImagePath': p.posix.join('images', idSafe, 'left.jpg'),
        'rightEyeImagePath': p.posix.join('images', idSafe, 'right.jpg'),
        'ai': d.aiResultJson,
      });
    }

    File(p.join(tmp.path, 'manifest.json'))
        .writeAsStringSync(jsonEncode(_manifest(appVersion: appVersion, count: all.length)), flush: true);

    File(p.join(tmp.path, 'diagnoses.json'))
        .writeAsStringSync(jsonEncode({'items': items}), flush: true);

    final zipPath = p.join(tmp.path, 'irida_export_v1.zip');
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    encoder.addFile(File(p.join(tmp.path, 'manifest.json')));
    encoder.addFile(File(p.join(tmp.path, 'diagnoses.json')));
    encoder.addDirectory(imagesDir, includeDirName: true);
    encoder.close();

    final bytes = File(zipPath).readAsBytesSync();
    final name = 'irida_export_${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}.zip';

    final mime = lookupMimeType(name) ?? 'application/zip';
    final xfile = XFile.fromData(bytes, name: name, mimeType: mime);

    final save = await getSaveLocation(suggestedName: name);
    if (save == null) throw Exception('Export cancelled');

    final out = File(save.path);
    out.writeAsBytesSync(await xfile.readAsBytes(), flush: true);
    return out.path;
  }

  static Future<int> importZip({bool merge = true}) async {
    final typeGroup = XTypeGroup(label: 'IRIDA ZIP', extensions: const ['zip']);
    final xfile = await openFile(acceptedTypeGroups: [typeGroup]);
    if (xfile == null) throw Exception('Import cancelled');

    final bytes = await xfile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    Map<String, dynamic>? manifest;
    List<dynamic> items = <dynamic>[];

    final tmp = await _tmpDir();

    for (final f in archive) {
      if (!f.isFile) continue;
      final name = f.name.replaceAll('\\', '/');

      if (name.toString() == 'manifest.json') {
        manifest = jsonDecode(utf8.decode(f.content as List<int>)) as Map<String, dynamic>;
      } else if (name.toString() == 'diagnoses.json') {
        final m = jsonDecode(utf8.decode(f.content as List<int>)) as Map<String, dynamic>;
        items = (m['items'] is List) ? (m['items'] as List) : <dynamic>[];
      } else if (name.startsWith('images/')) {
        final out = File(p.join(tmp.path, name));
        out.parent.createSync(recursive: true);
        out.writeAsBytesSync(f.content as List<int>, flush: true);
      }
    }

    if (manifest == null) throw Exception('Invalid ZIP: missing manifest.json');

    final fv = (manifest['formatVersion'] is num)
        ? (manifest['formatVersion'] as num).toInt()
        : int.tryParse(manifest['formatVersion']?.toString() ?? '') ?? 0;
    if (fv != formatVersion) throw Exception('Unsupported export formatVersion=$fv');

    final box = Hive.box<Diagnosis>('diagnoses');

    final appDir = await getApplicationDocumentsDirectory();
    final examsDir = Directory(p.join(appDir.path, 'exams'));
    examsDir.createSync(recursive: true);

    int imported = 0;

    for (final raw in items) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);

      final id = (m['id'] ?? '').toString();
      if (id.isEmpty) continue;

      if (!merge && box.values.any((e) => e.id.toString() == id)) continue;

      final genderStr = (m['gender'] ?? '').toString();
      final gender = Gender.values.where((g) => g.name == genderStr).isNotEmpty
          ? Gender.values.firstWhere((g) => g.name == genderStr)
          : Gender.male;

      final idSafe = _safe(id);

      final srcDir = Directory(p.join(tmp.path, 'images', idSafe));
      final dstDir = Directory(p.join(examsDir.path, idSafe));
      dstDir.createSync(recursive: true);

      final leftSrc = File(p.join(srcDir.path, 'left.jpg'));
      final rightSrc = File(p.join(srcDir.path, 'right.jpg'));

      final leftDst = File(p.join(dstDir.path, 'left.jpg'));
      final rightDst = File(p.join(dstDir.path, 'right.jpg'));

      if (leftSrc.existsSync()) leftDst.writeAsBytesSync(leftSrc.readAsBytesSync(), flush: true);
      if (rightSrc.existsSync()) rightDst.writeAsBytesSync(rightSrc.readAsBytesSync(), flush: true);

      // ВАЖНО: дальше мы подгоним под твою модель Diagnosis (age/date поля).
      // Пока создаём через dynamic, чтобы компилятор подсказал точные именованные параметры.
      final ageStr = _toStr(m['age']);
      final dt = _millisToLocal(m['dateMillis']);

      final diag = (Diagnosis as dynamic)(
        id: id,
        age: ageStr,
        gender: gender,
        leftEyeImagePath: leftDst.path,
        rightEyeImagePath: rightDst.path,
        dateTime: dt,
        aiResultJson: m['ai']?.toString() ?? '',
      ) as Diagnosis;

      final existingKey = box.keys.cast<dynamic>().firstWhere(
        (k) => (box.get(k)?.id.toString() == id),
        orElse: () => null,
      );

      if (existingKey != null) {
        await box.put(existingKey, diag);
      } else {
        await box.add(diag);
      }
      imported++;
    }

    return imported;
  }
}
