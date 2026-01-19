import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:iris_health/services/ai_models.dart';

class AiClientCli {
  final String baseUrl;

  AiClientCli({required String baseUrl}) : baseUrl = _normalize(baseUrl);

  static String _normalize(String s) {
    final t = s.trim();
    if (t.isEmpty) return '';
    return t.replaceAll(RegExp(r'/+$'), '');
  }

  Uri _u(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$p');
  }

  Future<bool> health() async {
    try {
      final r = await http.get(_u('/health')).timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<AiAnalyzeResponse> analyzeEye({
    required File file,
    required String side,
    required String examId,
    required int age,
    required String gender,
    String locale = 'ru',
  }) async {
    final uri = _u('/analyze-eye');
    final req = http.MultipartRequest('POST', uri);

    req.fields['eye'] = side;
    req.fields['exam_id'] = examId;
    req.fields['age'] = age.toString();
    req.fields['gender'] = gender;
    req.fields['locale'] = locale;
    req.fields['task'] = 'Iridodiagnosis';

    final bytes = await file.readAsBytes();
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: '${examId}_$side.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    final streamed = await req.send().timeout(const Duration(seconds: 90));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      throw Exception('AI error ${streamed.statusCode}: $body');
    }

    final jsonMap = jsonDecode(body) as Map<String, dynamic>;
    return AiAnalyzeResponse.fromJson(jsonMap);
  }
}
