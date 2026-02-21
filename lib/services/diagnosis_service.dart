import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'ai_client.dart';

class DiagnosisService {
  DiagnosisService({AiClient? client}) : _client = client ?? AiClient.instance;

  final AiClient _client;

  Future<bool> health() => _client.health();

  Uri _u(String path) {
    final b = _client.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$b$p');
  }

  /// Анализ пары (левый + правый) через ОДИН POST /analyze
  /// Сервер v0.6.1 ожидает multipart:
  ///   - file_left
  ///   - file_right
  ///
  /// Возвращаем структуру для UI: summary/findings/raw.
  Future<Map<String, dynamic>> analyzePair({
    required File leftFile,
    required File rightFile,
    required String examId,
    required int age,
    required String gender,
    String locale = 'ru',
  }) async {
    final b = _client.baseUrl;
    if (b.contains('127.0.0.1') || b.contains('localhost')) {
      throw Exception(
        'AI baseUrl points to localhost. On iPhone use Mac LAN IP, e.g. http://172.20.10.11:8010',
      );
    }

    final uri = _u('/analyze');

    final req = http.MultipartRequest('POST', uri);

    // Эти поля сервер может игнорировать — но они полезны для будущей трассировки/логов.
    req.fields['exam_id'] = examId;
    req.fields['age'] = age.toString();
    req.fields['gender'] = gender;
    req.fields['locale'] = locale;
    req.fields['task'] = 'Iridodiagnosis';

    final leftBytes = await leftFile.readAsBytes();
    final rightBytes = await rightFile.readAsBytes();

    req.files.add(
      http.MultipartFile.fromBytes(
        'file_left',
        leftBytes,
        filename: '${examId}_left.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    req.files.add(
      http.MultipartFile.fromBytes(
        'file_right',
        rightBytes,
        filename: '${examId}_right.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    final streamed = await req.send().timeout(const Duration(seconds: 120));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      throw Exception('AI error ${streamed.statusCode}: $body');
    }

    final jsonMap = jsonDecode(body);
    if (jsonMap is! Map) {
      throw Exception('AI invalid JSON: expected object');
    }

    final m = Map<String, dynamic>.from(jsonMap as Map);

    final textSummary = m['text_summary']?.toString();
    final pdfUrl = m['pdf_url']?.toString();

    final summaryParts = <String>[];
    if (textSummary != null && textSummary.isNotEmpty) {
      summaryParts.add(textSummary);
    } else {
      summaryParts.add('AI OK.');
    }
    if (pdfUrl != null && pdfUrl.isNotEmpty) {
      summaryParts.add('PDF: $pdfUrl');
    }

    return {
      'summary': summaryParts.join(' '),
      'findings': const <dynamic>[],
      'raw': m,
    };
  }
}
