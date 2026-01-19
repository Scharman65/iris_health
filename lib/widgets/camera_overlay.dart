import 'package:flutter/material.dart';

class CameraOverlay extends StatelessWidget {
  final double sharpness;
  final double threshold;
  final bool stable;
  final bool ready;
  final bool calibrated;

  const CameraOverlay({
    super.key,
    required this.sharpness,
    required this.threshold,
    required this.stable,
    required this.ready,
    required this.calibrated,
  });

  @override
  Widget build(BuildContext context) {
    final ok = calibrated && stable && ready && sharpness >= threshold;

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RingPainter(),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: _Hud(
              sharpness: sharpness,
              threshold: threshold,
              stable: stable,
              ready: ready,
              calibrated: calibrated,
              ok: ok,
            ),
          ),
        ],
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  final double sharpness;
  final double threshold;
  final bool stable;
  final bool ready;
  final bool calibrated;
  final bool ok;

  const _Hud({
    required this.sharpness,
    required this.threshold,
    required this.stable,
    required this.ready,
    required this.calibrated,
    required this.ok,
  });

  Widget _line(ThemeData theme, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(k, style: theme.textTheme.bodySmall)),
          Text(v, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 89),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 31)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ok ? 'Готово к снимку' : 'Стабилизируйте кадр',
              style: theme.textTheme.titleSmall?.copyWith(
                color: ok ? Colors.greenAccent.withValues(alpha: 242) : Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            _line(theme, 'Резкость', sharpness.toStringAsFixed(1)),
            _line(theme, 'Порог', threshold.toStringAsFixed(1)),
            _line(theme, 'Стабильно', stable ? 'да' : 'нет'),
            _line(theme, 'Кадр ready', ready ? 'да' : 'нет'),
            _line(theme, 'Калибровка', calibrated ? 'да' : 'нет'),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final r = shortest * 0.33;

    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (shortest * 0.006).clamp(2.0, 6.0);

    p.color = Colors.white.withValues(alpha: 191);
    canvas.drawCircle(center, r, p);

    p.color = Colors.white.withValues(alpha: 89);
    canvas.drawCircle(center, r * 0.72, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
