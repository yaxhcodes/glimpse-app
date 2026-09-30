import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/app_motion.dart';

/// Fade + short rise used when content first appears (first load of a list,
/// a newly saved card, a filter switch).
///
/// Decides once, in [State.initState], whether to play: later rebuilds with
/// [animate] false never snap a running entrance to its end. Honors the
/// system "remove animations" setting.
class EntranceMotion extends StatefulWidget {
  const EntranceMotion({
    super.key,
    required this.child,
    this.animate = true,
    this.delay = Duration.zero,
    this.offset = 12,
    this.duration = AppMotion.long,
    this.spring = false,
  });

  final Widget child;
  final bool animate;
  final Duration delay;

  /// Vertical travel in logical pixels.
  final double offset;
  final Duration duration;

  /// Rises on an M3 Expressive spatial spring instead of [duration]: quick
  /// off the mark, a touch past its place, then settled.
  final bool spring;

  /// Delay for the [index]th item of a staggered group. Only the first
  /// [maxStaggered] items stagger; the rest would enter off-screen anyway.
  static Duration stagger(int index, {int maxStaggered = 8}) =>
      Duration(milliseconds: 40 * index.clamp(0, maxStaggered));

  @override
  State<EntranceMotion> createState() => _EntranceMotionState();
}

class _EntranceMotionState extends State<EntranceMotion>
    with SingleTickerProviderStateMixin {
  // Unbounded, so a spring may carry the rise a little past its place.
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
  );
  Timer? _delayTimer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    if (!widget.animate) _controller.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || _controller.value == 1) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (widget.delay == Duration.zero) {
      _play();
    } else {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _play();
      });
    }
  }

  void _play() {
    if (widget.spring) {
      _controller.animateWith(SpringSimulation(AppMotion.spatialFast, 0, 1, 0))
      // Springs only settle within tolerance: end exactly in place.
      .whenCompleteOrCancel(() {
        if (mounted && !_controller.isAnimating) _controller.value = 1;
      });
    } else {
      _controller.animateTo(
        1,
        duration: widget.duration,
        curve: AppMotion.emphasizedDecelerate,
      );
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Opacity(
          // Fully in before the spring has finished moving it.
          opacity: (widget.spring ? t * 1.6 : t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.offset),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
