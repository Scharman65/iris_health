import 'package:flutter/material.dart';

class IrisRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.30;

    // 1) Внешний прямоугольник (всё поле)
    final outerPath = Path()..addRect(Offset.zero & size);

    // 2) Круг в центре — окно для зрачка
    final innerPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));

    // 3) Разность: затемняем всё, КРОМЕ круга
    final maskPath = Path.combine(
      PathOperation.difference,
      outerPath,
      innerPath,
    );

    final dimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 140)
      ..style = PaintingStyle.fill;

    canvas.drawPath(maskPath, dimPaint);

    // 4) Контур кольца
    final ringPaint = Paint()
      ..color = const Color.fromARGB(220, 0, 200, 255)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius, ringPaint);

    // 5) Лёгкое свечение по краю
    final glowPaint = Paint()
      ..color = const Color.fromARGB(120, 0, 200, 255)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

    canvas.drawCircle(center, radius, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

