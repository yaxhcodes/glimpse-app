import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/providers/swipe_preferences_provider.dart';

typedef SwipeActionCallback = FutureOr<bool> Function(SwipeActionType action);
typedef SwipeDismissedCallback =
    FutureOr<void> Function(SwipeActionType action);

class PremiumSwipeCard extends StatefulWidget {
  const PremiumSwipeCard({
    super.key,
    required this.child,
    required this.leftSwipeAction,
    required this.rightSwipeAction,
    this.onAction,
    this.onDismissed,
    this.dismissibleActions = const {SwipeActionType.delete},
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  /// Action triggered when the card is dragged left.
  final SwipeActionType leftSwipeAction;

  /// Action triggered when the card is dragged right.
  final SwipeActionType rightSwipeAction;

  final Widget child;
  final SwipeActionCallback? onAction;
  final SwipeDismissedCallback? onDismissed;
  final Set<SwipeActionType> dismissibleActions;
  final BorderRadius borderRadius;

  @override
  State<PremiumSwipeCard> createState() => _PremiumSwipeCardState();
}

class _PremiumSwipeCardState extends State<PremiumSwipeCard>
    with SingleTickerProviderStateMixin {
  static const _softThreshold = 0.38;
  static const _hardThreshold = 0.68;

  late final AnimationController _controller;
  Animation<double>? _offsetAnimation;
  Animation<double>? _opacityAnimation;

  double _rawOffset = 0;
  double _offset = 0;
  double _opacity = 1;
  bool _softHapticSent = false;
  bool _hardHapticSent = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
        )..addListener(() {
          if (!mounted) return;
          setState(() {
            _offset = _offsetAnimation?.value ?? _offset;
            _opacity = _opacityAnimation?.value ?? _opacity;
          });
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasAnySwipe =>
      widget.leftSwipeAction != SwipeActionType.none ||
      widget.rightSwipeAction != SwipeActionType.none;

  SwipeActionType _actionForOffset(double offset) {
    if (offset < 0) return widget.leftSwipeAction;
    if (offset > 0) return widget.rightSwipeAction;
    return SwipeActionType.none;
  }

  double _displayOffsetForRaw(double raw, double width) {
    if (width <= 0) return 0;
    if (raw < 0 && widget.leftSwipeAction == SwipeActionType.none) return 0;
    if (raw > 0 && widget.rightSwipeAction == SwipeActionType.none) return 0;

    final sign = raw.sign;
    var distance = raw.abs();
    final resistanceStart = width * 0.60;
    if (distance > resistanceStart) {
      distance = resistanceStart + (distance - resistanceStart) * 0.42;
    }
    return sign * distance.clamp(0, width * 0.78);
  }

  void _updateThresholdHaptics(double progress) {
    if (progress >= _softThreshold && !_softHapticSent) {
      HapticFeedback.lightImpact();
      _softHapticSent = true;
    } else if (progress < _softThreshold - 0.08) {
      _softHapticSent = false;
    }

    if (progress >= _hardThreshold && !_hardHapticSent) {
      HapticFeedback.mediumImpact();
      _hardHapticSent = true;
    } else if (progress < _hardThreshold - 0.10) {
      _hardHapticSent = false;
    }
  }

  void _handleDragStart(DragStartDetails details) {
    if (_busy || !_hasAnySwipe) return;
    _controller.stop();
    _rawOffset = _offset;
    _opacity = 1;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_busy || !_hasAnySwipe) return;
    final width = context.size?.width ?? MediaQuery.of(context).size.width;
    if (width <= 0) return;
    final delta = details.primaryDelta ?? 0;
    final raw = _rawOffset + delta;
    final display = _displayOffsetForRaw(raw, width);
    final progress = (display.abs() / width).clamp(0.0, 1.0).toDouble();
    setState(() {
      _rawOffset = raw;
      _offset = display;
      _opacity = 1;
    });
    _updateThresholdHaptics(progress);
  }

  Future<void> _handleDragEnd(DragEndDetails details) async {
    if (_busy || !_hasAnySwipe) return;
    final width = context.size?.width ?? MediaQuery.of(context).size.width;
    final progress = width <= 0 ? 0.0 : (_offset.abs() / width);
    final action = _actionForOffset(_offset);
    if (action == SwipeActionType.none || progress < _softThreshold) {
      await _animateBack();
      return;
    }
    await _commitAction(action, width);
  }

  Future<bool> _callAction(SwipeActionType action) async {
    final callback = widget.onAction;
    if (callback == null) return true;
    return callback(action);
  }

  Future<void> _commitAction(SwipeActionType action, double width) async {
    if (_busy) return;
    _busy = true;
    try {
      if (widget.dismissibleActions.contains(action)) {
        final allowed = await _callAction(action);
        if (!mounted) return;
        if (!allowed) {
          await _animateBack();
          return;
        }

        final sign = _offset < 0 ? -1.0 : 1.0;
        await _animateTo(
          sign * width * 1.08,
          targetOpacity: 0,
          duration: const Duration(milliseconds: 230),
          curve: Curves.easeInCubic,
        );
        await widget.onDismissed?.call(action);
      } else {
        await _animateBack();
        if (!mounted) return;
        await _callAction(action);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          if (_opacity == 0) {
            _offset = 0;
            _rawOffset = 0;
            _opacity = 1;
          }
        });
      }
    }
  }

