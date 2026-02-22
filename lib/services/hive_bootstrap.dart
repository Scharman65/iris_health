import 'package:hive_flutter/hive_flutter.dart';

import '../models/diagnosis_model.dart';
import '../models/ai_journal_entry.dart';
import '../models/gender.dart';

class HiveBootstrap {
  static bool _ready = false;

  static Future<void> ensureInitialized() async {
    if (_ready) return;

    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(GenderAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(DiagnosisAdapter());
    }

    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(AiJournalEntryAdapter());
    }

    // Ensure AI journal box exists early (diagnostics / tracing).
    if (!Hive.isBoxOpen('ai_journal')) {
      await Hive.openBox<AiJournalEntry>('ai_journal');
    }

    _ready = true;
  }

  static Future<Box<T>> openBox<T>(String name) async {
    await ensureInitialized();
    if (Hive.isBoxOpen(name)) {
      return Hive.box<T>(name);
    }
    return Hive.openBox<T>(name);
  }
}
