import 'dart:math';

class ExamSession {
  static String? _id;
  static String start() {
    final r = Random.secure();
    final t = DateTime.now().millisecondsSinceEpoch;
    final tail = List.generate(4, (_) => r.nextInt(36))
        .map((i) => "0123456789abcdefghijklmnopqrstuvwxyz"[i])
        .join();
    _id = "EX-$t-$tail";
    return _id!;
  }
  static String get id {
    final v = _id;
    if (v == null) { throw StateError("ExamSession not initialized. Call ExamSession.start() first."); }
    return v;
  }
  static void end() { _id = null; }
}
