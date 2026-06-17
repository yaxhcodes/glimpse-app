import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Material 3 Expressive–style loading indicator (Android 17): a single filled
/// shape that continuously morphs between lobed "cookie / flower" forms while
/// it rotates. A hand-built Flutter approximation of the system morphing loader
/// — Flutter's Material library doesn't ship it yet.
class ExpressiveLoadingIndicator extends StatefulWidget {
  const ExpressiveLoadingIndicator({super.key, this.size = 40, this.color});

  final double size;
  final Color? color;

  @override
  State<ExpressiveLoadingIndicator> createState() =>
      _ExpressiveLoadingIndicatorState();
}

class _ExpressiveLoadingIndicatorState extends State<ExpressiveLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _MorphingShapePainter(t: _controller.value, color: color),
          ),
        ),
      ),
    );
  }
}

class _MorphingShapePainter extends CustomPainter {
  _MorphingShapePainter({required this.t, required this.color});

  /// Loop phase, 0..1.
  final double t;
  final Color color;

  static const int _samples = 160;
  static const double _maxAmp = 0.18;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final half = size.shortestSide / 2;
    // Scale so the largest lobe exactly reaches the bounds (never clips).
    final unit = half / (1 + _maxAmp);

    // Breathe between a 4-lobe (rounded-square-ish) and a 7-lobe (cookie) form.
    // Two morph cycles per full rotation reads as lively and non-repetitive.
    final blend = 0.5 - 0.5 * math.cos(t * 2 * math.pi * 2);
    final amp4 = _maxAmp * (1 - blend);
    final amp7 = _maxAmp * blend;
    final rotation = t * 2 * math.pi;

    final path = Path();
    for (int i = 0; i <= _samples; i++) {
      final phase = (i / _samples) * 2 * math.pi;
      final r =
          unit * (1 + amp4 * math.cos(4 * phase) + amp7 * math.cos(7 * phase));
      final angle = rotation + phase;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = true
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_MorphingShapePainter old) =>
      old.t != t || old.color != color;
}
