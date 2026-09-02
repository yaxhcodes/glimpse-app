import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Connects Flutter scrollables to Android's system scrolling-screenshot API.
///
/// Android cannot discover Flutter's internal [Scrollable] widgets because the
/// entire Flutter scene is hosted in one native rendering view. This widget
/// tracks visible vertical scrollables and exposes the best candidate through a
/// platform channel used by the Android scroll-capture callback.
class ScrollCaptureCoordinator extends StatefulWidget {
  const ScrollCaptureCoordinator({required this.child, super.key});

  final Widget child;

  @override
  State<ScrollCaptureCoordinator> createState() =>
      _ScrollCaptureCoordinatorState();
}

/// Reports whether Android is currently composing a scrolling screenshot.
///
/// Fixed shell chrome should leave the window while capture is active so the
/// system can treat the selected [Scrollable] as the page body and append the
/// original bottom chrome only once.
class ScrollCaptureScope extends InheritedWidget {
  const ScrollCaptureScope({
    required this.isCapturing,
    required super.child,
    super.key,
  });

  final bool isCapturing;

  static bool isCapturingOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<ScrollCaptureScope>()
            ?.isCapturing ??
        false;
  }

  @override
  bool updateShouldNotify(ScrollCaptureScope oldWidget) {
    return isCapturing != oldWidget.isCapturing;
  }
}

/// Marks whether a mounted subtree is the shell's currently visible tab.
///
/// [IndexedStack] keeps inactive tabs laid out, so render-object visibility is
/// not enough to identify the page Android should scroll.
class ScrollCaptureVisibilityScope extends InheritedWidget {
  const ScrollCaptureVisibilityScope({
    required this.isVisible,
    required super.child,
    super.key,
  });

  final bool isVisible;

  @override
  bool updateShouldNotify(ScrollCaptureVisibilityScope oldWidget) {
    return isVisible != oldWidget.isVisible;
  }
}

/// Describes fixed shell chrome that must sit outside the native scroll target.
class ScrollCaptureViewportScope extends InheritedWidget {
  const ScrollCaptureViewportScope({
    required this.bottomObstruction,
    required super.child,
    super.key,
  });

  final double bottomObstruction;

  @override
  bool updateShouldNotify(ScrollCaptureViewportScope oldWidget) {
    return bottomObstruction != oldWidget.bottomObstruction;
  }
}

/// Describes fixed chrome owned by one particular scrolling surface.
class ScrollCaptureFixedOverlayScope extends InheritedWidget {
  const ScrollCaptureFixedOverlayScope({
    required this.bottomObstruction,
    required super.child,
    super.key,
  });

  final double bottomObstruction;

  @override
  bool updateShouldNotify(ScrollCaptureFixedOverlayScope oldWidget) {
    return bottomObstruction != oldWidget.bottomObstruction;
  }
}

class _ScrollCaptureCoordinatorState extends State<ScrollCaptureCoordinator> {
  static const _channel = MethodChannel(
    'com.shinrinyoku.glimpse/scroll_capture',
  );

