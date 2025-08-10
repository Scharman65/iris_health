import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'models/diagnosis_model.dart';
import 'screens/patient_form_screen.dart';
import 'screens/camera_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(GenderAdapter());
  Hive.registerAdapter(DiagnosisAdapter());
  await Hive.openBox<Diagnosis>('diagnoses');

  runApp(const IrisHealthApp());
}

class IrisHealthApp extends StatelessWidget {
  const IrisHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Iris Health',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal),
      home: Builder(
        builder: (context) {
          return PatientFormScreen(
            onSubmit: (age, genderStr) {
              final gender =
                  genderStr == 'Мужчина' ? Gender.male : Gender.female;

              // Генерируем уникальный ID обследования
              final examId = DateTime.now().millisecondsSinceEpoch;

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => CameraScreen(
                    examId: examId,
                    age: age,
                    gender: gender,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
