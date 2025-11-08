import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'session_meta.dart';

class AiQueue {
  AiQueue._();
  static final instance = AiQueue._();
  static final String _endpoint =
      const String.fromEnvironment('AI_ENDPOINT', defaultValue: 'http://127.0.0.1:8000/analyze');

  static Future<Directory> _baseDir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/iris_sessions');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Сканирует все <examId>, где есть и left-*.jpg, и right-*.jpg,
  /// читает session.json (age, gender, task) и отправляет одной формой.
  static Future<void> scanAndSendAll() async {
    final dir = await _baseDir();
    final subs = await dir.list().where((e) => e is Directory).cast<Directory>().toList();

    for (final sess in subs) {
      final examId = sess.path.split('/').last;
      final left = await _findLast(sess, prefix: 'left-');
      final right = await _findLast(sess, prefix: 'right-');
      if (left == null || right == null) continue;

      final meta = await SessionMeta.read(examId);
      if (meta['ai_sent'] == true) continue;

      final age = meta['age']?.toString() ?? '';
      final gender = meta['gender']?.toString() ?? '';
      final task = meta['task']?.toString() ?? '';

      try {
        final uri = Uri.parse(_endpoint);
        final req = http.MultipartRequest('POST', uri)
          ..fields['exam_id'] = examId
          ..fields['age'] = age
          ..fields['gender'] = gender
          ..fields['task'] = task
          ..files.add(await http.MultipartFile.fromPath('left', left.path))
          ..files.add(await http.MultipartFile.fromPath('right', right.path));

        final resp = await http.Response.fromStream(await req.send());
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          await SessionMeta.markAiSent(examId);
        } else {
          // лог, но не падаем
          // print('AI ${resp.statusCode}: ${resp.body}');
        }
      } catch (e) {
        // сеть/сервер недоступны — оставим на затем
        // print('AI send error: $e');
      }
    }
  }

  static Future<File?> _findLast(Directory d, {required String prefix}) async {
    final files = await d
        .list()
        .where((e) => e is File && e.path.split('/').last.startsWith(prefix))
        .cast<File>()
        .toList();
    if (files.isEmpty) return null;
    files.sort((a,b)=>a.path.compareTo(b.path));
    return files.last;
  }
}
