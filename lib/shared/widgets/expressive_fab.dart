import 'package:flutter/material.dart';
import 'expressive_tap_scale.dart';

/// Extended FAB with a Material 3 Expressive press response: on
/// touch it springs down in scale and morphs its corners tighter, then springs
/// back with a gentle overshoot on release.
///
/// Wraps the real [FloatingActionButton.extended] — so theme colors, elevation,
/// ink and semantics are unchanged — and only animates scale + corner radius.
/// A [Listener] drives the press so the button's own tap handling is untouched;
/// the press is abandoned if the pointer travels (a drag/scroll), so it never
/// sticks pressed.
class ExpressiveExtendedFab extends StatelessWidget {
  const ExpressiveExtendedFab({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.idleRadius = 16,
    this.pressedRadius = 9,
    this.isExtended,
    this.tooltip,
  });

  final VoidCallback onPressed;
  final Widget icon;
  final Widget label;
  final double idleRadius;
  final double pressedRadius;
  final bool? isExtended;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return _ExpressiveFabMotion(
      idleRadius: idleRadius,
      pressedRadius: pressedRadius,
      builder: (radius) => FloatingActionButton.extended(
        onPressed: onPressed,
        tooltip: tooltip,
        extendedPadding: isExtended == null
            ? null
            : const EdgeInsets.symmetric(horizontal: 18),
        icon: isExtended == null ? icon : null,
        label: isExtended == null
            ? label
            : TweenAnimationBuilder<double>(
                tween: Tween<double>(end: isExtended! ? 1 : 0),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeInOutCubic,
                builder: (context, progress, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRect(
                      child: Align(
                        widthFactor: progress,
                        child: Opacity(
                          opacity: progress,
                          child: ExcludeSemantics(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: label,
                            ),
                          ),
                        ),
                      ),
                    ),
                    icon,
                  ],
                ),
              ),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Regular FAB with the same Material 3 Expressive spring response as
/// [ExpressiveExtendedFab].
class ExpressiveFab extends StatelessWidget {
  const ExpressiveFab({
    super.key,
    required this.onPressed,
    required this.child,
    this.heroTag,
    this.tooltip,
    this.idleRadius = 16,
    this.pressedRadius = 9,
  });

  final VoidCallback onPressed;
  final Widget child;
  final Object? heroTag;
  final String? tooltip;
  final double idleRadius;
  final double pressedRadius;

  @override
  Widget build(BuildContext context) {
    return _ExpressiveFabMotion(
      idleRadius: idleRadius,
      pressedRadius: pressedRadius,
      builder: (radius) => FloatingActionButton(
        heroTag: heroTag,
        tooltip: tooltip,
        onPressed: onPressed,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
}

class _ExpressiveFabMotion extends StatelessWidget {
  const _ExpressiveFabMotion({
    required this.builder,
    required this.idleRadius,
    required this.pressedRadius,
  });

  final Widget Function(double radius) builder;
  final double idleRadius;
  final double pressedRadius;

  @override
  Widget build(BuildContext context) {
    return ExpressiveTapScale(
      pressedScale: 0.96,
      builder: (context, press) =>
          builder(idleRadius + (pressedRadius - idleRadius) * press),
    );
  }
}
