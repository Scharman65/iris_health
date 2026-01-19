import 'dart:math';
import 'package:camera/camera.dart';
import 'macro_profile.dart';

class MacroProbe {
  const MacroProbe();

  Future<MacroProfile> detect(
    CameraController controller, {
    required double precisionTorchLevel,
  }) async {
    final model = controller.description.name.toLowerCase();

    // --- ЗУМ ---
    double maxZoom = 1.0;
    try {
      maxZoom = await controller.getMaxZoomLevel();
    } catch (_) {}

    // --- РУЧНОЙ ФОКУС ---
    bool manual = false;
    try {
      await controller.setFocusMode(FocusMode.locked);
      manual = true;
    } catch (_) {}

    // --- ФОНАРИК ---
    bool hasTorch = false;
    try {
      await controller.setFlashMode(FlashMode.torch);
      hasTorch = true;
      await controller.setFlashMode(FlashMode.off);
    } catch (_) {}

    final torchRange = hasTorch ? [0.0, precisionTorchLevel] : [0.0, 0.0];

    final d = _getDefaults(model);

    return MacroProfile(
      deviceModel: controller.description.name,
      bestLens: d.bestLens,
      lensQualityScore: d.lensQualityScore,
      minFocusDistance: d.minFocusDistance,
      recommendedZoom: min(maxZoom, d.recommendedZoom),
      supportsManualFocus: manual,
      supportsRaw: d.supportsRaw,
      supportsLidar: d.supportsLidar,
      aperture: d.aperture,
      pixelSizeMicrons: d.pixelSizeMicrons,
      dynamicRangeStops: d.dynamicRangeStops,
      torchRange: torchRange,
      precisionTorchLevel: precisionTorchLevel,
      recommendedIso: d.recommendedIso,
      recommendedExposure: d.recommendedExposure,
      recommendedFps: d.recommendedFps,
      preferredFormat: d.preferredFormat,
      bestAutofocusScore: d.bestAutofocusScore,
    );
  }

  _Defaults _getDefaults(String m) {
    if (m.contains("13") && m.contains("pro")) {
      return _Defaults(
        bestLens: "telephoto",
        lensQualityScore: 0.92,
        minFocusDistance: 0.02,
        recommendedZoom: 3.0,
        supportsRaw: true,
        supportsLidar: true,
        aperture: 2.2,
        pixelSizeMicrons: 1.9,
        dynamicRangeStops: 11.5,
        recommendedIso: 64,
        recommendedExposure: -0.3,
        recommendedFps: 30,
        preferredFormat: "jpg",
        bestAutofocusScore: 0.85,
      );
    }

    if (m.contains("14") && m.contains("pro")) {
      return _Defaults(
        bestLens: "telephoto",
        lensQualityScore: 0.94,
        minFocusDistance: 0.02,
        recommendedZoom: 3.0,
        supportsRaw: true,
        supportsLidar: true,
        aperture: 2.2,
        pixelSizeMicrons: 2.0,
        dynamicRangeStops: 12.0,
        recommendedIso: 64,
        recommendedExposure: -0.33,
        recommendedFps: 30,
        preferredFormat: "jpg",
        bestAutofocusScore: 0.87,
      );
    }

    return _Defaults(
      bestLens: "wide",
      lensQualityScore: 0.75,
      minFocusDistance: 0.05,
      recommendedZoom: 2.0,
      supportsRaw: false,
      supportsLidar: false,
      aperture: 2.2,
      pixelSizeMicrons: 1.6,
      dynamicRangeStops: 10.0,
      recommendedIso: 100,
      recommendedExposure: -0.3,
      recommendedFps: 30,
      preferredFormat: "jpg",
      bestAutofocusScore: 0.65,
    );
  }
}

class _Defaults {
  final String bestLens;
  final double lensQualityScore;
  final double minFocusDistance;
  final double recommendedZoom;
  final bool supportsRaw;
  final bool supportsLidar;
  final double aperture;
  final double pixelSizeMicrons;
  final double dynamicRangeStops;
  final double recommendedIso;
  final double recommendedExposure;
  final int recommendedFps;
  final String preferredFormat;
  final double bestAutofocusScore;

  _Defaults({
    required this.bestLens,
    required this.lensQualityScore,
    required this.minFocusDistance,
    required this.recommendedZoom,
    required this.supportsRaw,
    required this.supportsLidar,
    required this.aperture,
    required this.pixelSizeMicrons,
    required this.dynamicRangeStops,
    required this.recommendedIso,
    required this.recommendedExposure,
    required this.recommendedFps,
    required this.preferredFormat,
    required this.bestAutofocusScore,
  });
}
