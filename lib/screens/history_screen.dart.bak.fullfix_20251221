import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/diagnosis_model.dart';
import 'diagnosis_summary_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Box<Diagnosis> _box;

  @override
  void initState() {
    super.initState();
    _box = Hive.box<Diagnosis>('diagnoses');
  }

  @override
  Widget build(BuildContext context) {
    final diagnoses = _box.values.toList().reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('История обследований')),
      body: diagnoses.isEmpty
          ? const Center(child: Text('История пуста'))
          : ListView.builder(
              itemCount: diagnoses.length,
              itemBuilder: (context, index) {
                final diagnosis = diagnoses[index];
                return ListTile(
                  leading: diagnosis.leftEyeImagePath.isNotEmpty
                      ? Image.file(
                          File(diagnosis.leftEyeImagePath),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.image_not_supported),
                  title: Text('ID: ${diagnosis.id}'),
                  subtitle: Text(
                    'Возраст: ${diagnosis.age}, Пол: ${diagnosis.gender == Gender.male ? 'Мужчина' : 'Женщина'}\nДата: ${diagnosis.date.toLocal().toString().split(' ')[0]}',
                  ),
                  isThreeLine: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DiagnosisSummaryScreen(
                          diagnosis: diagnosis,
                          aiResult: {}, // 🔹 Пустой результат AI для истории
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
