import 'dart:math';

import 'package:flutter/material.dart';

import 'ai_settings_screen.dart';
import 'camera_screen.dart';

class PatientFormScreen extends StatefulWidget {
  const PatientFormScreen({super.key});

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _ageCtrl = TextEditingController();
  String? _gender;

  String _generateExamId() {
    final r = Random().nextInt(99999999);
    final ts = DateTime.now().millisecondsSinceEpoch;
    return "EXAM_${ts}_$r";
  }

  void _goNext() {
    final age = int.tryParse(_ageCtrl.text);

    if (age == null || age < 1 || age > 120) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Укажи корректный возраст")),
      );
      return;
    }

    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Выбери пол")),
      );
      return;
    }

    final examId = _generateExamId();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          examId: examId,
          age: age,
          gender: _gender!,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Пациент"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Возраст:", style: TextStyle(fontSize: 18)),
            TextField(
              controller: _ageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "Например: 45",
              ),
            ),
            const SizedBox(height: 24),
            const Text("Пол:", style: TextStyle(fontSize: 18)),
            DropdownButton<String>(
              value: _gender,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: "M", child: Text("Мужской")),
                DropdownMenuItem(value: "F", child: Text("Женский")),
              ],
              onChanged: (v) => setState(() => _gender = v),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _goNext,
                child: const Text("Продолжить →"),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

