import 'package:flutter/material.dart';

typedef _PathBuilder = void Function(Path path, double size);

class PlatformIcon extends StatelessWidget {
  final String platform;
  final double size;
  final Color? color;

  const PlatformIcon({
    super.key,
    required this.platform,
    this.size = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c =
        color ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    final builder = _glyphs[platform.toLowerCase()];
    if (builder == null) {
      return Icon(Icons.circle_outlined, size: size, color: c);
    }
    return CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(builder, c),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final _PathBuilder _builder;
  final Color _color;

  _GlyphPainter(this._builder, this._color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    _builder(path, size.width);
    canvas.drawPath(path, Paint()..color = _color);
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) => old._color != _color;
}

void _x(Path p, double s) {
  final w = s * 0.16;
  final m = s * 0.12;
  p.moveTo(m, m);
  p.lineTo(m + w, m);
  p.lineTo(s / 2, s * 0.46);
  p.lineTo(s - m - w, m);
  p.lineTo(s - m, m);
  p.lineTo(s / 2, s * 0.54);
  p.lineTo(s - m, s - m);
  p.lineTo(s - m - w, s - m);
  p.lineTo(s / 2, s * 0.54 - w * 0.6);
  p.lineTo(m + w, s - m);
  p.lineTo(m, s - m);
  p.lineTo(s * 0.5 - w * 0.4, s * 0.46 + w * 0.3);
  p.close();
}

void _reddit(Path p, double s) {
  final cx = s / 2, cy = s * 0.62;
  final r = s * 0.18;
  p.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
  p.addOval(
    Rect.fromCircle(
      center: Offset(cx - s * 0.22, cy - s * 0.06),
      radius: s * 0.045,
    ),
  );
  p.addOval(
    Rect.fromCircle(
      center: Offset(cx + s * 0.22, cy - s * 0.06),
      radius: s * 0.045,
    ),
  );
  p.moveTo(cx, cy - r);
  p.lineTo(cx + s * 0.14, cy - r - s * 0.18);
  p.addOval(
    Rect.fromCircle(
      center: Offset(cx + s * 0.14, cy - r - s * 0.18),
      radius: s * 0.04,
    ),
  );
}

void _github(Path p, double s) {
  p.moveTo(s * 0.50, s * 0.12);
  p.cubicTo(s * 0.30, s * 0.12, s * 0.16, s * 0.27, s * 0.16, s * 0.47);
  p.cubicTo(s * 0.16, s * 0.61, s * 0.24, s * 0.72, s * 0.36, s * 0.78);
  p.cubicTo(s * 0.40, s * 0.80, s * 0.43, s * 0.76, s * 0.41, s * 0.72);
  p.cubicTo(s * 0.39, s * 0.68, s * 0.34, s * 0.68, s * 0.30, s * 0.68);
  p.cubicTo(s * 0.22, s * 0.68, s * 0.20, s * 0.60, s * 0.20, s * 0.60);
  p.cubicTo(s * 0.27, s * 0.65, s * 0.32, s * 0.63, s * 0.36, s * 0.68);
  p.cubicTo(s * 0.40, s * 0.62, s * 0.45, s * 0.60, s * 0.50, s * 0.60);
  p.cubicTo(s * 0.55, s * 0.60, s * 0.60, s * 0.62, s * 0.64, s * 0.68);
  p.cubicTo(s * 0.68, s * 0.63, s * 0.73, s * 0.65, s * 0.80, s * 0.60);
  p.cubicTo(s * 0.80, s * 0.60, s * 0.78, s * 0.68, s * 0.70, s * 0.68);
  p.cubicTo(s * 0.66, s * 0.68, s * 0.61, s * 0.68, s * 0.59, s * 0.72);
  p.cubicTo(s * 0.57, s * 0.76, s * 0.60, s * 0.80, s * 0.64, s * 0.78);
  p.cubicTo(s * 0.76, s * 0.72, s * 0.84, s * 0.61, s * 0.84, s * 0.47);
  p.cubicTo(s * 0.84, s * 0.27, s * 0.70, s * 0.12, s * 0.50, s * 0.12);
  p.close();
  p.moveTo(s * 0.28, s * 0.18);
  p.lineTo(s * 0.37, s * 0.23);
  p.lineTo(s * 0.32, s * 0.31);
  p.close();
  p.moveTo(s * 0.72, s * 0.18);
  p.lineTo(s * 0.68, s * 0.31);
  p.lineTo(s * 0.63, s * 0.23);
  p.close();
}

void _youtube(Path p, double s) {
  final cx = s / 2, cy = s / 2;
  final hw = s * 0.38, hh = s * 0.26;
  final rr = s * 0.06;
  final rect = Rect.fromCenter(
    center: Offset(cx, cy),
    width: hw * 2,
    height: hh * 2,
  );
  p.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(rr)));
  final triH = s * 0.14;
  p.moveTo(cx - triH * 0.4, cy - triH * 0.7);
  p.lineTo(cx + triH * 0.6, cy);
  p.lineTo(cx - triH * 0.4, cy + triH * 0.7);
  p.close();
}

