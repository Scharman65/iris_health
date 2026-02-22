// lib/screens/camera_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/diagnosis_service.dart';

import '../camera/camera_orchestrator.dart';
import '../camera/live_sharpness_analyzer.dart';
import '../camera/macro_profile_storage.dart';
import '../widgets/camera_overlay.dart';
import 'diagnosis_summary_screen.dart';

// AI base URL is managed via AiClient (SharedPreferences + default fallback).

class CameraScreen extends StatefulWidget {
  final String examId;
  final int age;
  final String gender;

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
  CameraOrchestrator? _orchestrator;
  CameraController? _controller;

  Uint8List? _left;
  Uint8List? _right;

  bool _leftDone = false;
  bool _rightDone = false;

  bool _initializing = true;
  bool _capturing = false;
  bool _sending = false;

  LiveSharpnessAnalyzer? _sharp;

  double _liveSharpness = 0.0;
  double _adaptiveThreshold = 0.0;
  bool _stable = false;
  bool _readyFrame = false;
  bool _calibrated = false;

  int _stableOk = 0;
  int _stableN = 0;
  double _motionPct = 100.0;

  bool get _bothDone => _leftDone && _rightDone;

  bool _focusLocked = false;
  Offset? _focusTapPos;
  Timer? _focusHideTimer;

  @override
  void initState() {
    super.initState();
    _initPipeline();
  }

  @override
  void dispose() {
    _focusHideTimer?.cancel();
    try {
      _controller?.dispose();
    } catch (_) {}
    try {
      _sharp?.dispose();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _initPipeline() async {
    try {
      final cams = await availableCameras();

      CameraDescription selectedCamera = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );

      final telephoto = cams.where(
        (c) =>
            c.lensDirection == CameraLensDirection.back &&
            c.name.toLowerCase().contains('tele'),
      );
      if (telephoto.isNotEmpty) {
        selectedCamera = telephoto.first;
      }

      final tmp = CameraController(
        selectedCamera,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await tmp.initialize();

      final storage = MacroProfileStorage();
      final profile = await storage.loadOrCreateProfile(tmp);

      await tmp.dispose();

      _sharp = LiveSharpnessAnalyzer(profile: profile);

      final orch = CameraOrchestrator(profile);
      await orch.initialize();

      final controller = orch.controller;

      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}
      try {
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}

      try {
        await controller.setFocusPoint(const Offset(0.5, 0.5));
      } catch (_) {}
      try {
        await controller.setExposurePoint(const Offset(0.5, 0.5));
      } catch (_) {}

      await _startStream(controller);

      _sharp!.stream.listen((data) {
        if (!mounted) return;
        setState(() {
          _liveSharpness = data['sharpness'] ?? 0.0;
          _adaptiveThreshold = data['threshold'] ?? 0.0;
          _stable = data['stable'] ?? false;
          _readyFrame = data['ready'] ?? false;
          _calibrated = data['calibrated'] ?? false;
          _stableOk = (data['stable_ok'] as int?) ?? 0;
          _stableN = (data['stable_n'] as int?) ?? 0;
          _motionPct = (data['motion_pct'] as num?)?.toDouble() ?? 100.0;
        });
      });

      if (!mounted) return;
      setState(() {
        _orchestrator = orch;
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _initializing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка камеры: $e')),
      );
    }
  }

  Future<void> _startStream(CameraController controller) async {
    if (controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 120));
    }

    await controller.startImageStream((CameraImage frame) {
      _sharp?.handleCameraImage(frame);
    });
  }

