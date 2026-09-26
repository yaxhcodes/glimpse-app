import 'package:flutter/material.dart';
import 'package:glimpse/shared/theme/app_icons.dart';

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
      return Icon(AppIcons.circle, size: size, color: c);
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

final Map<String, _PathBuilder> _glyphs = {
  'linkedin': _linkedin,
};
