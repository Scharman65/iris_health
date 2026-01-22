import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class AiClient {
  AiClient._();
  static final instance = AiClient._();

  // Можно переопределить флагом: --dart-define=AI_ENDPOINT=https://host/analyze
  static final String _endpoint =
      const String.fromEnvironment('AI_ENDPOINT', defaultValue: 'http://127.0.0.1:8000/analyze');

  Future<Map<String, dynamic>> analyze({
    required String examId,
    required String side, // 'left' | 'right'
    required String imagePath,
  }) async {
    final uri = Uri.parse(_endpoint);
    final req = http.MultipartRequest('POST', uri)
      ..fields['exam_id'] = examId
      ..fields['side'] = side
      ..files.add(await http.MultipartFile.fromPath('image', imagePath));

    final resp = await http.Response.fromStream(await req.send());
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException('AI ${resp.statusCode}: ${resp.body}');
    }
    final json = jsonDecode(resp.body);
    if (json is Map<String, dynamic>) return json;
    return {'raw': json};
  }
}
