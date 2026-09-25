import 'dart:async';

import 'package:flutter/material.dart';

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
  });

  final Widget child;
  final bool animate;
  final Duration delay;

  /// Vertical travel in logical pixels.
  final double offset;
  final Duration duration;

  /// Delay for the [index]th item of a staggered group. Only the first
  /// [maxStaggered] items stagger; the rest would enter off-screen anyway.
  static Duration stagger(int index, {int maxStaggered = 8}) =>
      Duration(milliseconds: 40 * index.clamp(0, maxStaggered));

  @override
  State<EntranceMotion> createState() => _EntranceMotionState();
}

class _EntranceMotionState extends State<EntranceMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.emphasizedDecelerate,
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
      _controller.forward();
    } else {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
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
    return FadeTransition(
      opacity: _progress,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - _progress.value) * widget.offset),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
