import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Retains as much tint as possible while keeping surface text readable.
Color readableTintedSurface({
  required Color base,
  required Color tint,
  required Iterable<Color> foregrounds,
  required double opacity,
}) {
  Color blend(double amount) =>
      Color.alphaBlend(tint.withValues(alpha: tint.a * amount), base);
  bool readable(Color background) => foregrounds.every((foreground) {
    final ink = Color.alphaBlend(foreground, background).computeLuminance();
    final paper = background.computeLuminance();
    // Leave a little contrast headroom for the discovery cards' fine grain.
    return (math.max(ink, paper) + .05) / (math.min(ink, paper) + .05) >= 5;
  });

  final preferred = blend(opacity);
  if (readable(preferred)) return preferred;
  var lower = 0.0;
  var upper = opacity;
  for (var step = 0; step < 10; step++) {
    final middle = (lower + upper) / 2;
    if (readable(blend(middle))) {
      lower = middle;
    } else {
      upper = middle;
    }
  }
  return blend(lower);
}
