import 'package:hive/hive.dart';

part 'ai_journal_entry.g.dart';

@HiveType(typeId: 10)
class AiJournalEntry extends HiveObject {
  @HiveField(0)
  String requestId;

  @HiveField(1)
  String examId;

  @HiveField(2)
  DateTime startedAt;

  @HiveField(3)
  int durationMs;

  @HiveField(4)
  String status; // ok / timeout / network / server / parse / error

  @HiveField(5)
  int? statusCode;

  @HiveField(6)
  String? message;

  AiJournalEntry({
    required this.requestId,
    required this.examId,
    required this.startedAt,
    required this.durationMs,
    required this.status,
    this.statusCode,
    this.message,
  });
}
