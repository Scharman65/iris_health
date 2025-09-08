import 'dart:convert';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> analyzeIrisImages({
  required String leftEyePath,
  required String rightEyePath,
}) async {
  final uri =
      Uri.parse('http://192.168.100.160:5050/preprocess'); // ✅ Новый порт!

  final request = http.MultipartRequest('POST', uri)
    ..files.add(await http.MultipartFile.fromPath('leftEye', leftEyePath))
    ..files.add(await http.MultipartFile.fromPath('rightEye', rightEyePath));

  try {
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return jsonDecode(responseBody); // ✅ Возвращает JSON с zones и summary
    } else {
      return {
        'error': 'Ошибка сервера: ${response.statusCode}',
        'details': responseBody
      };
    }
  } catch (e) {
    return {'error': 'Ошибка соединения: $e'};
  }
}
