import 'dart:io';
import 'package:flutter/material.dart';

class DiagnosisSummaryScreen extends StatelessWidget {
  const DiagnosisSummaryScreen({
    super.key,
    required this.examId,
    required this.leftPath,
    required this.rightPath,
    this.aiResult,
    this.age,
    this.gender,
  });

  /// Идентификатор обследования
  final String examId;

  /// Пути к сохранённым кадрам (jpg внутри sandbox приложения)
  final String leftPath;
  final String rightPath;

  /// Опциональные данные из ИИ (или заглушки)
  final Map<String, dynamic>? aiResult;

  /// Опциональные демографические параметры
  final int? age;
  final String? gender;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text('Итоги • ${examId.isNotEmpty ? examId.substring(0, examId.length.clamp(0, 8)) : ""}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (age != null || (gender != null && gender!.isNotEmpty)) ...[
              Text(
                'Профиль: '
                '${age != null ? 'возраст $age' : ''}'
                '${(age != null && gender != null && gender!.isNotEmpty) ? ', ' : ''}'
                '${(gender != null && gender!.isNotEmpty) ? 'пол $gender' : ''}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
            ],
            Row(
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
    if (aiResult == null) {
      return Text(
        'Результаты анализа недоступны.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final summary = aiResult!['summary'] as String? ?? 'Нет сводки.';
    final findings = (aiResult!['findings'] as List?) ?? const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Результаты анализа', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(summary),
            const SizedBox(height: 12),
            if (findings.isNotEmpty) ...[
              const Divider(),
              ...findings.map((f) {
                final m = (f as Map).cast<String, dynamic>();
                final zone = m['zone']?.toString() ?? '—';
                final score = (m['score'] is num) ? (m['score'] as num).toStringAsFixed(2) : '—';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(zone)),
                      Text(score),
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

