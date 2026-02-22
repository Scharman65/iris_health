import 'package:flutter/material.dart';

class CameraOverlay extends StatelessWidget {
  final Offset ringOffset;
  final double sharpness;
  final double threshold;
  final bool stable;
  final bool ready;
  final bool calibrated;

  final int stableOk;
  final int stableN;
  final double motionPct;

  const CameraOverlay({
    this.ringOffset = Offset.zero,
    super.key,
    required this.sharpness,
    required this.threshold,
    required this.stable,
    required this.ready,
    required this.calibrated,
    required this.stableOk,
    required this.stableN,
    required this.motionPct,
  });

  @override
  Widget build(BuildContext context) {
    final ok = calibrated && stable && ready && sharpness >= threshold;

    final sharpRatio = (threshold <= 0)
        ? 0.0
        : (sharpness / threshold).clamp(0.0, 1.25).toDouble();

    final stableRatio =
        (stableN <= 0) ? 0.0 : (stableOk / stableN).clamp(0.0, 1.0).toDouble();

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RingPainter(ringOffset: ringOffset),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: _HudCompact(
              ok: ok,
              calibrated: calibrated,
              stable: stable,
              ready: ready,
              sharpness: sharpness,
              threshold: threshold,
              sharpRatio: sharpRatio,
              stableOk: stableOk,
              stableN: stableN,
              stableRatio: stableRatio,
              motionPct: motionPct,
            ),
          ),
        ],
      ),
    );
  }
}

class _HudCompact extends StatelessWidget {
  final bool ok;
  final bool calibrated;
  final bool stable;
  final bool ready;

  final double sharpness;
  final double threshold;

  final double sharpRatio;
  final int stableOk;
  final int stableN;
  final double stableRatio;
  final double motionPct;

  const _HudCompact({
    required this.ok,
    required this.calibrated,
    required this.stable,
    required this.ready,
    required this.sharpness,
    required this.threshold,
    required this.sharpRatio,
    required this.stableOk,
    required this.stableN,
    required this.stableRatio,
    required this.motionPct,
  });

  Widget _chip(ThemeData theme, String label, bool on) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: on
            ? Colors.greenAccent.withValues(alpha: 38)
            : Colors.white.withValues(alpha: 23),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: on
              ? Colors.greenAccent.withValues(alpha: 89)
              : Colors.white.withValues(alpha: 31),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            on ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: on
                ? Colors.greenAccent.withValues(alpha: 242)
                : Colors.white.withValues(alpha: 140),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 242),
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _barRow(
    ThemeData theme, {
    required String title,
    required double value,
    required String rightText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 217),
                ),
              ),
            ),
            Text(
              rightText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 191),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 23),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = ok ? 'Готово к снимку' : 'Почти готово';
    final subtitle =
        ok ? 'Нажмите кнопку съёмки' : 'Удерживайте телефон 1–2 секунды';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 89),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 31)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: ok
                      ? Colors.greenAccent.withValues(alpha: 242)
                      : Colors.white.withValues(alpha: 140),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: ok
                          ? Colors.greenAccent.withValues(alpha: 242)
                          : Colors.white.withValues(alpha: 242),
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 191),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                    theme, 'Резкость', sharpness >= threshold && threshold > 0),
                _chip(theme, 'Стабильность', stable),
                _chip(theme, 'Калибровка', calibrated),
              ],
            ),
            const SizedBox(height: 12),
            _barRow(
              theme,
              title: 'Резкость / Порог',
              value: (sharpRatio / 1.0).clamp(0.0, 1.0),
              rightText:
                  '${sharpness.toStringAsFixed(1)} / ${threshold.toStringAsFixed(1)}',
            ),
            const SizedBox(height: 10),
            _barRow(
              theme,
              title: 'Стабильность',
              value: stableRatio,
              rightText: (stableN > 0)
                  ? '$stableOk/$stableN · движение ${motionPct.toStringAsFixed(1)}%'
                  : '—',
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.ringOffset});

  final Offset ringOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2) + ringOffset;
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
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.ringOffset != ringOffset;
}
