import 'dart:io';
import 'package:flutter/material.dart';

import 'explain_screen.dart';

class DiagnosisSummaryScreen extends StatelessWidget {
  const DiagnosisSummaryScreen({
    super.key,
    required this.examId,
    required this.leftPath,
    required this.rightPath,
    required this.age,
    required this.gender,
    this.aiResult,
  });

  final String examId;
  final String leftPath;
  final String rightPath;
  final int age;
  final String gender;
  final Map<String, dynamic>? aiResult;

  @override
  Widget build(BuildContext context) {
    final shortId = examId.isNotEmpty
        ? examId.substring(0, examId.length < 8 ? examId.length : 8)
        : '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Итоги • $shortId'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Профиль: возраст $age, пол $gender',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _photoCard(leftPath, 'Левый глаз')),
                const SizedBox(width: 12),
                Expanded(child: _photoCard(rightPath, 'Правый глаз')),
              ],
            ),
            const SizedBox(height: 16),
            _resultBlock(context),
          ],
        ),
      ),
    );
  }

  void _openExplain(BuildContext context, Map<String, dynamic> analysis) {
    final locale = 'ru';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExplainScreen(
          examId: examId,
          locale: locale,
          analysis: analysis,
        ),
      ),
    );
  }

  Widget _photoCard(String path, String title) {
    final exists = File(path).existsSync();
    final image = exists
        ? Image.file(
            File(path),
            height: 220,
            fit: BoxFit.contain,
          )
        : const SizedBox(
            height: 220,
            child: Center(child: Icon(Icons.image_not_supported)),
          );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(color: Colors.black, child: image),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(title),
          ),
        ],
      ),
    );
  }

  Widget _resultBlock(BuildContext context) {
    final theme = Theme.of(context);

    if (aiResult == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Результаты анализа', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Результаты анализа недоступны.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  _openExplain(
                    context,
                    <String, dynamic>{
                      'exam_id': examId,
                      'summary': null,
                      'findings': const <dynamic>[],
                      'raw': <String, dynamic>{},
                    },
                  );
                },
                child: const Text('Пояснение'),
              ),
            ],
          ),
        ),
      );
    }

    final summary = aiResult!['summary'] as String? ?? 'Нет сводки.';
    final findings = (aiResult!['findings'] as List?) ?? const [];

    final raw = (aiResult!['raw'] is Map)
        ? Map<String, dynamic>.from(aiResult!['raw'] as Map)
        : <String, dynamic>{};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Результаты анализа', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(summary),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                _openExplain(
                  context,
                  <String, dynamic>{
                    'exam_id': examId,
                    'summary': summary,
                    'findings': findings,
                    'raw': raw,
                  },
                );
              },
              child: const Text('Пояснение'),
            ),
            const SizedBox(height: 12),
            if (findings.isNotEmpty) ...[
              const Divider(),
              ...findings.map((f) {
                final m = (f as Map).cast<String, dynamic>();
                final zone = m['zone']?.toString() ?? '—';
                final score = (m['score'] is num)
                    ? (m['score'] as num).toStringAsFixed(2)
                    : '—';
                final note = m['note']?.toString();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(zone)),
                          Text(score),
                        ],
                      ),
                      if (note != null && note.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            note,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
