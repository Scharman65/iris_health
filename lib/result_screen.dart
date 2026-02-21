import 'dart:io';
import 'package:flutter/material.dart';
import '../models/gender.dart';

class ResultScreen extends StatelessWidget {
  final String imagePath;
  final String diagnosisId;
  final int age;
  final Gender gender;

  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.diagnosisId,
    required this.age,
    required this.gender,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Результат съемки'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Hero(
                tag: imagePath,
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Возраст: $age | Пол: ${gender == Gender.male ? 'Мужской' : 'Женский'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              'ID обследования: $diagnosisId',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Сделать новое фото'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
