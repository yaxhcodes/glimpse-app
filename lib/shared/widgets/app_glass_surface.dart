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
  });

  final Widget child;
  final Color? backgroundColor;
  final double blurSigma;
  final double? opacity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = MediaQuery.highContrastOf(context);
    final resolvedOpacity = highContrast
        ? 0.96
        : opacity ?? (theme.brightness == Brightness.dark ? 0.78 : 0.86);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (backgroundColor ?? theme.colorScheme.surface).withValues(
              alpha: resolvedOpacity,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
