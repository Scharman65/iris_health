import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'hive_bootstrap.dart';

class ExamStore {
  static Box? _box;

  static Future<Box> _openBox() async {
    if (_box != null) return _box!;
    _box = await HiveBootstrap.openBox('exams_index');
    return _box!;
  }

  static Future<Directory> sessionDir(String examId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/iris_sessions/$examId');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// ЯВНО: сохраняем как left или right; возвращает путь
  static Future<String> addPhotoSide({
    required String examId,
    required String srcPath,
    required String side, // 'left' | 'right'
  }) async {
    final box = await _openBox();
    final dir = await sessionDir(examId);

    final m = Map<String, dynamic>.from(box.get(examId, defaultValue: {
      'examId': examId,
      'createdAt': DateTime.now().toIso8601String(),
      'leftPath': null,
      'rightPath': null,
      'leftResult': null,
      'rightResult': null,
    }));

    final ts = DateTime.now().millisecondsSinceEpoch
    ;
    final name = '${side == 'left' ? 'left' : 'right'}-$ts.jpg';
    final dst = File('${dir.path}/$name');
    await File(srcPath).copy(dst.path);

    if (side == 'left') {
      m['leftPath'] = dst.path;
    } else {
      m['rightPath'] = dst.path;
    }
    m['updatedAt'] = DateTime.now().toIso8601String();

    await box.put(examId, m);
    return dst.path;
  }

  static Future<void> putAiResult({
    required String examId,
    required String side, // 'left' | 'right'
    required Map<String, dynamic> result,
  }) async {
    final box = await _openBox();
    final m = Map<String, dynamic>.from(box.get(examId));
    m[side == 'left' ? 'leftResult' : 'rightResult'] = result;
    m['updatedAt'] = DateTime.now().toIso8601String();
    await box.put(examId, m);
  }

  static Future<List<Map<String, dynamic>>> listExams() async {
    final box = await _openBox();
    return box.values
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList()
      ..sort((a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));
  }
}
