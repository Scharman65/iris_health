import 'package:hive/hive.dart';

part 'diagnosis_model.g.dart';

@HiveType(typeId: 0)
enum Gender {
  @HiveField(0)
  male,
  @HiveField(1)
  female,
}

@HiveType(typeId: 1)
class Diagnosis extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final int age;

  @HiveField(2)
  final Gender gender;

  @HiveField(3)
  final String leftEyeImagePath;

  @HiveField(4)
  final String rightEyeImagePath;

  @HiveField(5)
  final DateTime date;

  @HiveField(6)
  final String? aiResultJson;

  Diagnosis({
    required this.id,
    required this.age,
    required this.gender,
    required this.leftEyeImagePath,
    required this.rightEyeImagePath,
    required this.date,
    this.aiResultJson,
  });
}
