import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'macro_profile.dart';
import 'macro_probe.dart';

class MacroProfileStorage {
  static const _key = "macro_profile_v1";

  Future<MacroProfile> loadOrCreateProfile(CameraController tmp) async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.containsKey(_key)) {
      try {
        final decoded = jsonDecode(prefs.getString(_key)!);
        return MacroProfile.fromJson(decoded);
      } catch (_) {
        // повреждённый профиль — создаём заново
      }
    }

    final probe = MacroProbe();
    final profile =
        await probe.detect(tmp, precisionTorchLevel: 0.35);

    await prefs.setString(_key, jsonEncode(profile.toJson()));
    return profile;
  }
}
