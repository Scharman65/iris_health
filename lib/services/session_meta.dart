import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SessionMeta {
  static Future<String> _dir(String examId) async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/iris_sessions/$examId');
    if (!await d.exists()) await d.create(recursive: true);
    return d.path;
  }

  static Future<File> _file(String examId) async {
    final d = await _dir(examId);
    return File('$d/session.json');
  }

  static Future<void> write({
    required String examId,
    required int age,
    required String gender, // 'male' | 'female'
    String? task,
  }) async {
    final f = await _file(examId);
    Map<String,dynamic> m = {};
    if (await f.exists()) {
      try { m = jsonDecode(await f.readAsString()); } catch(_) {}
    }
    m['examId']=examId;
    m['age']=age;
    m['gender']=gender;
    m['task']=task ?? 'Используя все доступные атласы по иридодиагностике и всю доступную литературу на русском, английском и других языках по иридодиагностике, на основании радужки левого и правого глаза, возраста и пола выдать иридодиагностическое заключение.';
    m['updatedAt']=DateTime.now().toIso8601String();
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(m));
  }

  static Future<Map<String,dynamic>> read(String examId) async {
    final f = await _file(examId);
    if (!await f.exists()) return {};
    try { return jsonDecode(await f.readAsString()); } catch(_) { return {}; }
  }

  static Future<void> markAiSent(String examId) async {
    final f = await _file(examId);
    Map<String,dynamic> m = {};
    if (await f.exists()) {
      try { m = jsonDecode(await f.readAsString()); } catch(_) {}
    }
    m['ai_sent']=true;
    m['ai_sent_at']=DateTime.now().toIso8601String();
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(m));
  }
}
