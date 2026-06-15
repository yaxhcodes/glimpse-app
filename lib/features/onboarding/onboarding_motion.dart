import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Slow-drifting "aurora" backdrop — large soft radial blobs in the theme
/// colours. Gives onboarding a premium, alive feel with no asset dependency.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, this.intensity = 1.0});

  final double intensity;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 22))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _AuroraPainter(
          t: _c.value,
          colors: [cs.primary, cs.tertiary, cs.secondary],
          intensity: widget.intensity,
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.t,
    required this.colors,
    required this.intensity,
  });

  final double t;
  final List<Color> colors;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final blobs = <(Offset, double, Color)>[
      (const Offset(0.30, 0.32), 0.0, colors[0]),
      (const Offset(0.74, 0.40), 0.33, colors[1]),
      (const Offset(0.50, 0.74), 0.66, colors[2]),
    ];
    for (final (base, phase, color) in blobs) {
      final a = (t + phase) * 2 * math.pi;
      final cx = (base.dx + 0.08 * math.cos(a)) * size.width;
      final cy = (base.dy + 0.08 * math.sin(a * 1.3)) * size.height;
      final rect =
          Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.6);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.32 * intensity),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(rect);
      canvas.drawRect(Offset.zero & size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) => old.t != t;
}
