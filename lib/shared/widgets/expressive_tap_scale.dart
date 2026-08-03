import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/app_motion.dart';

/// Adds a springy press-down scale to [child] — the tactile "squish & settle"
/// of Material 3 Expressive interactive surfaces (Android 17).
///
/// Implemented with a [Listener] (raw pointer events) rather than a
/// [GestureDetector] so it never competes in the gesture arena: any existing
/// [InkWell] / tap handler *inside* [child] keeps its ripple, tap and
/// long-press intact. If the pointer travels past [_slop] — i.e. the gesture is
/// becoming a scroll — the press is released, so scrolling a list of these
/// never feels squishy.
class ExpressiveTapScale extends StatefulWidget {
  const ExpressiveTapScale({
    super.key,
    required this.child,
    this.pressedScale = 0.97,
    this.enabled = true,
  });

  final Widget child;

  /// Scale at full press. Subtle by design (3% squish).
  final double pressedScale;

  /// When false the wrapper is a no-op pass-through (e.g. disabled rows).
  final bool enabled;

  @override
  State<ExpressiveTapScale> createState() => _ExpressiveTapScaleState();
}

class _ExpressiveTapScaleState extends State<ExpressiveTapScale>
    with SingleTickerProviderStateMixin {
  /// Pointer travel (logical px) past which we treat the gesture as a scroll
  /// and abandon the press.
  static const double _slop = 14.0;

  // Unbounded so the release spring can briefly overshoot past 1.0.
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
    value: 1.0,
  );
  Offset? _downPosition;

  @override
  void dispose() {
    _downPosition = null;
    _controller.dispose();
    super.dispose();
  }

  void _press() {
    if (!mounted) return;
    _controller.animateTo(
      widget.pressedScale,
      duration: AppMotion.short,
      curve: AppMotion.emphasizedAccelerate,
    );
  }

  void _release() {
    if (!mounted || _downPosition == null) return;
    _downPosition = null;
    _controller.animateWith(
      SpringSimulation(AppMotion.springExpressive, _controller.value, 1.0, 0.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      onPointerDown: (event) {
        _downPosition = event.position;
        _press();
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
        animation: _controller,
        builder: (context, child) =>
            Transform.scale(scale: _controller.value, child: child),
        child: widget.child,
      ),
    );
  }
}
