import 'dart:io';

import 'ai_client_cli.dart';

Future<void> main() async {
  final client = AiClientCli(baseUrl: 'http://172.20.10.11:8000');

  final ok = await client.health();
  stdout.writeln('health: $ok');

  final left = File('left_test.jpg');
  final right = File('right_test.jpg');

  if (!left.existsSync() || !right.existsSync()) {
    stderr.writeln('Не найдены left_test.jpg / right_test.jpg в корне проекта.');
    stderr.writeln('Скопируй тестовые файлы и повтори.');
    exitCode = 2;
    return;
  }

  const examId = 'TEST_EXAM_001';
  const age = 30;
  const gender = 'm';

  final l = await client.analyzeEye(
    file: left,
    side: 'left',
    examId: examId,
    age: age,
    gender: gender,
    locale: 'ru',
  );

  final r = await client.analyzeEye(
    file: right,
    side: 'right',
    examId: examId,
    age: age,
    gender: gender,
    locale: 'ru',
  );

  stdout.writeln(
    'left:  status=${l.status} quality=${l.quality.toStringAsFixed(2)} size=${l.sizeBytes} took=${l.tookMs}ms',
  );
  for (final z in l.zones) {
    stdout.writeln(' - L ${z.name}: ${z.score.toStringAsFixed(2)} (${z.note ?? ''})');
  }

  stdout.writeln(
    'right: status=${r.status} quality=${r.quality.toStringAsFixed(2)} size=${r.sizeBytes} took=${r.tookMs}ms',
  );
  for (final z in r.zones) {
    stdout.writeln(' - R ${z.name}: ${z.score.toStringAsFixed(2)} (${z.note ?? ''})');
  }
}
