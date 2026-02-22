import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Базовый URL для IRIDA AI сервера.
/// Используем IP Мака в Wi-Fi: 172.20.10.11
const String _defaultBaseUrl = 'http://172.20.10.11:8000';

/// Простой HTTP-клиент для IRIDA AI сервера.
/// Здесь:
///  • checkHealth() — пинг /health
///  • analyzeEye(...) — POST /analyze-eye с JSON-пэйлоадом
class IridaApiClient {
  final String baseUrl;

  IridaApiClient({String? baseUrl}) : baseUrl = baseUrl ?? _defaultBaseUrl;

  /// Проверка здоровья сервера: GET /health
  Future<String> checkHealth() async {
    final uri = Uri.parse('$baseUrl/health');
    debugPrint('IRIDA API: GET $uri');

    final resp = await http
        .get(uri)
        .timeout(const Duration(seconds: 3));

    debugPrint(
        'IRIDA API: /health status=${resp.statusCode}, body=${resp.body}');

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return data['status']?.toString() ?? 'unknown';
    }

    throw Exception(
      'Health check failed: ${resp.statusCode} ${resp.body}',
    );
  }

  /// Вызов анализа: POST /analyze-eye
  ///
  /// [payload] — карта с данными обследования:
  ///   {
  ///     "exam_id": "...",
  ///     "patient": {...},
  ///     "eye": {...},
  ///     "zones": [...],
  ///     "global_flags": {...}
  ///   }
  ///
  /// Сейчас это будет использоваться как заглушка:
  ///   • мы сформируем payload в DiagnosisService
  ///   • отправим сюда
  ///   • вернём Map<String, dynamic> с ответом сервера
  Future<Map<String, dynamic>> analyzeEye(
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('$baseUrl/analyze-eye');
    debugPrint('IRIDA API: POST $uri');
    debugPrint('IRIDA API payload: ${jsonEncode(payload)}');

    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));

    debugPrint(
      'IRIDA API: /analyze-eye status=${resp.statusCode}, body=${resp.body}',
    );

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    throw Exception(
      'Analyze failed: ${resp.statusCode} ${resp.body}',
    );
  }
}

