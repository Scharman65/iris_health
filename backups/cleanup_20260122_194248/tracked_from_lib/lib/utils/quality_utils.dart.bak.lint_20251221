import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Средняя яркость кадра [0..1]
double meanBrightness(Uint8List bytes){
  final im = img.decodeImage(bytes); if (im==null) return 0.0;
  final g = img.grayscale(im);
  final w=g.width, h=g.height;
  int sum = 0;
  for (int y=0; y<h; y++){
    for (int x=0; x<w; x++){
      final int v = (g.getPixel(x,y).r as num).toInt();
      sum += v;
    }
  }
  return (sum/(w*h))/255.0;
}

/// Доля «почти белых» пикселей (простая метрика бликов)
double glareRatio(Uint8List bytes,{int threshold=240}){
  final im = img.decodeImage(bytes); if (im==null) return 0.0;
  final w=im.width, h=im.height;
  int c=0, tot=w*h;
  for (int y=0; y<h; y++){
    for (int x=0; x<w; x++){
      final p = im.getPixel(x,y);
      final int r = (p.r as num).toInt();
      final int g = (p.g as num).toInt();
      final int b = (p.b as num).toInt();
      if (r>=threshold && g>=threshold && b>=threshold) c++;
    }
  }
  return c / (tot.toDouble());
}
