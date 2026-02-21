// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diagnosis_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DiagnosisAdapter extends TypeAdapter<Diagnosis> {
  @override
  final int typeId = 1;

  @override
  Diagnosis read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Diagnosis(
      id: fields[0] as int,
      age: fields[1] as int,
      gender: fields[2] as Gender,
      leftEyeImagePath: fields[3] as String,
      rightEyeImagePath: fields[4] as String,
      date: fields[5] as DateTime,
      aiResultJson: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Diagnosis obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.age)
      ..writeByte(2)
      ..write(obj.gender)
      ..writeByte(3)
      ..write(obj.leftEyeImagePath)
      ..writeByte(4)
      ..write(obj.rightEyeImagePath)
      ..writeByte(5)
      ..write(obj.date)
      ..writeByte(6)
      ..write(obj.aiResultJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiagnosisAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
