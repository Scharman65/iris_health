import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Модель зоны: [ring] 0..(rings-1), [sector] 0..(sectors-1)
class IrisZone {
  final int ring;
  final int sector;
  const IrisZone(this.ring, this.sector);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IrisZone && ring == other.ring && sector == other.sector;

  @override
  int get hashCode => Object.hash(ring, sector);
}

/// Полупрозрачный оверлей поверх нормализованного «круглого» снимка радужки.
/// Рисует сетку и подсвечивает выбранные сектора.
class IrisZonesOverlay extends StatelessWidget {
  final Set<IrisZone> highlights;
  final int rings;
  final int sectors;
  final double irisRadiusFactor; // должно совпадать с normalizeIrisCircle

  const IrisZonesOverlay({
    super.key,
    required this.highlights,
    this.rings = 3,
    this.sectors = 12,
    this.irisRadiusFactor = 0.32,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _IrisZonesPainter(
        highlights: highlights,
        rings: rings,
        sectors: sectors,
        irisRadiusFactor: irisRadiusFactor,
      ),
    );
  }
}

class _IrisZonesPainter extends CustomPainter {
  final Set<IrisZone> highlights;
  final int rings;
  final int sectors;
  final double irisRadiusFactor;

  _IrisZonesPainter({
    required this.highlights,
    required this.rings,
    required this.sectors,
    required this.irisRadiusFactor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final R = math.min(size.width, size.height) * irisRadiusFactor;

    // Фон за пределами круга чуть затемним (необязательно, но красиво)
    canvas.save();
    final clip = Path()..addOval(Rect.fromCircle(center: center, radius: R));
    canvas.clipPath(clip);
    canvas.restore();

    // Сетка
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x66FFFFFF);

    // Кольца
    for (int r = 1; r <= rings; r++) {
      final rr = R * r / rings;
      canvas.drawCircle(center, rr, grid);
    }

    // Радиальные линии
    for (int s = 0; s < sectors; s++) {
      final a = -math.pi / 2 + 2 * math.pi * (s / sectors);
      final p2 = Offset(center.dx + R * math.cos(a), center.dy + R * math.sin(a));
      canvas.drawLine(center, p2, grid);
    }

    // Подсветка выбранных зон
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0x44FF3B30); // полупрозрачный красный

    for (final z in highlights) {
      if (z.ring < 0 || z.ring >= rings || z.sector < 0 || z.sector >= sectors) continue;

      final r0 = R * z.ring / rings;
      final r1 = R * (z.ring + 1) / rings;

      final a0 = -math.pi / 2 + 2 * math.pi * (z.sector / sectors);
      final a1 = -math.pi / 2 + 2 * math.pi * ((z.sector + 1) / sectors);

      final path = Path();
      // внешний дуговой сегмент
      path.addArc(Rect.fromCircle(center: center, radius: r1), a0, a1 - a0);
      // соединение к внутреннему радиусу
      final innerTo = Offset(center.dx + r0 * math.cos(a1), center.dy + r0 * math.sin(a1));
      path.lineTo(innerTo.dx, innerTo.dy);
      // внутренняя дуга в обратную сторону
      path.addArc(Rect.fromCircle(center: center, radius: r0), a1, -(a1 - a0));
      path.lineTo(
        center.dx + r1 * math.cos(a0),
        center.dy + r1 * math.sin(a0),
      );
      path.close();

      canvas.drawPath(path, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _IrisZonesPainter old) {
    return old.highlights != highlights ||
        old.rings != rings ||
        old.sectors != sectors ||
        old.irisRadiusFactor != irisRadiusFactor;
  }
}
