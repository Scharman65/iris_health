import 'dart:convert';
import 'package:camera/camera.dart';

/// Полный макро-профиль камеры.
/// Создаётся один раз при первом запуске устройства.
class MacroProfile {
  final int schemaVersion;

  final String deviceModel;
  final String bestLens;
  final double lensQualityScore;

  final double minFocusDistance;
  final double recommendedZoom;

  final bool supportsManualFocus;
  final bool supportsRaw;
  final bool supportsLidar;

  final double aperture;
  final double pixelSizeMicrons;
  final double dynamicRangeStops;

  final List<double> torchRange;
  final double precisionTorchLevel;

  final double recommendedIso;
  final double recommendedExposure;
  final int recommendedFps;

  final String preferredFormat;

  final double bestAutofocusScore;

  /// ------------------------------------------------------------
  /// Новые поля для совместимости с CameraOrchestrator v2
  /// ------------------------------------------------------------

  /// Фактический zoom, который использует камера
  double get zoom => recommendedZoom;

  /// Фактический режим фокусировки
  final FocusMode focusMode;

  MacroProfile({
    this.schemaVersion = 1,
    required this.deviceModel,
    required this.bestLens,
    required this.lensQualityScore,
    required this.minFocusDistance,
    required this.recommendedZoom,
    required this.supportsManualFocus,
    required this.supportsRaw,
    required this.supportsLidar,
    required this.aperture,
    required this.pixelSizeMicrons,
    required this.dynamicRangeStops,
    required this.torchRange,
    required this.precisionTorchLevel,
    required this.recommendedIso,
    required this.recommendedExposure,
    required this.recommendedFps,
    required this.preferredFormat,
    required this.bestAutofocusScore,
    this.focusMode = FocusMode.auto,
  });

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'deviceModel': deviceModel,
        'bestLens': bestLens,
        'lensQualityScore': lensQualityScore,
        'minFocusDistance': minFocusDistance,
        'recommendedZoom': recommendedZoom,
        'supportsManualFocus': supportsManualFocus,
        'supportsRaw': supportsRaw,
        'supportsLidar': supportsLidar,
        'aperture': aperture,
        'pixelSizeMicrons': pixelSizeMicrons,
        'dynamicRangeStops': dynamicRangeStops,
        'torchRange': torchRange,
        'precisionTorchLevel': precisionTorchLevel,
        'recommendedIso': recommendedIso,
        'recommendedExposure': recommendedExposure,
        'recommendedFps': recommendedFps,
        'preferredFormat': preferredFormat,
        'bestAutofocusScore': bestAutofocusScore,
        'focusMode': focusMode.toString(),
      };

  factory MacroProfile.fromJson(Map<String, dynamic> json) {
    return MacroProfile(
      schemaVersion: json['schemaVersion'] ?? 1,
      deviceModel: json['deviceModel'] ?? 'Unknown',
      bestLens: json['bestLens'] ?? 'wide',
      lensQualityScore: (json['lensQualityScore'] ?? 0.7).toDouble(),
      minFocusDistance: (json['minFocusDistance'] ?? 0.02).toDouble(),
      recommendedZoom: (json['recommendedZoom'] ?? 1.0).toDouble(),
      supportsManualFocus: json['supportsManualFocus'] ?? false,
      supportsRaw: json['supportsRaw'] ?? false,
      supportsLidar: json['supportsLidar'] ?? false,
      aperture: (json['aperture'] ?? 1.6).toDouble(),
      pixelSizeMicrons: (json['pixelSizeMicrons'] ?? 1.7).toDouble(),
      dynamicRangeStops: (json['dynamicRangeStops'] ?? 10.0).toDouble(),
      torchRange: (json['torchRange'] ?? [0.0, 1.0]).cast<double>(),
      precisionTorchLevel:
          (json['precisionTorchLevel'] ?? 0.5).toDouble(),
      recommendedIso: (json['recommendedIso'] ?? 64).toDouble(),
      recommendedExposure:
          (json['recommendedExposure'] ?? -0.3).toDouble(),
      recommendedFps: json['recommendedFps'] ?? 30,
      preferredFormat: json['preferredFormat'] ?? 'jpg',
      bestAutofocusScore:
          (json['bestAutofocusScore'] ?? 0.5).toDouble(),
      focusMode: _parseFocus(json['focusMode']),
    );
  }

  static FocusMode _parseFocus(String? value) {
    switch (value) {
      case 'FocusMode.locked':
        return FocusMode.locked;
      case 'FocusMode.auto':
      default:
        return FocusMode.auto;
    }
  }

  @override
  String toString() => jsonEncode(toJson());
}
