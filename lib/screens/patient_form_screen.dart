import '../services/exam_session.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'camera_screen.dart';
import '../services/session_meta.dart';

class PatientFormScreen extends StatefulWidget {
  const PatientFormScreen({super.key});

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();

  /// Храним техническое значение для сервиса: "male" / "female".
  String? _gender; // null до выбора

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  String _generateExamId() {
    // Простая, безопасная для файловystems строка: YYYYMMDDhhmmss-XXXX
    final now = DateTime.now();
    final ts =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    final suffix = List.generate(4, (_) => alphabet[rnd.nextInt(alphabet.length)]).join();
    return '$ts-$suffix';
  }

  Future<void> _startShoot() async {
    if (!_formKey.currentState!.validate()) return;

    final age = int.parse(_ageCtrl.text.trim());
    final gender = _gender!;
    final examId = ExamSession.start();

    await SessionMeta.write(examId: examId, age: age, gender: gender);

    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds:50));
Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          examId: examId,
              age: age,
              gender: gender,

          // age: age,
          // gender: gender,
          // onlySide: null, // при пересъёмке можно передать EyeSide.left/right
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Данные пациента')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Имя (необязательно)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Возраст (лет)',
                  hintText: 'Например: 34',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Укажите возраст';
                  final n = int.tryParse(t);
                  if (n == null) return 'Возраст должен быть числом';
                  if (n < 0 || n > 120) return 'Некорректный возраст';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(
                  labelText: 'Пол',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Мужской')),
                  DropdownMenuItem(value: 'female', child: Text('Женский')),
                ],
                onChanged: (v) => setState(() => _gender = v),
                validator: (v) => v == null ? 'Выберите пол' : null,
              ),
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: _startShoot,
                child: const Text('Начать съёмку'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
