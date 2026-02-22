// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_journal_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AiJournalEntryAdapter extends TypeAdapter<AiJournalEntry> {
  @override
  final int typeId = 10;

  @override
  AiJournalEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AiJournalEntry(
      requestId: fields[0] as String,
      examId: fields[1] as String,
      startedAt: fields[2] as DateTime,
      durationMs: fields[3] as int,
      status: fields[4] as String,
      statusCode: fields[5] as int?,
      message: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AiJournalEntry obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.requestId)
      ..writeByte(1)
      ..write(obj.examId)
      ..writeByte(2)
      ..write(obj.startedAt)
      ..writeByte(3)
      ..write(obj.durationMs)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.statusCode)
      ..writeByte(6)
      ..write(obj.message);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiJournalEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
