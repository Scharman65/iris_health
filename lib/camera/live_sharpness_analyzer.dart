// lib/camera/live_sharpness_analyzer.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'macro_profile.dart';

/// =================================================================
/// LiveSharpnessAnalyzer v4.5 PRO — Medical Edition
/// =================================================================
/// Медицинская версия:
///   • НЕТ print()
///   • НЕТ логирования
///   • НЕТ перегрузки консоли
///   • Минимальная задержка
///   • Медицински надёжный ready = резкость + стабильность
///
/// Выдаёт:
///   sharpness, threshold, stable, ready, calibrated
/// =================================================================

class LiveSharpnessAnalyzer {
  final StreamController<Map<String, dynamic>> _stream =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _stream.stream;

  bool _busy = false;
  Uint8List? _prevY;

  final int warmupFrames;
  int _frameCount = 0;

  double _calibratedThreshold = 28.0;
  bool _calibrated = false;

  double _motionThreshold;

  final MacroProfile profile;

  LiveSharpnessAnalyzer({
    required this.profile,
    this.warmupFrames = 20,
    double motionThreshold = 10.0,
  }) : _motionThreshold = motionThreshold {
    // Коррекция motionThreshold по размеру пикселя сенсора
    _motionThreshold += math.max(0, (1.7 - profile.pixelSizeMicrons) * 8);
  }

  /// =================================================================
  /// Обработка входящего кадра камеры
  /// =================================================================
  void handleCameraImage(CameraImage image) {
    if (_busy) return;
    _busy = true;

    try {
      final y = image.planes.first.bytes;
      final w = image.width;
      final h = image.height;

      final sharp = _estimateSharpness(y, w, h);
      final stable = _estimateMotion(y);

      // --- Калибровка ---
      if (!_calibrated) {
        _frameCount++;

        final weight = 1 + (profile.aperture - 1.6) * 0.25;

        _calibratedThreshold =
            (_calibratedThreshold * (_frameCount - 1) + sharp * weight) /
                _frameCount;

        if (_frameCount >= warmupFrames) {
          _calibratedThreshold =
              math.min(_calibratedThreshold * 1.18, _calibratedThreshold + 35);

          _calibrated = true;
        }
      }

      final threshold = _calibrated
          ? _calibratedThreshold
          : (sharp * 1.25);

      final ready = sharp >= threshold && stable;

      // Стрим обновления UI
      if (!_stream.isClosed) {
        _stream.add({
          "sharpness": sharp,
          "threshold": threshold,
          "stable": stable,
          "ready": ready,
          "calibrated": _calibrated,
        });
      }

    } catch (_) {
      if (!_stream.isClosed) {
        _stream.add({
          "sharpness": 0.0,
          "threshold": _calibratedThreshold,
          "stable": false,
          "ready": false,
          "calibrated": _calibrated,
        });
      }
    } finally {
      _busy = false;
    }
  }

  /// =================================================================
  /// Быстрый расчёт резкости (дисперсия градиента)
  /// =================================================================
  double _estimateSharpness(Uint8List y, int w, int h) {
    double sum = 0, sum2 = 0;
    int cnt = 0;

    const step = 3;
    final hLim = h - step;
    final wLim = w - step;

    for (int yy = step; yy < hLim; yy += step) {
      final row = yy * w;
      for (int xx = step; xx < wLim; xx += step) {
        final i = row + xx;
        final c = y[i];
        final r = y[i + 1];
        final b = y[i + w];

        final v = (r - c).abs() + (b - c).abs();

        sum += v;
        sum2 += v * v;
        cnt++;
      }
    }

    if (cnt == 0) return 0.0;

    final mean = sum / cnt;
    return sum2 / cnt - mean * mean;
  }

  /// =================================================================
  /// Оценка движения руки (межкадровая разница)
  /// =================================================================
  bool _estimateMotion(Uint8List yPlane) {
    if (_prevY == null) {
      _prevY = Uint8List.fromList(yPlane);
      return false;
    }

    final prev = _prevY!;
    _prevY = Uint8List.fromList(yPlane);

    final len = math.min(prev.length, yPlane.length);
    const sample = 5000;

    int diff = 0;
    for (int i = 0; i < sample; i++) {
      final idx = (i * 73) % len;
      if ((prev[idx] - yPlane[idx]).abs() > 14) diff++;
    }

    final motion = diff / sample * 100.0;
    return motion < _motionThreshold;
  }

  /// =================================================================
  /// Очистка
  /// =================================================================
  void dispose() {
    if (!_stream.isClosed) _stream.close();
    _prevY = null;
  }
}
