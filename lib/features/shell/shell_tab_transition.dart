import 'package:flutter/material.dart';

import '../../shared/theme/app_motion.dart';

class ShellTabTransition extends StatefulWidget {
  const ShellTabTransition({
    super.key,
    required this.selectedIndex,
    required this.child,
    this.enabled = true,
  });

  final int selectedIndex;
  final Widget child;
  final bool enabled;

  @override
  State<ShellTabTransition> createState() => _ShellTabTransitionState();
}

class _ShellTabTransitionState extends State<ShellTabTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.medium,
      value: 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _controller.value = 1;
  }

  @override
  void didUpdateWidget(ShellTabTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || _reduceMotion) {
      _controller.value = 1;
    } else if (oldWidget.selectedIndex != widget.selectedIndex) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = Curves.easeOutBack.transform(_controller.value);
          return Transform.translate(
            offset: Offset(0, 8 * (1 - progress)),
            child: Transform.scale(
              scale: 0.984 + 0.016 * progress,
              child: child,
            ),
          );
        },
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}
