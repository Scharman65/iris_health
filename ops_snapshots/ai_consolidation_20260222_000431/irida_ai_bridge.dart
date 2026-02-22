import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class IridaAiBridge {
  final String baseUrl;

  IridaAiBridge({required this.baseUrl});

  Uri _endpoint() {
    final cleaned = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$cleaned/analyze-eye');
  }

  Future<Map<String, dynamic>> analyzeEye({
    required String examId,
    required int age,
    required String gender,
    required String side,
    required File imageFile,
  }) async {
    final uri = _endpoint();

    final req = http.MultipartRequest('POST', uri);

    req.fields['exam_id'] = examId;
    req.fields['age'] = age.toString();
    req.fields['gender'] = gender;
    req.fields['side'] = side;

    final filename = imageFile.path.split('/').last;
    req.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        filename: filename,
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    final streamed = await req.send().timeout(const Duration(seconds: 90));
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('AI server error ${resp.statusCode}: ${resp.body}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'raw': decoded};
  }
}

