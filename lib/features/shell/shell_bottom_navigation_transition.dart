import 'package:flutter/material.dart';

class ShellBottomNavigationTransition extends StatefulWidget {
  const ShellBottomNavigationTransition({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  State<ShellBottomNavigationTransition> createState() =>
      _ShellBottomNavigationTransitionState();
}

class _ShellBottomNavigationTransitionState
    extends State<ShellBottomNavigationTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
      value: widget.visible ? 1 : 0,
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(curved);
  }

  @override
  void didUpdateWidget(ShellBottomNavigationTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) return;
    if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      excluding: !widget.visible,
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: SlideTransition(
          position: _offset,
          child: RepaintBoundary(child: widget.child),
        ),
      ),
    );
  }
}
