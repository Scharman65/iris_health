import 'dart:math' as math;
import 'dart:typed_data';

/// Простая метрика резкости на основе суммы градиентов (очень быстрая).
/// Возвращает значение "чем больше, тем резче".
double sharpnessScoreGray8({
  required Uint8List gray,
  required int width,
  required int height,
  int step = 2,
}) {
  if (width <= 2 || height <= 2) return 0.0;
  if (gray.isEmpty) return 0.0;

  double acc = 0.0;
  int count = 0;

  // пропускаем границы
  for (int y = 1; y < height - 1; y += step) {
    final row = y * width;
    final rowUp = (y - 1) * width;
    final rowDn = (y + 1) * width;

    for (int x = 1; x < width - 1; x += step) {
      final i = row + x;

      final gx = gray[i + 1] - gray[i - 1];
      final gy = gray[rowDn + x] - gray[rowUp + x];

      acc += (gx.abs() + gy.abs()).toDouble();
      count++;
    }
  }

  if (count == 0) return 0.0;

  // нормализация (чтобы не зависеть сильно от размера)
  final norm = acc / count;
  return math.max(0.0, norm);
}
