import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:iris_health/l10n/localizations.dart';
import 'package:iris_health/screens/patient_form_screen.dart';

void main() => runApp(const IrisApp());

class IrisApp extends StatelessWidget {
  const IrisApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      localeResolutionCallback: (loc, supported){
        final code = loc?.languageCode ?? 'en';
        return supported.firstWhere((l)=>l.languageCode==code, orElse: ()=>const Locale('en'));
      },

      title: 'Iris Health',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const PatientFormScreen(),
    );
  }
}
