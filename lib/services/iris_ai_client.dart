import 'dart:convert';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> analyzeIrisImages({
  required String leftEyePath,
  required String rightEyePath,
}) async {
  final uri = Uri.parse('https://iris-ai-server.onrender.com/preprocess');

  final request = http.MultipartRequest('POST', uri)
    ..files.add(await http.MultipartFile.fromPath('leftEye', leftEyePath))
    ..files.add(await http.MultipartFile.fromPath('rightEye', rightEyePath));

  final response = await request.send();
  final responseBody = await response.stream.bytesToString();

  if (response.statusCode == 200) {
    return jsonDecode(responseBody);
  } else {
    return {
      'status': 'error',
      'message': 'Ошибка анализа: ${response.statusCode}'
    };
  }
}
