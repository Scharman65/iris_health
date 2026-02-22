import 'package:flutter/material.dart';
import 'patient_form_screen.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iris Health')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const PatientFormScreen()),
              );
            },
            child: const Text('Начать'),
          ),
        ),
      ),
    );
  }
}
