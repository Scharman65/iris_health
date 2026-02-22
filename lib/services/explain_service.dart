import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/explain_models.dart';
import 'ai_client.dart';

class ExplainNotSupportedError implements Exception {
  ExplainNotSupportedError(this.message);
  final String message;
  @override
  String toString() => message;
}

class ExplainService {
  ExplainService({AiClient? client}) : _client = client ?? AiClient.instance;

  final AiClient _client;

  Uri _endpoint() {
    final cleaned = _client.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$cleaned/explain');
  }

  Future<ExplainResponse> explain({
    required String locale,
    required Map<String, dynamic> analysis,
    Map<String, dynamic>? clientMeta,
    String? requestId,
  }) async {
    final uri = _endpoint();

    final payload = <String, dynamic>{
      'locale': locale,
      'analysis': analysis,
      'client': clientMeta ?? <String, dynamic>{},
      if (requestId != null) 'request_id': requestId,
    };

    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode == 404) {
      throw ExplainNotSupportedError(
          'Explain endpoint is not available on this AI server');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Explain failed: ${resp.statusCode} ${resp.body}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Explain failed: invalid JSON shape');
    }

    return ExplainResponse.fromJson(decoded);
  }
}
