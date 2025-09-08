import 'package:iris_health/models/eye_side.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:iris_health/l10n/localizations.dart';
import 'package:iris_health/utils/sharp.dart';
import 'package:iris_health/utils/quality_utils.dart';
import 'package:iris_health/utils/circle_crop.dart';
import 'package:iris_health/services/diagnosis_service.dart';
import 'diagnosis_summary_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    required this.examId,
    this.onlySide,
    this.age,
    this.gender,
  });

  /// Идентификатор обследования (папка хранения и сквозной ключ)
  final String examId;

  /// Если задано — снимаем только указанную сторону (для пересъёмки),
  /// иначе мастер: левый → правый.
  final EyeSide? onlySide;

  /// Доп. параметры (могут быть не заданы).
  final int? age;
  final String? gender;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _ready = false;

  bool _leftDone = false;
  Uint8List? _leftBestBytes;
  Uint8List? _rightBestBytes;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();

      // По умолчанию первая камера, но пытаемся выбрать «tele/zoom» для макро.
      CameraDescription cam = _cameras!.first;
      final backs = _cameras!
          .where((c) => c.lensDirection == CameraLensDirection.back)
          .toList();
      if (backs.isNotEmpty) {
        cam = backs.first;
        final tele = backs.firstWhere(
          (c) {
            final n = c.name.toLowerCase();
            return n.contains('tele') || n.contains('zoom');
          },
          orElse: () => cam,
        );
        cam = tele;
      }

      _controller = CameraController(
        cam,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _controller!.initialize();

      // Базовые настройки: без вспышки, пробуем x2 если доступно
      try {
        await _controller!.setFlashMode(FlashMode.off);
      } catch (_) {}
      try {
        final maxZoom = await _controller!.getMaxZoomLevel();
        final targetZoom = maxZoom >= 2.0 ? 2.0 : 1.0;
        await _controller!.setZoomLevel(targetZoom);
      } catch (_) {}

      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera init error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Серия снимков с оценкой яркости/бликов/резкости
  Future<Uint8List?> _captureBestOf(
    int count, {
    double minSharp = 200.0,
    int attempts = 3,
  }) async {
    if (_controller == null || !_controller!.value.isInitialized) return null;
    Uint8List? bestBytes;
    double best = -1;

    for (int a = 0; a < attempts; a++) {
      bestBytes = null;
      best = -1;
      for (int i = 0; i < count; i++) {
        final xf = await _controller!.takePicture();
        final bytes = await xf.readAsBytes();

        final bright = meanBrightness(bytes);
        final glare = glareRatio(bytes);

        if (bright < 0.18) {
          // темно → подсказка и пробуем включить «torch»
          try {
            await _controller!.setFlashMode(FlashMode.torch);
          } catch (_) {}
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(S.of(context).t('too_dark'))),
            );
          }
        } else if (glare > 0.02) {
          // блики → подсказка и выключим вспышку
          try {
            await _controller!.setFlashMode(FlashMode.off);
          } catch (_) {}
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(S.of(context).t('too_glare'))),
            );
          }
        }

        final s = sharpnessFromBytes(bytes);
        if (s > best) {
          best = s;
          bestBytes = bytes;
        }
        await Future.delayed(const Duration(milliseconds: 150));
      }
      if (best >= minSharp) break; // достаточно резкий кадр получили
    }
    return bestBytes;
  }

  Future<void> _shootSeries() async {
    if (!_ready) return;

    // Если задана пересъёмка только одной стороны
    if (widget.onlySide != null) {
      final best = await _captureBestOf(3, minSharp: 200.0, attempts: 3);
      if (best == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory(p.join(dir.path, 'exams', widget.examId));
      await folder.create(recursive: true);

      if (widget.onlySide == EyeSide.left) {
        final leftPath = p.join(folder.path, 'left.jpg');
        final cropped =
            cropIrisCenterCircle(best, radiusFactor: 0.32, maxSide: 1500);
        await File(leftPath).writeAsBytes(cropped, flush: true);
      } else {
        final rightPath = p.join(folder.path, 'right.jpg');
        final cropped =
            cropIrisCenterCircle(best, radiusFactor: 0.32, maxSide: 1500);
        await File(rightPath).writeAsBytes(cropped, flush: true);
      }

      // Возвращаемся назад (пересъёмка завершена)
      if (!mounted) return;
      Navigator.of(context).maybePop();
      return;
    }

    // Режим мастера: сначала левый, затем правый
    if (!_leftDone) {
      final best = await _captureBestOf(3, minSharp: 200.0, attempts: 3);
      if (best == null) return;
      setState(() {
        _leftBestBytes = best;
        _leftDone = true;
      });
      return;
    }

    if (_leftDone && _rightBestBytes == null) {
      final best = await _captureBestOf(3, minSharp: 200.0, attempts: 3);
      if (best == null) return;
      setState(() {
        _rightBestBytes = best;
      });
      await _persistAndAnalyze();
    }
  }

  Future<void> _persistAndAnalyze() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'exams', widget.examId));
    await folder.create(recursive: true);

    final leftPath = p.join(folder.path, 'left.jpg');
    final rightPath = p.join(folder.path, 'right.jpg');

    if (_leftBestBytes != null) {
      final cropped =
          cropIrisCenterCircle(_leftBestBytes!, radiusFactor: 0.32, maxSide: 1500);
      await File(leftPath).writeAsBytes(cropped, flush: true);
    }
    if (_rightBestBytes != null) {
      final cropped =
          cropIrisCenterCircle(_rightBestBytes!, radiusFactor: 0.32, maxSide: 1500);
      await File(rightPath).writeAsBytes(cropped, flush: true);
    }

    // Передаём возраст/пол только если заданы.
    final result = await DiagnosisService.analyzeAndSave(
      examId: widget.examId,
      leftPath: leftPath,
      rightPath: rightPath,
      age: widget.age,
      gender: widget.gender,
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DiagnosisSummaryScreen(
          examId: widget.examId,
          leftPath: leftPath,
          rightPath: rightPath,
          aiResult: result, // aiResult может быть nullable на экране
        ),
      ),
    );
  }

  Widget _previewWithOverlay() {
    return Stack(
      children: [
        CameraPreview(_controller!),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _IrisRingPainter()),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  S.of(context).t('place_in_ring'),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final takingLeft =
        widget.onlySide == null ? !_leftDone : (widget.onlySide == EyeSide.left);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Съёмка: ${takingLeft ? "ЛЕВЫЙ" : "ПРАВЫЙ"} глаз • ${widget.examId.substring(0, 8)}',
        ),
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned.fill(child: _previewWithOverlay()),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: FilledButton.tonal(
                      onPressed: _shootSeries,
                      child: Text(
                        takingLeft
                            ? S.of(context).t('shoot_left')
                            : S.of(context).t('shoot_right'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _IrisRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide * 0.32);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xCCFFFFFF);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
