import 'package:flutter/widgets.dart';

class S {
  final Locale locale;
  S(this.locale);

  static const supported = ['en','ru','fr','de','es'];
  static S of(BuildContext c) => Localizations.of<S>(c, S)!;
  static const LocalizationsDelegate<S> delegate = _SDelegate();
  static List<Locale> get supportedLocales => supported.map((e)=>Locale(e)).toList();

  static final _m = <String,Map<String,String>>{
    'title': {'en':'Iris Health','ru':'Iris Health','fr':'Iris Health','de':'Iris Health','es':'Iris Health'},

    // Было "Анкета пациента" — стало "Иридодиагностика"
    'form_title': {
      'en':'Iridodiagnostics','ru':'Иридодиагностика','fr':'Iridodiagnostique','de':'Iridodiagnostik','es':'Iridodiagnóstico'
    },

    'age': {'en':'Age','ru':'Возраст','fr':'Âge','de':'Alter','es':'Edad'},
    'gender': {'en':'Gender','ru':'Пол','fr':'Sexe','de':'Geschlecht','es':'Género'},
    'male': {'en':'Male','ru':'Мужчина','fr':'Homme','de':'Männlich','es':'Hombre'},
    'female': {'en':'Female','ru':'Женщина','fr':'Femme','de':'Weiblich','es':'Mujer'},
    'next': {'en':'Next','ru':'Далее','fr':'Suivant','de':'Weiter','es':'Siguiente'},
    'place_in_ring': {
      'en':'Place pupil in the ring','ru':'Поместите зрачок в кольцо','fr':'Placez la pupille dans l’anneau','de':'Pupille in den Ring platzieren','es':'Coloque la pupila en el anillo'
    },
    'shoot_left': {
      'en':'Shoot burst x3 (LEFT)','ru':'Снять серию 3 (ЛЕВЫЙ)','fr':'Prendre rafale x3 (GAUCHE)','de':'Serie x3 (LINKS)','es':'Ráfaga x3 (IZQ)'
    },
    'shoot_right': {
      'en':'Shoot burst x3 (RIGHT)','ru':'Снять сериию 3 (ПРАВЫЙ)','fr':'Prendre rafale x3 (DROIT)','de':'Serie x3 (RECHTS)','es':'Ráfaga x3 (DER)'
    },
    'too_dark': {
      'en':'Too dark. Turning on light…','ru':'Темно. Включаю подсветку…','fr':'Trop sombre. J’allume la lumière…','de':'Zu dunkel. Licht an…','es':'Muy oscuro. Encendiendo luz…'
    },
    'too_glare': {
      'en':'Glare detected. Adjust angle / turning light off…','ru':'Блики. Измените угол / выключаю подсветку…','fr':'Reflets détectés. Ajustez l’angle / j’éteins…','de':'Blendung erkannt. Winkel anpassen / Licht aus…','es':'Reflejos detectados. Ajuste el ángulo / apagando luz…'
    },
  };

  String t(String key){
    final lang = locale.languageCode;
    final m = _m[key];
    return (m?[lang] ?? m?['en'] ?? key);
  }
}

class _SDelegate extends LocalizationsDelegate<S>{
  const _SDelegate();
  @override bool isSupported(Locale l)=>S.supported.contains(l.languageCode);
  @override Future<S> load(Locale l) async => S(l);
  @override bool shouldReload(_SDelegate old)=>false;
}
