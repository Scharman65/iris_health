import 'package:flutter/material.dart';
import 'patient_form_screen.dart';
import '../models/gender.dart'; // ✅ Добавлен импорт

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PatientFormScreen(
      onSubmit: (age, genderStr) {
        final gender = genderStr == 'Мужчина' ? Gender.male : Gender.female;
        Navigator.pushReplacementNamed(
          context,
          '/camera',
          arguments: {
            'age': age,
            'gender': gender,
          },
        );
      },
    );
  }
}
