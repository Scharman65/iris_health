import 'dart:math' as math;
import 'dart:ui';

/// Нормализация/утилиты для работы с "кольцом радужки" и координатами.
class IrisNormalize {
  /// Нормирует точку внутри прямоугольника (0..1 по каждой оси).
  static Offset toNormalized(Offset p, Size size) {
    if (size.width <= 0 || size.height <= 0) return const Offset(0.5, 0.5);

    final nx = (p.dx / size.width).clamp(0.0, 1.0);
    final ny = (p.dy / size.height).clamp(0.0, 1.0);
    return Offset(nx, ny);
  }

  /// Превращает нормализованную точку (0..1) обратно в пиксели.
  static Offset fromNormalized(Offset n, Size size) {
    final x = (n.dx.clamp(0.0, 1.0)) * size.width;
    final y = (n.dy.clamp(0.0, 1.0)) * size.height;
    return Offset(x, y);
  }

  /// Рекомендуемый радиус кольца (в пикселях) от меньшей стороны.
  static double ringRadius(Size size, {double factor = 0.33}) {
    final shortest = math.min(size.width, size.height);
    if (shortest <= 0) return 0.0;
    return shortest * factor;
  }
}
