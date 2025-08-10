import 'package:flutter/material.dart';
import 'models/diagnosis_model.dart';
import 'screens/diagnosis_summary_screen.dart';

class HomeScreen extends StatelessWidget {
  final List<Diagnosis> diagnoses;

  const HomeScreen({super.key, required this.diagnoses});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История обследований'),
      ),
      body: ListView.builder(
        itemCount: diagnoses.length,
        itemBuilder: (context, index) {
          final diagnosis = diagnoses[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              title: Text('ID: ${diagnosis.id}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Возраст: ${diagnosis.age}'),
                  Text('Пол: ${diagnosis.gender == Gender.male ? 'Мужской' : 'Женский'}'),
                  Text('Дата: ${diagnosis.dateTime.toLocal().toString().split(' ')[0]}'),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DiagnosisSummaryScreen(diagnosis: diagnosis),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
