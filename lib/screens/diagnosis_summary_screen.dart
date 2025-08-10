import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iris_health/models/diagnosis_model.dart';
import 'history_screen.dart';

class DiagnosisSummaryScreen extends StatelessWidget {
  final Diagnosis diagnosis;
  final Map<String, dynamic>? aiResult;

  const DiagnosisSummaryScreen({
    super.key,
    required this.diagnosis,
    this.aiResult,
  });

  @override
  Widget build(BuildContext context) {
    final zones = aiResult?['zones'] ?? [];
    final summary = aiResult?['summary'] ?? {};
    final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(diagnosis.date);

    return Scaffold(
      appBar: AppBar(title: const Text('Результат обследования')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('ID: ${diagnosis.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Возраст: ${diagnosis.age}'),
            Text('Пол: ${diagnosis.gender == Gender.male ? 'Мужчина' : 'Женщина'}'),
            Text('Дата: $dateStr'),
            const Divider(height: 32),

            const Text('Левый глаз:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildEyeImage(diagnosis.leftEyeImagePath),
            const SizedBox(height: 16),

            const Text('Правый глаз:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildEyeImage(diagnosis.rightEyeImagePath),
            const Divider(height: 32),

            if (aiResult != null) ...[
              const Text('Анализ по зонам:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...zones.map<Widget>((zone) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${zone['organ']} (${zone['position']}): ${zone['findings']} (Степень ${zone['severity']})',
                  ),
                );
              }).toList(),
              const SizedBox(height: 16),
              const Text('Диагноз:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(summary['diagnosis'] ?? '—'),
              const SizedBox(height: 12),
              const Text('Рекомендации:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...(summary['recommendations'] as List<dynamic>? ?? [])
                  .map((r) => Row(
                        children: [
                          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(child: Text(r)),
                        ],
                      ))
                  .toList(),
            ] else
              const Text('AI-результат отсутствует', style: TextStyle(fontStyle: FontStyle.italic)),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Готово'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    );
                  },
                  child: const Text('История'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEyeImage(String path) {
    if (File(path).existsSync()) {
      return Image.file(File(path), height: 150);
    } else {
      return Container(
        height: 150,
        color: Colors.grey[300],
        child: const Center(child: Text('Фото отсутствует')),
      );
    }
  }
}
