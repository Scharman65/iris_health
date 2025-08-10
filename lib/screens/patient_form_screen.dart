import 'package:flutter/material.dart';

class PatientFormScreen extends StatefulWidget {
  final void Function(int age, String gender) onSubmit;

  const PatientFormScreen({super.key, required this.onSubmit});

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  int _age = 0;
  String _gender = 'Мужчина';

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      widget.onSubmit(_age, _gender); // 👉 логика из main.dart
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Пациент')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Возраст'),
                keyboardType: TextInputType.number,
                onSaved: (value) => _age = int.tryParse(value ?? '') ?? 0,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Введите возраст';
                  final parsed = int.tryParse(value);
                  if (parsed == null || parsed <= 0 || parsed > 120) {
                    return 'Введите корректный возраст';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _gender,
                items: ['Мужчина', 'Женщина']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (value) => setState(() => _gender = value!),
                onSaved: (value) => _gender = value!,
                decoration: const InputDecoration(labelText: 'Пол'),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Далее'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
