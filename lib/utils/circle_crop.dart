import 'dart:typed_data';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// Центрированная круговая маска радужки.
/// Всё вне круга закрашивается серым (18% серый), результат — JPEG.
Uint8List cropIrisCenterCircle(Uint8List bytes, {double radiusFactor = 0.32, int maxSide = 1500}) {
  final src = img.decodeImage(bytes);
  if (src == null) return bytes;

  final base = _fitWithin(src, maxSide);
  final w = base.width, h = base.height;
  final cx = w / 2.0, cy = h / 2.0;
  final r = math.min(w, h) * radiusFactor;
  final r2 = r * r;

  final out = img.Image.from(base);
  for (int y = 0; y < h; y++) {
    final dy = y - cy;
    for (int x = 0; x < w; x++) {
      final dx = x - cx;
      if ((dx * dx + dy * dy) > r2) {
        out.setPixelRgba(x, y, 46, 46, 46, 255); // серый фон
      }
    }
  }
  return Uint8List.fromList(img.encodeJpg(out, quality: 95));
}

img.Image _fitWithin(img.Image src, int maxSide) {
  final m = math.max(src.width, src.height);
  if (m <= maxSide) return src;
  final scale = maxSide / m;
  return img.copyResize(
    src,
    width: (src.width * scale).round(),
    height: (src.height * scale).round(),
    interpolation: img.Interpolation.linear,
  );
}
