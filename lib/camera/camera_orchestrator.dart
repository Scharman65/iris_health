import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'macro_profile.dart';

/// ------------------------------------------------------------
/// CameraOrchestrator v2.1 — единый контроллер, совместимый с iOS.
/// ------------------------------------------------------------
/// • Один CameraController для preview + photo
/// • Поддерживает:
///     – YUV420 stream для LiveSharpnessAnalyzer
///     – JPEG снимки
///     – zoom / focus из MacroProfile
///     – телефото объектив (если есть)
/// • Полностью совместим с iPhone 13 Pro.
/// ------------------------------------------------------------
class CameraOrchestrator {
  final MacroProfile profile;

  late CameraController _controller;
  CameraController get controller => _controller;

  bool _torchOn = false;
  bool get torchOn => _torchOn;

  CameraOrchestrator(this.profile);

  Future<void> initialize() async {
    final cams = await availableCameras();

    // Ищем тыловую камеру
    CameraDescription selected = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cams.first,
    );

    // Ищем телефото-объектив (iPhone 13 Pro — tele)
    final tele = cams.where((c) =>
        c.lensDirection == CameraLensDirection.back &&
        c.name.toLowerCase().contains("tele"));

    if (tele.isNotEmpty) {
      selected = tele.first;
    }

    // Создаём единый контроллер — поток + фото
    _controller = CameraController(
      selected,
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // поток для sharpness
    );

    await _controller.initialize();

    // Применяем macro-profile
    try {
      // Zoom
      await _controller.setZoomLevel(profile.zoom);

      // FocusMode
      await _controller.setFocusMode(profile.focusMode);
    } catch (_) {
      // на некоторых моделях отдельные функции могут быть недоступны
    }

    try {
      await _controller.setFlashMode(FlashMode.off);
      _torchOn = false;
    } catch (_) {}

    // Fallback автонастройки
    try {
      await _controller.setFocusMode(FocusMode.auto);
      await _controller.setExposureMode(ExposureMode.auto);
    } catch (_) {}
  }

  /// ------------------------------------------------------------
  /// Съёмка макро-фото высокого качества
  /// ------------------------------------------------------------
  Future<Uint8List> captureBestIris() async {
    final file = await _controller.takePicture();
    return await file.readAsBytes();
  }

  Future<void> setTorch(bool on) async {
    try {
      await _controller.setFlashMode(on ? FlashMode.torch : FlashMode.off);
      _torchOn = on;
    } catch (_) {}
  }

  /// ------------------------------------------------------------
  /// Поток изображений для резкости / стабилизации
  /// ------------------------------------------------------------
  Future<void> startStream(void Function(CameraImage image) onImage) async {
    await _controller.startImageStream(onImage);
  }

  Future<void> stopStream() async {
    if (_controller.value.isStreamingImages) {
      await _controller.stopImageStream();
    }
  }

  /// ------------------------------------------------------------
  /// Освобождение ресурсов
  /// ------------------------------------------------------------
  void dispose() {
    if (_controller.value.isStreamingImages) {
      _controller.stopImageStream();
    }
    _controller.dispose();
  }
}
