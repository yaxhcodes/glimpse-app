import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
    this.child,
    this.builder,
    this.pressedScale = 0.98,
    this.enabled = true,
  }) : assert((child == null) != (builder == null)),
       assert(pressedScale > 0 && pressedScale < 1);

  final Widget? child;
  final Widget Function(BuildContext context, double press)? builder;

  /// Scale at full press. Large surfaces use a restrained 2% compression.
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
  late final AnimationController _controller;
  Offset? _downPosition;
  int? _pointer;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 1);
  }

  void _reset() {
    _downPosition = null;
    _pointer = null;
    _controller.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _reset();
  }

  @override
  void didUpdateWidget(ExpressiveTapScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || oldWidget.pressedScale != widget.pressedScale) {
      _reset();
    }
  }

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
      duration: AppMotion.press,
      curve: AppMotion.emphasizedDecelerate,
    );
  }

  void _release() {
    if (!mounted || _downPosition == null) return;
    _downPosition = null;
    _pointer = null;
    _controller.animateWith(
      SpringSimulation(
        AppMotion.springExpressive,
        _controller.value,
        1.0,
        _controller.velocity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _reduceMotion) {
      return widget.child ?? widget.builder!(context, 0);
    }
    return Listener(
      onPointerDown: (event) {
        if (_pointer != null || event.buttons != kPrimaryButton) return;
        _pointer = event.pointer;
        _downPosition = event.position;
        _press();
      },
      onPointerMove: (event) {
        if (event.pointer != _pointer) return;
        final start = _downPosition;
        if (start != null && (event.position - start).distance > _slop) {
          _reset();
        }
      },
      onPointerUp: (event) {
        if (event.pointer == _pointer) _release();
      },
      onPointerCancel: (event) {
        if (event.pointer == _pointer) _reset();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: _controller.value,
          child:
              child ??
              widget.builder!(
                context,
                ((1 - _controller.value) / (1 - widget.pressedScale)).clamp(
                  0,
                  1,
                ),
              ),
        ),
        child: widget.child,
      ),
    );
  }
}
