import 'dart:async';

import 'package:flutter/material.dart';

import '../services/ai_client.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final _ctrl = TextEditingController();
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _ctrl.text = AiClient.instance.baseUrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _normalize(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t.replaceAll(RegExp(r'/+$'), '');
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });

    final candidate = _normalize(_ctrl.text);
    try {
      await AiClient.instance.setBaseUrl(candidate);
      final ok = await AiClient.instance.health();
      setState(() {
        _testResult = ok ? 'OK: /health = 200' : 'FAIL: /health not 200';
      });
    } catch (e) {
      setState(() {
        _testResult = 'ERROR: $e';
      });
    } finally {
      setState(() {
        _testing = false;
      });
    }
  }

  Future<void> _save() async {
    final candidate = _normalize(_ctrl.text);
    await AiClient.instance.setBaseUrl(candidate);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI_BASE_URL сохранён')),
    );
  }

  Future<void> _reset() async {
    await AiClient.instance.resetToDefault();
    _ctrl.text = AiClient.instance.baseUrl;
    setState(() {
      _testResult = null;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Сброшено на значение по умолчанию')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Базовый URL сервера',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'https://xxxxx.trycloudflare.com',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _testing ? null : _test,
                  child: _testing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Test /health'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : _save,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _testing ? null : _reset,
            child: const Text('Reset to default'),
          ),
          const SizedBox(height: 16),
          if (_testResult != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: Text(_testResult!),
            ),
          const SizedBox(height: 24),
          Text(
            'Текущее значение',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SelectableText(AiClient.instance.baseUrl),
        ],
      ),
    );
  }
}
