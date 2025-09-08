import 'package:camera/camera.dart';

Future<CameraDescription> pickBestBackCamera() async {
  final cams = await availableCameras();
  if (cams.isEmpty) {
    throw StateError('No cameras available');
  }
  final backs =
      cams.where((c) => c.lensDirection == CameraLensDirection.back).toList();
  if (backs.isEmpty) return cams.first;

  backs.sort((a, b) {
    int score(CameraDescription c) {
      final n = c.name.toLowerCase();
      if (n.contains('macro')) return 110;
      if (n.contains('tele')) return 100; // часто лучшая резкость для макро
      if (n.contains('wide')) return 80;
      return 60;
    }

    return score(b).compareTo(score(a));
  });
  return backs.first;
}
