import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DiagnosisService {
  /// Можно переопределить из запуска:
  /// flutter run ... --dart-define=AI_ENDPOINT=http://<ip>:8000/analyze
  static final String aiEndpoint = const String.fromEnvironment(
    'AI_ENDPOINT',
    defaultValue: 'http://127.0.0.1:8000/analyze',
  );

  static Future<Map<String, dynamic>> analyzeAndSave({
    required String examId,
    required String leftPath,
    required String rightPath,
    int? age,
    String? gender,
  }) async {
    // Сохраним метаданные локально
    final appDir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(appDir.path, 'exams', examId));
    await folder.create(recursive: true);

    final meta = <String, dynamic>{
      'examId': examId,
      'leftPath': leftPath,
      'rightPath': rightPath,
      'createdAt': DateTime.now().toIso8601String(),
    };
    if (age != null) meta['age'] = age;
    if (gender != null && gender.isNotEmpty) meta['gender'] = gender;

    final metaFile = File(p.join(folder.path, 'record.json'));
    await metaFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(meta),
      flush: true,
    );

    // Попробуем вызвать ИИ; если не доступен — заглушка
    try {
      final uri = Uri.parse(aiEndpoint);
      final req = http.MultipartRequest('POST', uri);
      req.fields['examId'] = examId;
      if (age != null) req.fields['age'] = age.toString();
      if (gender != null && gender.isNotEmpty) req.fields['gender'] = gender;
      req.files.add(await http.MultipartFile.fromPath('left', leftPath));
      req.files.add(await http.MultipartFile.fromPath('right', rightPath));

      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode == 200) {
        final data = json.decode(body) as Map<String, dynamic>;
        // сохраним ответ
        final resFile = File(p.join(folder.path, 'ai_result.json'));
        await resFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(data),
          flush: true,
        );
        return data;
      } else {
        return _stubResult('AI HTTP ${streamed.statusCode}', examId);
      }
    } catch (_) {
      return _stubResult('AI not reachable', examId);
    }
  }

  static Map<String, dynamic> _stubResult(String reason, String examId) {
    return {
      'examId': examId,
      'status': 'stub',
      'reason': reason,
      'findings': [
        {'zone': 'Digestive', 'score': 0.18},
        {'zone': 'Liver', 'score': 0.27},
        {'zone': 'Kidney', 'score': 0.12},
      ],
      'summary':
          'Предварительная заглушка: для точного анализа подключите AI-сервер.',
    };
  }
}
