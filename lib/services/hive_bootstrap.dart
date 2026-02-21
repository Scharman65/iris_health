import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/diagnosis_model.dart';
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
