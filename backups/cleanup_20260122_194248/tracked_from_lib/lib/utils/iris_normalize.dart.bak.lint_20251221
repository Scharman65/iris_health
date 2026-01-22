import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Ищем центр зрачка: берём градации серого, сканируем небольшую область вокруг центра и
/// ищем окно с минимальной средней яркостью. Быстро и устойчиво на большинстве телефонов.
({double cx, double cy}) estimatePupilCenter(img.Image gray){
  final w = gray.width, h = gray.height;
  final cx0 = w/2.0, cy0 = h/2.0;
  final radius = (math.min(w, h) * 0.08).clamp(8, 64); // окно ~8–64px
  final step = (radius / 3).clamp(3, 16).toInt();       // шаг сетки
  double bestMean = 1e9, bestCx = cx0, bestCy = cy0;

  int clampi(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

  for (int dy = -step*2; dy <= step*2; dy += step) {
    for (int dx = -step*2; dx <= step*2; dx += step) {
      final cx = cx0 + dx;
      final cy = cy0 + dy;
      int x0 = clampi((cx - radius).round(), 0, w-1);
      int y0 = clampi((cy - radius).round(), 0, h-1);
      int x1 = clampi((cx + radius).round(), 0, w-1);
      int y1 = clampi((cy + radius).round(), 0, h-1);
      int sum = 0, cnt = 0;
      for (int y = y0; y <= y1; y++){
        for (int x = x0; x <= x1; x++){
          final p = gray.getPixel(x,y);
          final int v = (p.r as num).toInt();
          sum += v; cnt++;
        }
      }
      final mean = sum / (cnt.toDouble());
      if (mean < bestMean){
        bestMean = mean; bestCx = cx; bestCy = cy;
      }
    }
  }
  return (cx: bestCx, cy: bestCy);
}

/// Нормализуем: центр по зрачку, радиус = radiusFactor*minSide, всё вне круга — серым.
Uint8List normalizeIrisCircle(Uint8List bytes, {double radiusFactor = 0.32, int maxSide=1500}){
  final src = img.decodeImage(bytes);
  if (src == null) return bytes;

  final base = _fitWithin(src, maxSide);
  final gray = img.grayscale(base);
  final center = estimatePupilCenter(gray);

  final w = base.width, h = base.height;
  final r = math.min(w, h) * radiusFactor;
  final r2 = r*r;

  final out = img.Image.from(base);
  for (int y=0; y<h; y++){
    final dy = y - center.cy;
    for (int x=0; x<w; x++){
      final dx = x - center.cx;
      if ((dx*dx + dy*dy) > r2){
        out.setPixelRgba(x, y, 46, 46, 46, 255); // 18% серый фон
      }
    }
  }
  return Uint8List.fromList(img.encodeJpg(out, quality: 95));
}

img.Image _fitWithin(img.Image src, int maxSide){
  final m = math.max(src.width, src.height);
  if (m <= maxSide) return src;
  final s = maxSide/m;
  return img.copyResize(src,
    width: (src.width*s).round(),
    height: (src.height*s).round(),
    interpolation: img.Interpolation.linear,
  );
}
