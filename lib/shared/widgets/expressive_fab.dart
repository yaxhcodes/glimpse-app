import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/app_motion.dart';

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
  });

  final VoidCallback onPressed;
  final Widget icon;
  final Widget label;
  final double idleRadius;
  final double pressedRadius;

  @override
  Widget build(BuildContext context) {
    return _ExpressiveFabMotion(
      idleRadius: idleRadius,
      pressedRadius: pressedRadius,
      builder: (radius) => FloatingActionButton.extended(
        onPressed: onPressed,
        icon: icon,
        label: label,
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

class _ExpressiveFabMotion extends StatefulWidget {
  const _ExpressiveFabMotion({
    required this.builder,
    required this.idleRadius,
    required this.pressedRadius,
  });

  final Widget Function(double radius) builder;
  final double idleRadius;
  final double pressedRadius;

  @override
  State<_ExpressiveFabMotion> createState() => _ExpressiveFabMotionState();
}

class _ExpressiveFabMotionState extends State<_ExpressiveFabMotion>
    with SingleTickerProviderStateMixin {
  static const double _slop = 18.0;

  // 0 = idle, 1 = fully pressed. Unbounded so the release spring can briefly
  // overshoot past idle for a lively settle.
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
    value: 0.0,
  );
  Offset? _downPosition;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _pressDown() {
    _press.animateTo(
      1.0,
      duration: AppMotion.short,
      curve: AppMotion.emphasizedAccelerate,
    );
  }

  void _release() {
    if (_downPosition == null) return;
    _downPosition = null;
    _press.animateWith(
      SpringSimulation(AppMotion.springExpressive, _press.value, 0.0, 0.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _downPosition = event.position;
        _pressDown();
      },
      onPointerMove: (event) {
        final start = _downPosition;
        if (start != null && (event.position - start).distance > _slop) {
          _release();
        }
      },
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, _) {
          final clamped = _press.value.clamp(0.0, 1.0);
          // Uses the raw (possibly overshooting) value so release pops slightly
          // above idle scale.
          final scale = 1 - 0.04 * _press.value;
          final radius =
              widget.idleRadius +
              (widget.pressedRadius - widget.idleRadius) * clamped;
          return Transform.scale(scale: scale, child: widget.builder(radius));
        },
      ),
    );
  }
}
