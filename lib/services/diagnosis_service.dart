import 'dart:io';

import 'ai_client.dart';

class DiagnosisService {
  DiagnosisService({AiClient? client}) : _client = client ?? AiClient.instance;

  final AiClient _client;

  Future<bool> health() => _client.health();

  /// Анализ пары (левый + правый) через ЕДИНСТВЕННЫЙ клиент AiClient -> POST /analyze
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
    final m = await _client.analyzePair(
      leftFile: leftFile,
      rightFile: rightFile,
      examId: examId,
      age: age,
      gender: gender,
      locale: locale,
    );

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
