import 'package:flutter/material.dart';

import '../models/explain_models.dart';
import '../services/explain_service.dart';

class ExplainScreen extends StatefulWidget {
  const ExplainScreen({
    super.key,
    required this.analysis,
    required this.locale,
    required this.examId,
  });

  final Map<String, dynamic> analysis;
  final String locale;
  final String examId;

  @override
  State<ExplainScreen> createState() => _ExplainScreenState();
}

class _ExplainScreenState extends State<ExplainScreen> {
  final ExplainService _svc = ExplainService();
  Future<ExplainResponse>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ExplainResponse> _load() {
    return _svc.explain(
      locale: widget.locale,
      analysis: widget.analysis,
      clientMeta: <String, dynamic>{
        'app': 'iris_health',
        'platform': Theme.of(context).platform.name,
      },
      requestId: widget.examId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пояснение'),
      ),
      body: FutureBuilder<ExplainResponse>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return _ErrorPane(
              error: snap.error.toString(),
              onRetry: () {
                setState(() {
                  _future = _load();
                });
              },
            );
          }

          final data = snap.data!;
          if (data.blocks.isEmpty) {
            return const Center(child: Text('Нет данных для пояснения.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.blocks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final b = data.blocks[i];
              return _ExplainCard(block: b);
            },
          );
        },
      ),
    );
  }
}

class _ExplainCard extends StatelessWidget {
  const _ExplainCard({required this.block});

  final ExplainBlock block;

  @override
  Widget build(BuildContext context) {
    final sev = block.severity.toLowerCase();
    IconData icon = Icons.info_outline;
    if (sev == 'medium') icon = Icons.warning_amber_outlined;
    if (sev == 'high') icon = Icons.error_outline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    block.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(block.body),
          ],
        ),
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Не удалось получить пояснение.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
