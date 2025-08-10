import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/diagnosis_model.dart';
import '../screens/diagnosis_summary_screen.dart';

class DiagnosisService {
  String? _leftEyeTemp;

  /// Обработка сделанного фото
  Future<void> onEyeCaptured({
    required BuildContext context,
    required int examId,
    required int age,
    required Gender gender,
    required bool isLeftEye,
    required String imagePath,
    String? aiResultJson,
  }) async {
    final box = await Hive.openBox<Diagnosis>('diagnoses');

    if (isLeftEye) {
      // Запоминаем путь левого глаза
      _leftEyeTemp = imagePath;
    } else {
      // Сохраняем полную запись
      final diagnosis = Diagnosis(
        id: examId,
        age: age,
        gender: gender,
        leftEyeImagePath: _leftEyeTemp ?? '',
        rightEyeImagePath: imagePath,
        date: DateTime.now(),
        aiResultJson: aiResultJson,
      );
      await box.put(examId, diagnosis);

      // Переходим на экран результатов
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DiagnosisSummaryScreen(diagnosis: diagnosis),
          ),
        );
      }
    }
  }

  /// Отправка данных на AI-сервер
  static Future<void> sendDiagnosis(Diagnosis diagnosis) async {
    // Здесь будет логика отправки данных на сервер
    // Например, через HTTP POST с фото и параметрами
  }

  /// Загрузка истории из локального хранилища
  static Future<List<Diagnosis>> fetchHistory() async {
    final box = await Hive.openBox<Diagnosis>('diagnoses');
    return box.values.toList();
  }
}
