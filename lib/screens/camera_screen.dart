// lib/screens/camera_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/diagnosis_model.dart';
import '../services/diagnosis_service.dart';

class CameraScreen extends StatefulWidget {
  final int examId;
  final int age;
  final Gender gender;

  const CameraScreen({
    super.key,
    required this.examId,
    required this.age,
    required this.gender,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  String? _errorMessage;

  bool _isLeft = true;
  bool _isBusy = false;
  double _lastSharpness = 0.0;

  static const double _zoomLevel = 2.0;
  static const double _sharpnessThreshold = 100.0;
  static const int _maxAttemptsPerEye = 6;

  static const double _ringDiameterPx = 250.0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      final description = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );

      _controller = CameraController(
        description,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      await _controller!.setFlashMode(FlashMode.off);
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setExposureMode(ExposureMode.auto);
      await _controller!.setFocusPoint(const Offset(0.5, 0.5));
      await _controller!.setExposurePoint(const Offset(0.5, 0.5));

      try {
        await _controller!.setZoomLevel(_zoomLevel);
      } catch (_) {}

      setState(() => _isInitialized = true);

      unawaited(_autoCaptureCurrentEye());
    } catch (e) {
      setState(() => _errorMessage = 'Ошибка камеры: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _autoCaptureCurrentEye() async {
    if (!mounted || _isBusy) return;
    _isBusy = true;

    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      _isBusy = false;
      return;
    }

    for (int attempt = 1; attempt <= _maxAttemptsPerEye; attempt++) {
      try {
        await ctrl.setFocusMode(FocusMode.auto);
        await ctrl.setFocusPoint(const Offset(0.5, 0.5));
        await Future.delayed(const Duration(milliseconds: 280));

        final shot = await ctrl.takePicture();

        final sharp = await _estimateSharpness(File(shot.path));
        _lastSharpness = sharp;
        if (!mounted) return;
        setState(() {});

        if (sharp >= _sharpnessThreshold) {
          final cropped = await _cropToCircle(File(shot.path));
          await DiagnosisService().onEyeCaptured(
            context: context,
            examId: widget.examId,
            age: widget.age,
            gender: widget.gender,
            isLeftEye: _isLeft,
            imagePath: cropped,
          );

          if (_isLeft && mounted) {
            setState(() => _isLeft = false);
            await Future.delayed(const Duration(milliseconds: 400));
            _isBusy = false;
            unawaited(_autoCaptureCurrentEye());
            return;
          } else {
            _isBusy = false;
            return;
          }
        } else {
          await Future.delayed(const Duration(milliseconds: 420));
        }
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 480));
      }
    }

    _isBusy = false;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Не удалось получить чёткий кадр (${_isLeft ? "левый" : "правый"} глаз). '
          'Попробуйте нажать кнопку вручную.',
        ),
      ),
    );
  }

  Future<void> _manualCapture() async {
    if (_isBusy) return;
    _isBusy = true;

    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      _isBusy = false;
      return;
    }

    try {
      await ctrl.setFocusMode(FocusMode.auto);
      await ctrl.setFocusPoint(const Offset(0.5, 0.5));
      await Future.delayed(const Duration(milliseconds: 280));

      final shot = await ctrl.takePicture();

      final sharp = await _estimateSharpness(File(shot.path));
      _lastSharpness = sharp;
      if (!mounted) return;
      setState(() {});

      if (sharp < _sharpnessThreshold) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Кадр недостаточно резкий — попробуйте ещё раз')),
        );
        _isBusy = false;
        return;
      }

      final cropped = await _cropToCircle(File(shot.path));
      await DiagnosisService().onEyeCaptured(
        context: context,
        examId: widget.examId,
        age: widget.age,
        gender: widget.gender,
        isLeftEye: _isLeft,
        imagePath: cropped,
      );

      if (_isLeft) {
        setState(() => _isLeft = false);
        _isBusy = false;
        unawaited(_autoCaptureCurrentEye());
      } else {
        _isBusy = false;
      }
    } catch (e) {
      _isBusy = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Съёмка не удалась: $e')),
      );
    }
  }

  Future<double> _estimateSharpness(File file) async {
    final bytes = await file.readAsBytes();
    final src = img.decodeImage(bytes);
    if (src == null) return 0.0;

    final gray = img.grayscale(src);

    final w = gray.width, h = gray.height;
    final lap = img.Image(width: w, height: h);

    double sum = 0.0, sumSq = 0.0;
    int count = 0;

    double g(int x, int y) => img.getLuminance(gray.getPixel(x, y)).toDouble();

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final v = (g(x, y - 1) + g(x - 1, y) - 4 * g(x, y) + g(x + 1, y) + g(x, y + 1)).toDouble();
        sum += v;
        sumSq += v * v;
        count++;
      }
    }

    if (count == 0) return 0.0;
    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    return variance.isFinite ? variance : 0.0;
  }

  Future<String> _cropToCircle(File file) async {
    final bytes = await file.readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) return file.path;

    final size = min(original.width, original.height);
    final ox = (original.width - size) ~/ 2;
    final oy = (original.height - size) ~/ 2;
    final square = img.copyCrop(original, x: ox, y: oy, width: size, height: size);

    final circle = img.Image(width: size, height: size);
    img.fill(circle, color: img.ColorRgba8(0, 0, 0, 0));
    final r = size ~/ 2;
    final r2 = r * r;
    final cx = size ~/ 2;
    final cy = size ~/ 2;

    for (int y = 0; y < size; y++) {
      final dy = y - cy;
      for (int x = 0; x < size; x++) {
        final dx = x - cx;
        if (dx * dx + dy * dy <= r2) {
          circle.setPixel(x, y, square.getPixel(x, y));
        }
      }
    }

    final outPath = file.path.replaceFirst(
      RegExp(r'\.(jpg|jpeg|heic|png)$', caseSensitive: false),
      '',
    ) +
        (_isLeft ? '_left' : '_right') +
        '_circle.png';
    await File(outPath).writeAsBytes(img.encodePng(circle));
    return outPath;
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(body: Center(child: Text(_errorMessage!)));
    }
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(_controller!),
          _buildRingOverlay(),
          _buildTopStatus(),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildRingOverlay() {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: _ringDiameterPx,
          height: _ringDiameterPx,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.9), width: 3),
          ),
        ),
      ),
    );
  }

  Widget _buildTopStatus() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 12,
      right: 12,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${_isLeft ? "Левый" : "Правый"} глаз • резкость: ${_lastSharpness.toStringAsFixed(0)}'
            ' (порог ${_sharpnessThreshold.toStringAsFixed(0)})'
            '${_isBusy ? " • съёмка…" : ""}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 28,
      left: 0,
      right: 0,
      child: Center(
        child: ElevatedButton.icon(
          onPressed: _manualCapture,
          icon: const Icon(Icons.camera_alt),
          label: Text(_isLeft ? 'Сделать фото (левый)' : 'Сделать фото (правый)'),
        ),
      ),
    );
  }
}
