import 'package:flutter/material.dart';

import 'screens/patient_form_screen.dart';
import 'services/ai_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AiClient.instance.init();
  runApp(const IrisApp());
}

class IrisApp extends StatelessWidget {
  const IrisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Iris Health",
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: const PatientFormScreen(),
    );
  }
}
