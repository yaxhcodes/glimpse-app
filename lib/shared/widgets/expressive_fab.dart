import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/app_motion.dart';

/// Extended FAB with a Material 3 Expressive press response (Android 17): on
/// touch it springs down in scale and morphs its corners tighter, then springs
/// back with a gentle overshoot on release.
///
/// Wraps the real [FloatingActionButton.extended] — so theme colors, elevation,
/// ink and semantics are unchanged — and only animates scale + corner radius.
/// A [Listener] drives the press so the button's own tap handling is untouched;
/// the press is abandoned if the pointer travels (a drag/scroll), so it never
/// sticks pressed.
class ExpressiveExtendedFab extends StatefulWidget {
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
  State<ExpressiveExtendedFab> createState() => _ExpressiveExtendedFabState();
}

class _ExpressiveExtendedFabState extends State<ExpressiveExtendedFab>
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
          return Transform.scale(
            scale: scale,
            child: FloatingActionButton.extended(
              onPressed: widget.onPressed,
              icon: widget.icon,
              label: widget.label,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          );
        },
      ),
    );
  }
}