void _spotify(Path p, double s) {
  final cx = s / 2, cy = s / 2, r = s * 0.38;
  p.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
  for (var i = 0; i < 3; i++) {
    final yy = cy + s * (0.0 + i * 0.08);
    final x0 = cx - s * 0.18, x1 = cx + s * 0.18;
    p.moveTo(x0, yy);
    p.quadraticBezierTo(cx, yy + s * 0.04, x1, yy + s * 0.02);
  }
}

void _pinterest(Path p, double s) {
  final cx = s / 2, cy = s / 2, r = s * 0.36;
  p.addOval(Rect.fromCircle(center: Offset(cx, cy - s * 0.02), radius: r));
  p.moveTo(cx, cy + r);
  p.lineTo(cx + s * 0.02, cy + s * 0.46);
}

void _instagram(Path p, double s) {
  final cx = s / 2, cy = s / 2;
  final hw = s * 0.36, hh = s * 0.36, r = s * 0.10;
  p.addRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: hw * 2, height: hh * 2),
      Radius.circular(r),
    ),
  );
  p.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: s * 0.14));
  p.addOval(
    Rect.fromCircle(
      center: Offset(cx + s * 0.24, cy - s * 0.24),
      radius: s * 0.035,
    ),
  );
}

void _linkedin(Path p, double s) {
  final m = s * 0.18, w = s * 0.64, h = s * 0.64;
  p.addRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(m, m + s * 0.18, w, h),
      Radius.circular(s * 0.06),
    ),
  );
  p.addRect(Rect.fromLTWH(m, m + s * 0.08, s * 0.10, s * 0.08));
  p.addRect(Rect.fromLTWH(m + s * 0.16, m + s * 0.08, s * 0.24, s * 0.08));
  p.addRect(Rect.fromLTWH(m + s * 0.16, m + s * 0.30, s * 0.36, s * 0.08));
  p.addRect(Rect.fromLTWH(m + s * 0.16, m + s * 0.46, s * 0.36, s * 0.08));
}

void _medium(Path p, double s) {
  final m = s * 0.14, w = s * 0.72, h = s * 0.68;
  p.addRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(m, m + s * 0.16, w, h),
      Radius.circular(s * 0.08),
    ),
  );
  p.moveTo(m + s * 0.10, m + s * 0.24);
  p.lineTo(m + s * 0.10, m + s * 0.10);
  p.lineTo(m + w - s * 0.10, m + s * 0.10);
  p.lineTo(m + w - s * 0.10, m + s * 0.24);
  p.close();
}

void _substack(Path p, double s) {
  final m = s * 0.16, w = s * 0.68;
  p.addRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(m, m, w, s * 0.52),
      Radius.circular(s * 0.06),
    ),
  );
  p.moveTo(m, s * 0.56);
  p.lineTo(m + w / 2, s * 0.82);
  p.lineTo(m + w, s * 0.56);
  p.close();
}

final Map<String, _PathBuilder> _glyphs = {
  'x': _x,
  'twitter': _x,
  'reddit': _reddit,
  'github': _github,
  'youtube': _youtube,
  'spotify': _spotify,
  'pinterest': _pinterest,
  'instagram': _instagram,
  'linkedin': _linkedin,
  'medium': _medium,
  'substack': _substack,
};
