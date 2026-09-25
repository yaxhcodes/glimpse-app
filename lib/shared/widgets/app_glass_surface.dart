import 'dart:ui';

import 'package:flutter/material.dart';

/// A restrained translucent surface for chrome that overlays scrolling content.
class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    super.key,
    this.child = const SizedBox.expand(),
    this.backgroundColor,
    this.blurSigma = 18,
    this.opacity,
    this.blur = true,
  });

  final Widget child;
  final Color? backgroundColor;
  final double blurSigma;
  final double? opacity;

  /// When false, draws the tinted surface without a [BackdropFilter].
  ///
  /// Use this for chrome that stays on screen while content scrolls beneath
  /// it (the bottom navigation bar): a live blur re-samples the content on
  /// every scrolled frame, which is the most expensive raster work in the app.
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = MediaQuery.highContrastOf(context);
    final resolvedOpacity = highContrast
        ? 0.96
        : opacity ?? (theme.brightness == Brightness.dark ? 0.78 : 0.86);

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: (backgroundColor ?? theme.colorScheme.surface).withValues(
          alpha: resolvedOpacity,
        ),
      ),
      child: child,
    );
    if (!blur) return surface;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: surface,
      ),
    );
  }
}
