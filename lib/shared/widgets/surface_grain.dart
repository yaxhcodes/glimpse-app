import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A fixed paper grain beneath content. The reusable tile never animates.
class SurfaceGrain extends StatelessWidget {
  const SurfaceGrain({super.key, required this.child, this.strength = 1})
    : assert(strength >= 0 && strength <= 1);

  final Widget child;
  final double strength;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _GrainPainter(isDark: isDark, strength: strength),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter({required this.isDark, required this.strength});

  final bool isDark;
  final double strength;
  static const _tileSize = 96.0;
  static final _tiles = <(bool, double), ui.Picture>{};

  static ui.Picture _recordTile(bool isDark, double strength) {
    final random = math.Random(47);
    final darkPoints = Float32List(2400);
    final lightPoints = Float32List(2400);
    for (var i = 0; i < darkPoints.length; i++) {
      darkPoints[i] = random.nextDouble() * _tileSize;
      lightPoints[i] = random.nextDouble() * _tileSize;
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.clipRect(const Rect.fromLTWH(0, 0, _tileSize, _tileSize));
    canvas.drawRawPoints(
      ui.PointMode.points,
      darkPoints,
      Paint()
        ..color = Colors.black.withValues(
          alpha: (isDark ? .20 : .10) * strength,
        )
        ..strokeWidth = .7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRawPoints(
      ui.PointMode.points,
      lightPoints,
      Paint()
        ..color = Colors.white.withValues(
          alpha: (isDark ? .065 : .32) * strength,
        )
        ..strokeWidth = .65
        ..strokeCap = StrokeCap.round,
    );
    return recorder.endRecording();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final tile = _tiles.putIfAbsent((
      isDark,
      strength,
    ), () => _recordTile(isDark, strength));
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var y = 0.0; y < size.height; y += _tileSize) {
      for (var x = 0.0; x < size.width; x += _tileSize) {
        canvas.save();
        canvas.translate(x, y);
        canvas.drawPicture(tile);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GrainPainter oldDelegate) =>
      isDark != oldDelegate.isDark || strength != oldDelegate.strength;
}
