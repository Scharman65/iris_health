import 'dart:io';

import 'ai_client.dart';
import 'ai_models.dart';

class DiagnosisService {
  DiagnosisService({AiClient? client}) : _client = client ?? AiClient.instance;

  final AiClient _client;

  Future<bool> health() => _client.health();

  /// Анализ пары (левый + правый) через два запроса /analyze-eye?eye=left|right.
  /// Возвращает структуру для UI: summary/findings/raw.
  Future<Map<String, dynamic>> analyzePair({
    required File leftFile,
    required File rightFile,
    required String examId,
    required int age,
    required String gender,
    String locale = 'ru',
  }) async {
    final AiAnalyzeResponse left = await _client.analyzeEye(
      file: leftFile,
      side: 'left',
      examId: examId,
      age: age,
      gender: gender,
      locale: locale,
    );

    final AiAnalyzeResponse right = await _client.analyzeEye(
      file: rightFile,
      side: 'right',
      examId: examId,
      age: age,
      gender: gender,
      locale: locale,
    );

    final findings = <Map<String, dynamic>>[];

    for (final z in left.zones) {
      findings.add({
        'zone': 'L: ${z.name}',
        'score': z.score,
        'note': z.note,
      });
    }

    for (final z in right.zones) {
      findings.add({
        'zone': 'R: ${z.name}',
        'score': z.score,
        'note': z.note,
      });
    }

    Map<String, dynamic> pack(AiAnalyzeResponse r) {
      return {
        'status': r.status,
        'field': r.field,
        'filename': r.filename,
        'content_type': r.contentType,
        'size_bytes': r.sizeBytes,
        'quality': r.quality,
        'took_ms': r.tookMs,
        'zones': [
          for (final z in r.zones)
            {
              'name': z.name,
              'score': z.score,
              'note': z.note,
            }
        ],
      };
    }

    return {
      'summary':
          'AI OK. Quality: L=${left.quality.toStringAsFixed(2)}, R=${right.quality.toStringAsFixed(2)}. '
          'Time: L=${left.tookMs}ms, R=${right.tookMs}ms.',
      'findings': findings,
      'raw': {
        'left': pack(left),
        'right': pack(right),
      },
    };
  }
}
