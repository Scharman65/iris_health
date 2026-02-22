import 'dart:typed_data';

/// Утилиты качества (быстрые эвристики).
/// Здесь главное — не "идеальная наука", а стабильная фильтрация мусора.
class QualityUtils {
  /// Средняя яркость (0..255) по grayscale байтам.
  static double meanLuma(Uint8List gray) {
    if (gray.isEmpty) return 0.0;

    int sum = 0;
    for (final v in gray) {
      sum += v;
    }
    return sum / gray.length;
  }

  /// Контраст как стандартное отклонение яркости.
  static double stdLuma(Uint8List gray) {
    if (gray.isEmpty) return 0.0;

    final mean = meanLuma(gray);
    double acc = 0.0;
    for (final v in gray) {
      final d = v - mean;
      acc += d * d;
    }
    return (acc / gray.length).sqrt();
  }

  /// Быстрая оценка "пересвет/недосвет".
  /// Возвращает true если снимок явно плох по экспозиции.
  static bool badExposure(
    Uint8List gray, {
    double minMean = 35.0,
    double maxMean = 220.0,
  }) {
    final m = meanLuma(gray);
    return m < minMean || m > maxMean;
  }
}

extension on double {
  double sqrt() => (this <= 0) ? 0.0 : (this).powHalf();
  double powHalf() {
    // очень лёгкий sqrt без math import (и без cast-ов)
    // Newton-Raphson:
    double x = this;
    double r = x;
    for (int i = 0; i < 8; i++) {
      if (r == 0) return 0.0;
      r = 0.5 * (r + x / r);
    }
    return r;
  }
}
