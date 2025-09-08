import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iris_health/utils/sharp.dart';

class CameraProfile {
  final String cameraName;
  final double zoom;

  CameraProfile({required this.cameraName, required this.zoom});

  static const _kName = 'cam_profile_name';
  static const _kZoom = 'cam_profile_zoom';

  static Future<CameraProfile?> load() async {
    final p = await SharedPreferences.getInstance();
    final name = p.getString(_kName);
    final zoom = p.getDouble(_kZoom);
    if (name == null || zoom == null) return null;
    return CameraProfile(cameraName: name, zoom: zoom);
  }

  static Future<void> save(CameraProfile profile) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kName, profile.cameraName);
    await p.setDouble(_kZoom, profile.zoom);
  }

  /// Выбираем предпочтительную заднюю камеру: Tele/Zoom если есть, иначе первая задняя, иначе первая любая.
  static CameraDescription chooseBestCamera(List<CameraDescription> cameras) {
    if (cameras.isEmpty) return cameras.first;
    final backs = cameras.where((c) => c.lensDirection == CameraLensDirection.back).toList();
    if (backs.isEmpty) return cameras.first;
    CameraDescription pick = backs.first;
    final tele = backs.firstWhere(
      (c) {
        final n = c.name.toLowerCase();
        return n.contains('tele') || n.contains('zoom');
      },
      orElse: () => pick,
    );
    pick = tele;
    return pick;
  }

  /// Быстрая проба резкости на 1× и 2×. Возвращает рекомендуемый зум.
  static Future<double> probeBestZoom(CameraController controller) async {
    double bestZoom = 1.0;
    double bestScore = -1;

    final maxZoom = await controller.getMaxZoomLevel();
    final candidates = <double>[1.0, if (maxZoom >= 2.0) 2.0];
    for (final z in candidates) {
      try {
        await controller.setZoomLevel(z);
        final shot = await controller.takePicture();
        final Uint8List bytes = await shot.readAsBytes();
        final s = sharpnessFromBytes(bytes);
        if (s > bestScore) {
          bestScore = s; bestZoom = z;
        }
      } catch (_) { /* ignore, keep previous */ }
    }
    // вернуть комфортный, но не за пределами max:
    if (bestZoom > maxZoom) bestZoom = maxZoom;
    return bestZoom;
  }
}
