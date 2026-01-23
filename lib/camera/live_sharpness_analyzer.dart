import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';

import 'macro_profile.dart';

class LiveSharpnessAnalyzer {
  final StreamController<Map<String, dynamic>> _stream =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _stream.stream;

  bool _busy = false;

  Uint8List? _prevSample;

  final int warmupFrames;
  int _frameCount = 0;

  double _calibratedThreshold = 28.0;
  bool _calibrated = false;

  double _motionThreshold;

  double _lastMotionPct = 100.0;

  final MacroProfile profile;

  final int stableWindow;
  final int stableMinOk;
  final List<bool> _stableHist = <bool>[];

  final int readyHoldMs;
  int _readyUntilEpochMs = 0;

  LiveSharpnessAnalyzer({
    required this.profile,
    this.warmupFrames = 20,
    double motionThreshold = 10.0,
    this.stableWindow = 7,
    int? stableMinOk,
    this.readyHoldMs = 550,
  })  : _motionThreshold = motionThreshold,
        stableMinOk = stableMinOk ?? 5 {
    _motionThreshold += math.max(0, (1.7 - profile.pixelSizeMicrons) * 8);
  }

  void handleCameraImage(CameraImage image) {
    if (_busy) return;
    _busy = true;

    try {
      final fmt = image.format.group;

      double sharp = 0.0;
      bool stableRaw = false;

      if (fmt == ImageFormatGroup.yuv420) {
        final yPlane = image.planes[0];
        final bytes = yPlane.bytes;
        final w = image.width;
        final h = image.height;
        final stride = yPlane.bytesPerRow;

        sharp = _estimateSharpnessY(bytes, w, h, stride);
        stableRaw = _estimateMotionY(bytes, w, h, stride);
      } else if (fmt == ImageFormatGroup.bgra8888) {
        final p = image.planes[0];
        final bytes = p.bytes;
        final w = image.width;
        final h = image.height;
        final stride = p.bytesPerRow;

        sharp = _estimateSharpnessBGRA(bytes, w, h, stride);
        stableRaw = _estimateMotionBGRA(bytes, w, h, stride);
      } else {
        sharp = 0.0;
        stableRaw = false;
        _lastMotionPct = 100.0;
      }

      _stableHist.add(stableRaw);
      if (_stableHist.length > stableWindow) {
        _stableHist.removeAt(0);
      }
      final ok = _stableHist.where((v) => v).length;
      final stable = ok >= stableMinOk;

      if (!_calibrated) {
        _frameCount++;

        final weight = 1 + (profile.aperture - 1.6) * 0.25;
        _calibratedThreshold =
            (_calibratedThreshold * (_frameCount - 1) + sharp * weight) /
                _frameCount;

        if (_frameCount >= warmupFrames) {
          _calibratedThreshold =
              math.min(_calibratedThreshold * 1.10, _calibratedThreshold + 25);
          _calibrated = true;
        }
      }

      final threshold =
          _calibrated ? _calibratedThreshold : math.max(12.0, sharp * 1.10);

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final readyRaw = sharp >= threshold && stable;

      if (readyRaw) {
        _readyUntilEpochMs = nowMs + readyHoldMs;
      }

      final ready = readyRaw || (nowMs <= _readyUntilEpochMs);

      if (!_stream.isClosed) {
        _stream.add({
          "sharpness": sharp,
          "threshold": threshold,
          "stable": stable,
          "ready": ready,
          "calibrated": _calibrated,
          "stable_ok": ok,
          "stable_n": _stableHist.length,
          "motion_pct": _lastMotionPct,
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
          "stable_ok": 0,
          "stable_n": 0,
          "motion_pct": _lastMotionPct,
        });
      }
    } finally {
      _busy = false;
    }
  }

  double _estimateSharpnessY(Uint8List y, int w, int h, int stride) {
    double sum = 0, sum2 = 0;
    int cnt = 0;

    const step = 3;
    final hLim = h - step;
    final wLim = w - step;

    for (int yy = step; yy < hLim; yy += step) {
      final row = yy * stride;
      final rowDown = (yy + 1) * stride;

      for (int xx = step; xx < wLim; xx += step) {
        final i = row + xx;
        final c = y[i];
        final r = y[i + 1];
        final b = y[rowDown + xx];

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

  bool _estimateMotionY(Uint8List y, int w, int h, int stride) {
    const sample = 2500;
    final cur = Uint8List(sample);

    for (int i = 0; i < sample; i++) {
      final yy = (i * 37) % h;
      final xx = (i * 73) % w;
      cur[i] = y[yy * stride + xx];
    }

    if (_prevSample == null) {
      _prevSample = cur;
      _lastMotionPct = 100.0;
      return false;
    }

    final prev = _prevSample!;
    _prevSample = cur;

    int diff = 0;
    for (int i = 0; i < sample; i++) {
      if ((prev[i] - cur[i]).abs() > 14) diff++;
    }

    final motion = diff / sample * 100.0;
    _lastMotionPct = motion;
    return motion < _motionThreshold;
  }

  double _estimateSharpnessBGRA(Uint8List bgra, int w, int h, int stride) {
    double sum = 0, sum2 = 0;
    int cnt = 0;

    const step = 3;
    final hLim = h - step;
    final wLim = w - step;

    for (int yy = step; yy < hLim; yy += step) {
      final row = yy * stride;
      final rowDown = (yy + 1) * stride;

      for (int xx = step; xx < wLim; xx += step) {
        final i = row + xx * 4;
        final j = rowDown + xx * 4;

        final c = _lumaFromBGRA(bgra, i);
        final r = _lumaFromBGRA(bgra, i + 4);
        final b = _lumaFromBGRA(bgra, j);

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

  bool _estimateMotionBGRA(Uint8List bgra, int w, int h, int stride) {
    const sample = 2500;
    final cur = Uint8List(sample);

    for (int i = 0; i < sample; i++) {
      final yy = (i * 37) % h;
      final xx = (i * 73) % w;
      final idx = yy * stride + xx * 4;
      cur[i] = _lumaFromBGRA(bgra, idx);
    }

    if (_prevSample == null) {
      _prevSample = cur;
      _lastMotionPct = 100.0;
      return false;
    }

    final prev = _prevSample!;
    _prevSample = cur;

    int diff = 0;
    for (int i = 0; i < sample; i++) {
      if ((prev[i] - cur[i]).abs() > 14) diff++;
    }

    final motion = diff / sample * 100.0;
    _lastMotionPct = motion;
    return motion < _motionThreshold;
  }

  int _lumaFromBGRA(Uint8List bgra, int i) {
    final b = bgra[i];
    final g = bgra[i + 1];
    final r = bgra[i + 2];
    return ((r * 54 + g * 183 + b * 19) >> 8);
  }

  void dispose() {
    if (!_stream.isClosed) _stream.close();
    _prevSample = null;
    _stableHist.clear();
    _readyUntilEpochMs = 0;
  }
}
