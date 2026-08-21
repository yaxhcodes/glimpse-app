import 'package:flutter/material.dart';

class ShellStatusBarAccent extends StatelessWidget {
  const ShellStatusBarAccent({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final highContrast = MediaQuery.highContrastOf(context);
    final accentTint = Color.alphaBlend(
      cs.primary.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.05 : 0.03,
      ),
      cs.surface,
    );
    final opacity = highContrast
        ? 0.68
        : theme.brightness == Brightness.dark
        ? 0.36
        : 0.32;

    return IgnorePointer(
      child: AnimatedOpacity(
        key: const ValueKey('shell-status-bar-accent'),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        opacity: visible ? 1 : 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                accentTint.withValues(alpha: opacity),
                accentTint.withValues(alpha: opacity * 0.52),
                accentTint.withValues(alpha: 0),
              ],
              stops: const [0, 0.78, 1],
            ),
          ),
          child: SizedBox(
            key: const ValueKey('shell-status-bar-accent-size'),
            height: MediaQuery.paddingOf(context).top,
            width: double.infinity,
          ),
        ),
      ),
    );
  }
}