  Future<void> _capture(String side) async {
    if (_controller == null ||
        _orchestrator == null ||
        _capturing ||
        _sending) {
      return;
    }

    setState(() => _capturing = true);

    try {
      if (!_readyFrame || !_stable || !_calibrated) {
        throw 'Кадр ещё не стабилен. Резкость: ${_liveSharpness.toStringAsFixed(1)}, '
            'порог: ${_adaptiveThreshold.toStringAsFixed(1)}';
      }

      try {
        if (_controller!.value.isStreamingImages) {
          await _controller!.stopImageStream();
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 120));

      final best = await _orchestrator!.captureBestIris();

      if (!mounted) return;
      setState(() {
        if (side == 'left') {
          _left = best;
          _leftDone = true;
        } else {
          _right = best;
          _rightDone = true;
        }
      });

      await _startStream(_controller!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<String> _saveTempJpg(String side, Uint8List bytes) async {
    final dir = Directory.systemTemp;
    final safeId = widget.examId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final path = '${dir.path}/iris_${safeId}_$side.jpg';
    final f = File(path);
    await f.writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<void> _analyzeAndOpenSummary() async {
    if (_left == null || _right == null) return;
    if (_sending) return;

    setState(() => _sending = true);

    try {
      final leftBytes = _left!;
      final rightBytes = _right!;

      final leftPath = await _saveTempJpg('left', leftBytes);
      final rightPath = await _saveTempJpg('right', rightBytes);

      final service = DiagnosisService();

      final ui = await service.analyzePair(
        leftFile: File(leftPath),
        rightFile: File(rightPath),
        examId: widget.examId,
        age: widget.age,
        gender: widget.gender,
        locale: 'ru',
      );

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DiagnosisSummaryScreen(
            examId: widget.examId,
            leftPath: leftPath,
            rightPath: rightPath,
            aiResult: ui,
            age: widget.age,
            gender: widget.gender,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка AI: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _tapToFocus(
      TapDownDetails details, BoxConstraints constraints) async {
    final controller = _controller;
    if (controller == null) return;
    if (!controller.value.isInitialized) return;
    if (_capturing || _sending) return;

    final Size size = Size(constraints.maxWidth, constraints.maxHeight);
    final Offset local = details.localPosition;

    final double nx = (local.dx / size.width).clamp(0.0, 1.0);
    final double ny = (local.dy / size.height).clamp(0.0, 1.0);

    _focusHideTimer?.cancel();
    setState(() => _focusTapPos = local);
    _focusHideTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _focusTapPos = null);
    });

    try {
      await controller.setFocusPoint(Offset(nx, ny));
    } catch (_) {}
    try {
      await controller.setExposurePoint(Offset(nx, ny));
    } catch (_) {}

    try {
      await controller
          .setFocusMode(_focusLocked ? FocusMode.locked : FocusMode.auto);
    } catch (_) {}

    try {
      await controller.setExposureMode(ExposureMode.auto);
    } catch (_) {}
  }

  Future<void> _setFocusLocked(bool locked) async {
    final controller = _controller;
    setState(() => _focusLocked = locked);
    if (controller == null) return;
    try {
      await controller.setFocusMode(locked ? FocusMode.locked : FocusMode.auto);
    } catch (_) {}
  }

  Future<void> _focusCenter() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      await controller.setFocusPoint(const Offset(0.5, 0.5));
    } catch (_) {}
    try {
      await controller.setExposurePoint(const Offset(0.5, 0.5));
    } catch (_) {}

    try {
      await controller.setExposureMode(ExposureMode.auto);
    } catch (_) {}
    try {
      await controller
          .setFocusMode(_focusLocked ? FocusMode.locked : FocusMode.auto);
    } catch (_) {}

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rb = context.findRenderObject();
      if (rb is RenderBox) {
        final s = rb.size;
        _focusHideTimer?.cancel();
        setState(() => _focusTapPos = Offset(s.width / 2, s.height / 2));
        _focusHideTimer = Timer(const Duration(milliseconds: 700), () {
          if (!mounted) return;
          setState(() => _focusTapPos = null);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = !_leftDone
        ? 'Фото левого глаза'
        : (!_rightDone ? 'Фото правого глаза' : 'Готово');

    final frameOk = _calibrated &&
        _stable &&
        _readyFrame &&
        (_liveSharpness >= _adaptiveThreshold);
    final canShootNow = (!_bothDone) ? frameOk : true;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: _focusLocked ? 'AF Lock: ON' : 'AF Lock: OFF',
            onPressed: (_controller == null || _capturing || _sending)
                ? null
                : () => _setFocusLocked(!_focusLocked),
            icon: Icon(_focusLocked ? Icons.lock : Icons.lock_open),
          ),
          IconButton(
            tooltip: 'Фокус в центр',
            onPressed: (_controller == null || _capturing || _sending)
                ? null
                : _focusCenter,
            icon: const Icon(Icons.center_focus_strong),
          ),
        ],
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : (_controller == null
              ? const Center(child: Text('Камера недоступна'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (d) => _tapToFocus(d, constraints),
                            child: CameraPreview(_controller!),
                          ),
                        ),
                        Positioned.fill(
                          child: CameraOverlay(
                            sharpness: _liveSharpness,
                            threshold: _adaptiveThreshold,
                            stable: _stable,
                            ready: _readyFrame,
                            calibrated: _calibrated,
                            stableOk: _stableOk,
                            stableN: _stableN,
                            motionPct: _motionPct,
                          ),
                        ),
                        if (_focusTapPos != null)
                          Positioned(
                            left: (_focusTapPos!.dx - 22)
                                .clamp(0.0, constraints.maxWidth - 44),
                            top: (_focusTapPos!.dy - 22)
                                .clamp(0.0, constraints.maxHeight - 44),
                            child: IgnorePointer(
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 217),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_sending)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: LinearProgressIndicator(),
                                ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'AF: ${_focusLocked ? "LOCK" : "AUTO"}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                  Text(
                                    'Sharp ${_liveSharpness.toStringAsFixed(1)} / Th ${_adaptiveThreshold.toStringAsFixed(1)}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (!_bothDone && !frameOk)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'Ждите зелёный индикатор (резкость/стабильность/калибровка)',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              FilledButton(
                                onPressed:
                                    (_capturing || _sending || !canShootNow)
                                        ? null
                                        : () async {
                                            if (!_leftDone) {
                                              await _capture('left');
                                            } else if (!_rightDone) {
                                              await _capture('right');
                                            } else {
                                              await _analyzeAndOpenSummary();
                                            }
                                          },
                                child: Text(
                                  !_leftDone
                                      ? 'Снять левый глаз'
                                      : (!_rightDone
                                          ? 'Снять правый глаз'
                                          : 'Анализ и итоги'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_bothDone)
                                OutlinedButton(
                                  onPressed: (_capturing || _sending)
                                      ? null
                                      : () {
                                          setState(() {
                                            _left = null;
                                            _right = null;
                                            _leftDone = false;
                                            _rightDone = false;
                                          });
                                        },
                                  child: const Text('Переснять оба'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                )),
    );
  }
}
