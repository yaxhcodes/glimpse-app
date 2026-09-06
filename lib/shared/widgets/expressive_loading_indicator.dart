import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Material 3 Expressive–style loading indicator (Android 17): a single filled
/// shape that continuously morphs between lobed "cookie / flower" forms while
/// it rotates. A hand-built Flutter approximation of the system morphing loader
/// — Flutter's Material library doesn't ship it yet.
class ExpressiveLoadingIndicator extends StatefulWidget {
  const ExpressiveLoadingIndicator({
    super.key,
    this.size = 40,
    this.color,
    this.semanticsLabel = 'Loading',
  });

  final double size;
  final Color? color;
  final String semanticsLabel;

  @override
  State<ExpressiveLoadingIndicator> createState() =>
      _ExpressiveLoadingIndicatorState();
}

class _ExpressiveLoadingIndicatorState extends State<ExpressiveLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      container: true,
      liveRegion: true,
      label: widget.semanticsLabel,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _MorphingShapePainter(
                t: _controller.value,
                color: color,
              ),
            ),
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

  static const int _sampleCount = 96;
  static const double _maxAmplitude = 0.34;
  static final List<_ShapeSample> _samples = List.generate(_sampleCount, (
    index,
  ) {
    final phase = (index / _sampleCount) * 2 * math.pi;
    return _ShapeSample(
      x: math.cos(phase),
      y: math.sin(phase),
      fourLobes: math.cos(4 * phase),
      sevenLobes: math.cos(7 * phase),
    );
  }, growable: false);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final half = size.shortestSide / 2;
    // Scale so the largest lobe exactly reaches the bounds (never clips).
    final unit = half / (1 + _maxAmplitude);

    // Breathe between a 4-lobe (rounded-square-ish) and a 7-lobe (cookie) form.
    // Two morph cycles per full rotation reads as lively and non-repetitive.
    final blend = 0.5 - 0.5 * math.cos(t * 2 * math.pi * 2);
    final amp4 = _maxAmplitude * (1 - blend);
    final amp7 = _maxAmplitude * blend;
    final rotation = t * 2 * math.pi;
    final cosRotation = math.cos(rotation);
    final sinRotation = math.sin(rotation);

    final path = Path();
    for (var i = 0; i <= _sampleCount; i++) {
      final sample = _samples[i % _sampleCount];
      final radius =
          unit * (1 + amp4 * sample.fourLobes + amp7 * sample.sevenLobes);
      final rotatedX = sample.x * cosRotation - sample.y * sinRotation;
      final rotatedY = sample.x * sinRotation + sample.y * cosRotation;
      final point = center + Offset(rotatedX, rotatedY) * radius;
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

class _ShapeSample {
  const _ShapeSample({
    required this.x,
    required this.y,
    required this.fourLobes,
    required this.sevenLobes,
  });

  final double x;
  final double y;
  final double fourLobes;
  final double sevenLobes;
}