  final Map<ScrollableState, _ScrollCaptureCandidate> _candidates = {};
  int _sequence = 0;
  bool _nativeMetricsUpdateScheduled = false;
  bool _isCaptureUiActive = false;
  Timer? _proxyResetTimer;
  _ProxyScrollSession? _proxySession;
  _ScrollCaptureSession? _session;
  late final Future<void> _nativeProxyReady;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleMethodCall);
    _nativeProxyReady = _resetNativeProxy();
    _scheduleNativeMetricsUpdate();
  }

  @override
  void dispose() {
    _proxyResetTimer?.cancel();
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleNativeMetricsUpdate();
    return ScrollCaptureScope(
      isCapturing: _isCaptureUiActive,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          _rememberScrollable(
            notification.context,
            notification.metrics,
            wasInteractedWith: false,
          );
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _rememberScrollable(
              notification.context,
              notification.metrics,
              wasInteractedWith:
                  notification is ScrollStartNotification ||
                  notification is ScrollUpdateNotification ||
                  notification is OverscrollNotification ||
                  notification is UserScrollNotification &&
                      notification.direction != ScrollDirection.idle,
            );
            return false;
          },
          child: widget.child,
        ),
      ),
    );
  }

  void _rememberScrollable(
    BuildContext? notificationContext,
    ScrollMetrics metrics, {
    required bool wasInteractedWith,
  }) {
    if (notificationContext == null || metrics.axis != Axis.vertical) return;
    if (metrics.maxScrollExtent <= metrics.minScrollExtent) return;

    final scrollable = Scrollable.maybeOf(notificationContext);
    if (scrollable == null) return;

    final previous = _candidates[scrollable];
    _candidates[scrollable] = _ScrollCaptureCandidate(
      scrollable: scrollable,
      notificationContext: notificationContext,
      sequence: ++_sequence,
      interactionSequence: wasInteractedWith
          ? _sequence
          : previous?.interactionSequence ?? 0,
    );
    _scheduleNativeMetricsUpdate();
  }

  void _scheduleNativeMetricsUpdate() {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        _nativeMetricsUpdateScheduled) {
      return;
    }
    _nativeMetricsUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nativeMetricsUpdateScheduled = false;
      if (!mounted) return;
      unawaited(_pushNativeViewMetrics());
    });
  }

  Future<bool> _pushNativeViewMetrics() async {
    await _nativeProxyReady;
    if (!mounted) return false;
    final candidate = _selectCandidate();
    Map<String, Object>? arguments;
    if (candidate != null &&
        candidate.notificationContext.mounted &&
        _isUsable(candidate)) {
      final position = candidate.scrollable.position;
      final ratio = View.of(candidate.notificationContext).devicePixelRatio;
      final bounds = _physicalBoundsFor(candidate);
      final bottomObstruction = candidate.notificationContext
          .getInheritedWidgetOfExactType<ScrollCaptureViewportScope>()
          ?.bottomObstruction;
      final shellOverlayObstruction =
          candidate.notificationContext
              .getInheritedWidgetOfExactType<ScrollCaptureFixedOverlayScope>()
              ?.bottomObstruction ??
          0;
      final effectiveBottomObstruction = math.max(
        bottomObstruction ?? 0,
        shellOverlayObstruction,
      );
      final bottomObstructionPixels = effectiveBottomObstruction * ratio;
      final scrollableBottom = bounds == null
          ? 0
          : math.max(bounds.top, bounds.bottom - bottomObstructionPixels);
      arguments = {
        'left': bounds?.left.round() ?? 0,
        'top': bounds?.top.round() ?? 0,
        'right': bounds?.right.round() ?? 0,
        'bottom': scrollableBottom.round(),
        'minimumOffset': position.minScrollExtent * ratio,
        'maximumOffset': position.maxScrollExtent * ratio,
        'offset': position.pixels * ratio,
        'viewportDimension': position.viewportDimension * ratio,
        'viewportTopInset': bounds?.top ?? 0,
        'viewportBottomInset': bottomObstructionPixels,
      };
    }

    try {
      await _channel.invokeMethod<void>('updateViewMetrics', arguments);
      return arguments != null;
    } on MissingPluginException {
      // Android versions before the native bridge was introduced are safe to
      // run without OEM view metrics; the official callback remains optional.
      return false;
    } on PlatformException catch (error) {
      debugPrint('Could not update Android scroll metrics: $error');
      return false;
    }
  }

  Future<void> _resetNativeProxy() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('resetProxy');
    } on MissingPluginException {
      // Older Android hosts do not expose the OEM compatibility proxy.
    } on PlatformException catch (error) {
      debugPrint('Could not reset Android scroll proxy: $error');
    }
  }

  Future<Object?> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'start':
        return _startCapture();
      case 'capture':
        final arguments = call.arguments;
        if (arguments is! Map) return null;
        return _capture(arguments);
      case 'end':
        await _endCapture();
        return null;
      case 'proxyScrollTo':
        final offset = call.arguments;
        if (offset is! num) return false;
        return _handleProxyScroll(offset.toDouble());
      case 'proxyPrepare':
        return _prepareProxyScroll();
      case 'proxyScrollEnd':
        await _finishProxyScroll();
        return true;
      default:
        throw MissingPluginException(
          'Unknown scroll capture method: ${call.method}',
        );
    }
  }

  Future<bool> _prepareProxyScroll() async {
    return _pushNativeViewMetrics();
  }

  Future<bool> _handleProxyScroll(double physicalOffset) async {
    final candidate = _proxySession?.candidate ?? _selectCandidate();
    if (candidate == null || !_isUsable(candidate)) return false;

    _proxyResetTimer?.cancel();
    final position = candidate.scrollable.position;
    final ratio = View.of(candidate.notificationContext).devicePixelRatio;
    _proxySession ??= _ProxyScrollSession(
      candidate: candidate,
      originalOffset: position.pixels,
    );
    final targetOffset = (physicalOffset / ratio).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final needsScroll =
        (position.pixels - targetOffset).abs() > precisionErrorTolerance;
    if (needsScroll) {
      position.jumpTo(targetOffset);
      await _waitForPaint();
    }

    if (!mounted || !_isUsable(candidate)) return false;
    final didReachTarget =
        (candidate.scrollable.position.pixels - targetOffset).abs() <=
        precisionErrorTolerance;

    _proxyResetTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_finishProxyScroll());
    });
    return didReachTarget;
  }

  Future<void> _finishProxyScroll() async {
    _proxyResetTimer?.cancel();
    _proxyResetTimer = null;
    final session = _proxySession;
    _proxySession = null;
    try {
      if (session != null && _isUsable(session.candidate)) {
        final position = session.candidate.scrollable.position;
        final targetOffset = session.originalOffset.clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        if ((position.pixels - targetOffset).abs() > precisionErrorTolerance) {
          position.jumpTo(targetOffset);
          await _waitForPaint();
        }
      }
    } finally {
      final needsUiRestore = _isCaptureUiActive;
      _deactivateCaptureUi();
      if (mounted && needsUiRestore) {
        await _waitForPaint();
      }
      if (mounted) {
        await _pushNativeViewMetrics();
      }
    }
  }

  Future<bool> _startCapture() async {
    if (!_isCaptureUiActive) {
      setState(() => _isCaptureUiActive = true);
      await _waitForPaint();
    }
    if (!mounted) return false;

    final candidate = _selectCandidate();
    if (candidate == null || !_isUsable(candidate)) {
      _deactivateCaptureUi();
      return false;
    }

    final position = candidate.scrollable.position;
    final pixelRatio = View.of(context).devicePixelRatio;
    _session = _ScrollCaptureSession(
      candidate: candidate,
      originalOffset: position.pixels,
      initialOffset: position.pixels,
      pixelRatio: pixelRatio,
    );
    return true;
  }

  Future<Map<String, Object>?> _capture(Map<dynamic, dynamic> arguments) async {
    final session = _session;
    if (session == null || !_isUsable(session.candidate)) return null;

    final requestedLeft = _intArgument(arguments, 'left');
    final requestedTop = _intArgument(arguments, 'top');
    final requestedRight = _intArgument(arguments, 'right');
    final requestedBottom = _intArgument(arguments, 'bottom');
    if (requestedLeft == null ||
        requestedTop == null ||
        requestedRight == null ||
        requestedBottom == null ||
        requestedRight <= requestedLeft ||
        requestedBottom <= requestedTop) {
      return null;
    }

    final position = session.candidate.scrollable.position;
    final ratio = session.pixelRatio;
    final contentTop =
        ((position.minScrollExtent - session.initialOffset) * ratio).ceil();
    final contentBottom =
        ((position.maxScrollExtent +
                    position.viewportDimension -
                    session.initialOffset) *
                ratio)
            .floor();
    final availableTop = math.max(requestedTop, contentTop);
    final availableBottom = math.min(requestedBottom, contentBottom);
    if (availableBottom <= availableTop) {
      return _captureResult(
        left: requestedLeft,
        top: 0,
        right: requestedLeft,
        bottom: 0,
        scrollDelta: ((position.pixels - session.initialOffset) * ratio)
            .round(),
      );
    }

    final requestedOffset =
        session.initialOffset + (availableTop / session.pixelRatio);
    final targetOffset = requestedOffset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((position.pixels - targetOffset).abs() > precisionErrorTolerance) {
      position.jumpTo(targetOffset);
      await _waitForPaint();
    }

    if (!_isUsable(session.candidate)) return null;
    final actualPosition = session.candidate.scrollable.position;
    final scrollDelta =
        ((actualPosition.pixels - session.initialOffset) * ratio).round();
    return _captureResult(
      left: requestedLeft,
      top: availableTop,
      right: requestedRight,
      bottom: availableBottom,
      scrollDelta: scrollDelta,
    );
  }

  Future<void> _endCapture() async {
    final session = _session;
    _session = null;
    try {
      if (session == null || !_isUsable(session.candidate)) return;

      final position = session.candidate.scrollable.position;
      final restoredOffset = session.originalOffset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - restoredOffset).abs() <= precisionErrorTolerance) {
        return;
      }
      position.jumpTo(restoredOffset);
      await _waitForPaint();
    } finally {
      final needsUiRestore = _isCaptureUiActive;
      _deactivateCaptureUi();
      if (mounted && needsUiRestore) {
        await _waitForPaint();
      }
      if (mounted) {
        await _pushNativeViewMetrics();
      }
    }
  }

  void _deactivateCaptureUi() {
    if (!mounted || !_isCaptureUiActive) return;
    setState(() => _isCaptureUiActive = false);
  }

  Future<void> _waitForPaint() async {
    WidgetsBinding.instance.scheduleFrame();
    await WidgetsBinding.instance.endOfFrame;
    WidgetsBinding.instance.scheduleFrame();
    await WidgetsBinding.instance.endOfFrame;
  }

  _ScrollCaptureCandidate? _selectCandidate({bool discover = true}) {
    if (discover) _discoverScrollables();
    _candidates.removeWhere((_, candidate) => !_isUsable(candidate));
    if (_candidates.isEmpty) return null;

    final candidates = _candidates.values.toList()
      ..sort((a, b) {
        final aIsCurrent = _isOnCurrentRoute(a);
        final bIsCurrent = _isOnCurrentRoute(b);
        final currentRouteComparison = aIsCurrent == bIsCurrent
            ? 0
            : bIsCurrent
            ? 1
            : -1;
        if (currentRouteComparison != 0) return currentRouteComparison;
        final interactionComparison = b.interactionSequence.compareTo(
          a.interactionSequence,
        );
        if (interactionComparison != 0) return interactionComparison;
        final scrollRangeComparison = _scrollRange(
          b,
        ).compareTo(_scrollRange(a));
        if (scrollRangeComparison != 0) return scrollRangeComparison;
        final viewportComparison = b.scrollable.position.viewportDimension
            .compareTo(a.scrollable.position.viewportDimension);
        if (viewportComparison != 0) return viewportComparison;
        return b.sequence.compareTo(a.sequence);
      });
    return candidates.first;
  }

  double _scrollRange(_ScrollCaptureCandidate candidate) {
    final position = candidate.scrollable.position;
    return position.maxScrollExtent - position.minScrollExtent;
  }

  void _discoverScrollables() {
    void visit(Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final scrollable = element.state as ScrollableState;
        final previous = _candidates[scrollable];
        _candidates[scrollable] = _ScrollCaptureCandidate(
          scrollable: scrollable,
          notificationContext: scrollable.context,
          sequence: previous?.sequence ?? ++_sequence,
          interactionSequence: previous?.interactionSequence ?? 0,
        );
      }
      element.visitChildElements(visit);
    }

    context.visitChildElements(visit);
  }

  bool _isUsable(_ScrollCaptureCandidate candidate) {
    if (!candidate.scrollable.mounted) return false;
    final visibility = candidate.notificationContext
        .getInheritedWidgetOfExactType<ScrollCaptureVisibilityScope>();
    if (visibility != null && !visibility.isVisible) return false;
    final position = candidate.scrollable.position;
    if (!position.hasContentDimensions ||
        position.axis != Axis.vertical ||
        position.maxScrollExtent <= position.minScrollExtent) {
      return false;
    }
    final renderObject = candidate.notificationContext.findRenderObject();
    return renderObject is RenderBox &&
        renderObject.attached &&
        renderObject.hasSize &&
        !renderObject.size.isEmpty;
  }

  bool _isOnCurrentRoute(_ScrollCaptureCandidate candidate) {
    return ModalRoute.of(candidate.notificationContext)?.isCurrent ?? true;
  }

  Rect? _physicalBoundsFor(_ScrollCaptureCandidate candidate) {
    final renderObject = candidate.notificationContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;

    final view = View.of(candidate.notificationContext);
    final ratio = view.devicePixelRatio;
    final logicalScreen = Offset.zero & (view.physicalSize / ratio);
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final logicalBounds = (topLeft & renderObject.size).intersect(
      logicalScreen,
    );
    if (logicalBounds.isEmpty) return null;

    return Rect.fromLTRB(
      (logicalBounds.left * ratio).floorToDouble(),
      (logicalBounds.top * ratio).floorToDouble(),
      (logicalBounds.right * ratio).ceilToDouble(),
      (logicalBounds.bottom * ratio).ceilToDouble(),
    );
  }

  static int? _intArgument(Map<dynamic, dynamic> arguments, String key) {
    final value = arguments[key];
    return value is num ? value.round() : null;
  }

  static Map<String, Object> _captureResult({
    required int left,
    required int top,
    required int right,
    required int bottom,
    required int scrollDelta,
  }) {
    return {
      'left': left,
      'top': top,
      'right': right,
      'bottom': bottom,
      'scrollDelta': scrollDelta,
    };
  }
}

class _ScrollCaptureCandidate {
  const _ScrollCaptureCandidate({
    required this.scrollable,
    required this.notificationContext,
    required this.sequence,
    required this.interactionSequence,
  });

  final ScrollableState scrollable;
  final BuildContext notificationContext;
  final int sequence;
  final int interactionSequence;
}

class _ScrollCaptureSession {
  const _ScrollCaptureSession({
    required this.candidate,
    required this.originalOffset,
    required this.initialOffset,
    required this.pixelRatio,
  });

  final _ScrollCaptureCandidate candidate;
  final double originalOffset;
  final double initialOffset;
  final double pixelRatio;
}

class _ProxyScrollSession {
  const _ProxyScrollSession({
    required this.candidate,
    required this.originalOffset,
  });

  final _ScrollCaptureCandidate candidate;
  final double originalOffset;
}
