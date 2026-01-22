import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

double _varianceOfLaplacian(img.Image gray) {
  final w = gray.width, h = gray.height;
  const k = <int>[-1,-1,-1,-1,8,-1,-1,-1,-1];
  double sum = 0.0, sum2 = 0.0;
  int n = 0;
  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      int acc = 0, ki = 0;
      for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
          final p = gray.getPixel(x + i, y + j);
          final int v = (p.r as num).toInt();
          acc += v * k[ki++];
        }
      }
      final double d = acc.toDouble();
      sum += d;
      sum2 += d * d;
      n++;
    }
  }
  if (n == 0) return 0.0;
  final mean = sum / n;
  final variance = (sum2 / n) - mean * mean;
  return variance.isNaN ? 0.0 : variance;
}

img.Image _fitWithin(img.Image src, int maxSide) {
  final w = src.width, h = src.height;
  final maxSrc = math.max(w, h);
  if (maxSrc <= maxSide) return src;
  final scale = maxSide / maxSrc;
  return img.copyResize(
    src,
    width: (w * scale).round(),
    height: (h * scale).round(),
    interpolation: img.Interpolation.linear,
  );
}

Future<double> computeSharpnessLaplacian(File file) async {
  final bytes = await file.readAsBytes();
  return sharpnessFromBytes(bytes);
}

double sharpnessFromBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return 0.0;
  final base = _fitWithin(decoded, 640);
  final gray = img.grayscale(base);
  return _varianceOfLaplacian(gray);
}

Future<double> sharpnessFromBytesAsync(Uint8List bytes) async => sharpnessFromBytes(bytes);
Future<double> computeSharpness(File file) => computeSharpnessLaplacian(file);
Future<double> varianceOfLaplacian(File file) => computeSharpnessLaplacian(file);
Future<double> sharpnessScore(File file) => computeSharpnessLaplacian(file);

bool isSharpFromBytes(Uint8List bytes, {double threshold = 180.0}) => sharpnessFromBytes(bytes) >= threshold;
Future<bool> isSharp(File file, {double threshold = 180.0}) async => (await computeSharpnessLaplacian(file)) >= threshold;
