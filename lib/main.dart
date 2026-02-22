import 'package:flutter/material.dart';

import 'screens/patient_form_screen.dart';
import 'services/ai_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ВАЖНО: не блокируем запуск UI сетевыми/долгими операциями.
  runApp(const IrisApp());

  // Инициализация AI-клиента выполняется в фоне.
  // Если init() делает scan/probe по сети — приложение не будет "висеть" на старте.
  Future<void>(() async {
    try {
      await AiClient.instance.init();
      debugPrint('[AiClient] init OK');
    } catch (e, st) {
      debugPrint('[AiClient] init FAILED: $e');
      debugPrint('$st');
    }
  });
}

class IrisApp extends StatelessWidget {
  const IrisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Iris Health',
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: const PatientFormScreen(),
    );
  }
}
