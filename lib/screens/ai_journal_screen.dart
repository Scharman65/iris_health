import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/ai_journal_entry.dart';

class AiJournalScreen extends StatelessWidget {
  const AiJournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<AiJournalEntry>('ai_journal');

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Journal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              await box.clear();
            },
          )
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<AiJournalEntry> box, _) {
          final items = box.values.toList().reversed.toList();

          if (items.isEmpty) {
            return const Center(child: Text('No journal entries'));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final e = items[index];
              return ListTile(
                title: Text('${e.status.toUpperCase()} • ${e.durationMs} ms'),
                subtitle: Text(
                  '${e.startedAt}\n'
                  'exam: ${e.examId}\n'
                  '${e.statusCode != null ? "code: ${e.statusCode}\n" : ""}'
                  '${e.message ?? ""}',
                ),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }
}