  Future<void> _animateBack() {
    return _animateTo(
      0,
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _animateTo(
    double target, {
    double targetOpacity = 1,
    required Duration duration,
    required Curve curve,
  }) async {
    _controller.duration = duration;
    final curved = CurvedAnimation(parent: _controller, curve: curve);
    _offsetAnimation = Tween<double>(
      begin: _offset,
      end: target,
    ).animate(curved);
    _opacityAnimation = Tween<double>(
      begin: _opacity,
      end: targetOpacity,
    ).animate(curved);
    await _controller.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _offset = target;
      _rawOffset = target;
      _opacity = targetOpacity;
      if (target == 0) {
        _softHapticSent = false;
        _hardHapticSent = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final progress = width <= 0
            ? 0.0
            : (_offset.abs() / width).clamp(0.0, 1.0).toDouble();
        final sign = _offset == 0 ? 0.0 : _offset.sign;
        final action = _actionForOffset(_offset);
        final easedProgress = Curves.easeOutCubic.transform(progress);
        final scale = 1.0 - (0.015 * easedProgress);
        final rotation = sign * math.pi / 180 * easedProgress;

        Widget content = Opacity(
          opacity: _opacity,
          child: Transform.translate(
            offset: Offset(_offset, 0),
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(scale: scale, child: widget.child),
            ),
          ),
        );

        if (_hasAnySwipe) {
          content = GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _handleDragStart,
            onHorizontalDragUpdate: _handleDragUpdate,
            onHorizontalDragEnd: _handleDragEnd,
            onHorizontalDragCancel: () {
              unawaited(_animateBack());
            },
            child: content,
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: _SwipeRevealSurface(
                action: action,
                progress: progress,
                revealFromRight: sign < 0,
                borderRadius: widget.borderRadius,
                armed: progress >= _softThreshold,
              ),
            ),
            content,
          ],
        );
      },
    );
  }
}

class _SwipeRevealSurface extends StatelessWidget {
  const _SwipeRevealSurface({
    required this.action,
    required this.progress,
    required this.revealFromRight,
    required this.borderRadius,
    required this.armed,
  });

  final SwipeActionType action;
  final double progress;
  final bool revealFromRight;
  final BorderRadius borderRadius;

  /// True once the drag has passed the trigger threshold — the action will
  /// fire on release. Mirrors Gmail's "let go now" colour commit.
  final bool armed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (action == SwipeActionType.none || progress <= 0.001) {
      return const SizedBox.shrink();
    }

    final tint = action.tint(cs);

    // A restrained wash that deepens slightly as the action arms — just enough
    // colour to read the intent, never loud.
    final bgAlpha = (armed ? 0.10 : progress * 0.07).clamp(0.0, 0.10).toDouble();

    // The glyph eases in, sits on a soft neutral disc, and lifts a touch on arm.
    final reveal = ((progress - 0.08) / 0.26).clamp(0.0, 1.0).toDouble();
    final chipScale = 0.84 + 0.16 * Curves.easeOut.transform(reveal);

    final chip = Transform.scale(
      scale: chipScale,
      child: AnimatedScale(
        scale: armed ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tint.withValues(alpha: armed ? 0.18 : 0.10),
          ),
          child: Center(child: action.iconWidget(color: tint, size: 21)),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            tint.withValues(alpha: bgAlpha),
            cs.surface,
          ),
        ),
        child: Align(
          alignment: revealFromRight
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: chip,
          ),
        ),
      ),
    );
  }
}
