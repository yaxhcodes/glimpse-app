import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart' show PredictiveBackEvent;

import '../../core/services/app_haptics.dart';
import '../theme/app_motion.dart';

/// Marks a card as a place a page opens out of — the card splits open,
/// its top edge rising and bottom edge falling, into the page — and closes
/// back into, where the card takes the landing with a small bounce and
/// jostles its neighbours (Material 3 Expressive springs).
///
/// Pages opt in by using [CardOpenPage]. Every mounted card registers
/// itself, so a page can close into a different card than it opened from —
/// after a swipe through the Details pager, the card of the save the reader
/// ended on (see [CardOpenRoute.reportVisibleUrl] and [openTag]).
class CardOpenOrigin extends StatefulWidget {
  const CardOpenOrigin({
    super.key,
    required this.child,
    this.openTag,
    this.borderRadius = 14,
    this.color,
  });

  /// Identifies what the card opens, for finding it again on close. Save
  /// cards use [urlTag].
  final Object? openTag;
  final Widget child;
  final double borderRadius;

  /// The card's fill, which the page opens out of. Defaults to
  /// `surfaceContainerLow`; a translucent fill is taken as it looks over
  /// the page's surface.
  final Color? color;

  /// The [openTag] of a card that opens save [urlId]'s Details.
  static Object urlTag(int urlId) => 'url:$urlId';

  /// A card at [context] is closing up its row (swiped away): the cards
  /// below it, sliding up into the gap, carry on a few pixels past and
  /// settle back — the Expressive list "catch".
  static void settleBelow(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final route = ModalRoute.of(context);
    final top = box.localToGlobal(Offset.zero).dy;
    const reach = 360.0;
    const maxShift = 7.0;
    for (final card in _CardOpenOriginState._mounted) {
      if (!identical(card._route, route)) continue;
      // Not the card that is going away.
      var inside = false;
      card.context.visitAncestorElements((element) {
        inside = identical(element, context);
        return !inside;
      });
      if (inside) continue;
      final rect = card._globalRect();
      if (rect == null || rect.top < top - 1) continue;
      final gap = rect.top - top;
      if (gap > reach) continue;
      final strength = 1 - gap / reach;
      card._jostle(Offset(0, -maxShift * strength));
    }
  }

  /// For a container that lays its own tap layer over its cards (such as
  /// [CarouselView]), so a card never sees the finger itself: records the
  /// card under [globalPosition] as the one being pressed.
  static void notePress(Offset globalPosition) {
    _CardOpenOriginState? pressed;
    var smallest = double.infinity;
    for (final card in _CardOpenOriginState._mounted) {
      final rect = card._globalRect();
      if (rect == null || !rect.contains(globalPosition)) continue;
      final area = rect.width * rect.height;
      if (area >= smallest) continue;
      pressed = card;
      smallest = area;
    }
    pressed?._notePressed();
  }

  @override
  State<CardOpenOrigin> createState() => _CardOpenOriginState();
}

class _CardOpenOriginState extends State<CardOpenOrigin>
    with SingleTickerProviderStateMixin {
  static final Set<_CardOpenOriginState> _mounted = {};
  static _CardOpenOriginState? _lastPressed;
  static DateTime? _lastPressedAt;

  /// A tap opens the page well within this; older presses are not the origin.
  static const _pressWindow = Duration(milliseconds: 1500);

  // Only the route's identity and whether it's active are used, and this
  // widget's rebuild is trivial (its child passes through untouched).
  ModalRoute<Object?>? _route;
  Color? _fill;

  /// Drives the landing bounce (this card) or the jostle (a neighbour).
  /// Rests at 0, where it adds nothing.
  late final AnimationController _bump = AnimationController.unbounded(
    vsync: this,
  );
  double _bumpSquash = 0;
  Offset _bumpShift = Offset.zero;

  static _CardOpenOriginState? _takePressed() {
    final state = _lastPressed;
    final at = _lastPressedAt;
    _lastPressed = null;
    _lastPressedAt = null;
    if (state == null || at == null || !state.mounted) return null;
    if (DateTime.now().difference(at) > _pressWindow) return null;
    return state;
  }

  void _notePressed() {
    _lastPressed = this;
    _lastPressedAt = DateTime.now();
  }

  @override
  void initState() {
    super.initState();
    _mounted.add(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _mounted.remove(this);
    if (identical(_lastPressed, this)) _lastPressed = null;
    _bump.dispose();
    super.dispose();
  }

  Rect? _globalRect() {
    if (!mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    try {
      final rect = MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      );
      return rect.isEmpty || !rect.isFinite ? null : rect;
    } catch (_) {
      return null;
    }
  }

  /// How much of the card is on screen, 0–1.
  double _visibleFraction(Size screen) {
    final rect = _globalRect();
    if (rect == null) return 0;
    final visible = rect.intersect(Offset.zero & screen);
    if (visible.isEmpty) return 0;
    return (visible.width * visible.height) / (rect.width * rect.height);
  }

  _OriginSnapshot? _snapshot() {
    final rect = _globalRect();
    final fill = _fill;
    if (rect == null || fill == null) return null;
    return _OriginSnapshot(
      rect: rect,
      radius: widget.borderRadius,
      color: fill,
    );
  }

  // Values that peak at about 1 for springs starting at rest (see
  // [_absorbLanding] / [_jostle]).
  static const _fastSpringPeakVelocity = 56.0;

  /// The page has just landed in this card: it gives a little under the
  /// weight and springs back.
  void _absorbLanding() {
    _bumpSquash = 0.045;
    _bumpShift = Offset.zero;
    _playBump();
  }

  /// A neighbour of the card a page landed in: nudged away from it, then
  /// back.
  void _jostle(Offset shift) {
    _bumpSquash = 0;
    _bumpShift = shift;
    _playBump();
  }

  void _playBump() {
    _bump
        .animateWith(
          SpringSimulation(
            AppMotion.spatialFast,
            0,
            0,
            _fastSpringPeakVelocity,
          ),
        )
        // A spring only settles to within tolerance: end exactly at rest,
        // where the card is untransformed.
        .whenCompleteOrCancel(() {
          if (mounted && !_bump.isAnimating) _bump.value = 0;
        });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fill = widget.color ?? cs.surfaceContainerLow;
    _fill = Color.alphaBlend(fill, cs.surface);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _notePressed(),
      child: AnimatedBuilder(
        animation: _bump,
        child: widget.child,
        builder: (context, child) {
          final v = _bump.value;
          return Transform.translate(
            offset: _bumpShift * v,
            child: Transform.scale(scale: 1 - _bumpSquash * v, child: child),
          );
        },
      ),
    );
  }
}

class _OriginSnapshot {
  const _OriginSnapshot({
    required this.rect,
    required this.radius,
    required this.color,
  });

  final Rect rect;
  final double radius;
  final Color color;
}

/// A page that opens out of the card that was tapped to open it (a
/// [CardOpenOrigin]) and closes back into it. Opened from anywhere without
/// a card — a notification, a deep link — it opens out of a line across the
/// middle of the screen.
class CardOpenPage extends Page<void> {
  const CardOpenPage({
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    this.urlId,
    required this.child,
  });

  /// The save a Details page shows, so it can close into that save's card.
  final int? urlId;
  final Widget child;

  static final _routes = Expando<CardOpenRoute>('CardOpenPage.route');

  /// The route a page is showing in, found from its settings (see
  /// [ModalRoute.settingsOf]). Settings never change, so a page that looks
  /// its route up this way isn't rebuilt whenever the route's status does —
  /// [ModalRoute.of] would rebuild the whole page on the first frame of
  /// every close.
  static CardOpenRoute? routeOf(RouteSettings? settings) =>
      settings is CardOpenPage ? _routes[settings] : null;

  @override
  Route<void> createRoute(BuildContext context) {
    final route = CardOpenRoute._(this);
    _routes[this] = route;
    return route;
  }
}

class CardOpenRoute extends PageRoute<void> {
  CardOpenRoute._(CardOpenPage page) : super(settings: page) {
    final pressed = _CardOpenOriginState._takePressed();
    _openCard = pressed;
    _openOrigin = pressed?._snapshot();
    _originRoute = pressed?._route;
    _openTag = pressed?.widget.openTag;
    _visibleTag = _openTag;
  }

  /// A page opening out of a card that loads its content (a list, a save)
  /// can hand over the load: the card holds, opened but still, until it has
  /// arrived — briefly, at most [_contentWait] — so the page is built and
  /// painted under the card before anything moves, rather than arriving
  /// mid-flight. Call it from the page's first `didChangeDependencies`.
  static void waitForContent(BuildContext context, Future<Object?> content) {
    final route = CardOpenPage.routeOf(ModalRoute.settingsOf(context));
    if (route == null || route._contentTaken) return;
    route._content.add(content);
  }

  static const _contentWait = Duration(milliseconds: 200);
  final List<Future<Object?>> _content = [];
  bool _contentTaken = false;

  /// Resolves once the page's content has arrived and been painted (or the
  /// wait ran out).
  Future<void> _contentReady() async {
    _contentTaken = true;
    if (_content.isEmpty) return;
    try {
      await Future.wait(_content).timeout(_contentWait);
    } catch (_) {
      // Too slow or failed: open anyway, the page shows its own state.
    }
    // The content's rebuild, laid out and painted under the card.
    await WidgetsBinding.instance.endOfFrame;
  }

  /// Tells the route which save the Details pager is showing, so the page
  /// closes into that save's card.
  static void reportVisibleUrl(RouteSettings? settings, int urlId) {
    CardOpenPage.routeOf(settings)?._visibleTag = CardOpenOrigin.urlTag(urlId);
  }

  _CardOpenOriginState? _openCard;
  _OriginSnapshot? _openOrigin;
  ModalRoute<Object?>? _originRoute;
  Object? _openTag;
  Object? _visibleTag;

  /// Where the page closes to: the card it opened from until the page below
  /// is back on stage and can be measured again. Once measured, no card
  /// (the reader moved on to a save that isn't on screen) means closing to
  /// the middle — never into another card.
  _CardOpenOriginState? _closeCard;
  _OriginSnapshot? _closeOrigin;
  bool _closeResolved = false;
  final _closeOriginVersion = ValueNotifier<int>(0);

  _OriginSnapshot? get _origin => _closeResolved ? _closeOrigin : _openOrigin;

  void _measureCloseOrigin() {
    // Not `isActive`: a route stops being active the moment it is popped,
    // which is exactly when this runs.
    if (_disposed || navigator == null) return;
    _closeCard = _findCloseCard();
    _closeOrigin = _closeCard?._snapshot();
    _closeResolved = true;
    _closeOriginVersion.value++;
  }

  _CardOpenOriginState? _findCloseCard() {
    final originRoute = _originRoute;
    final navigatorContext = navigator?.context;
    if (originRoute == null || navigatorContext == null) return null;
    if (!originRoute.isActive) return null;
    final screen = MediaQuery.sizeOf(navigatorContext);
    bool onScreen(_CardOpenOriginState card) =>
        // Mostly visible, or the page would fly off to where nobody sees it.
        card.mounted && card._visibleFraction(screen) >= 0.6;

    final opened = _openCard;
    if (_visibleTag == _openTag && opened != null) {
      return identical(opened._route, originRoute) && onScreen(opened)
          ? opened
          : null;
    }
    if (_visibleTag == null) return null;
    _CardOpenOriginState? best;
    var bestVisible = 0.0;
    for (final card in _CardOpenOriginState._mounted) {
      // Only a card on the page being revealed; another tab's list can hold
      // the same save.
      if (card.widget.openTag != _visibleTag) continue;
      if (!identical(card._route, originRoute)) continue;
      final visible = card._visibleFraction(screen);
      if (visible < 0.6 || visible <= bestVisible) continue;
      best = card;
      bestVisible = visible;
    }
    return best;
  }

  /// The page has landed in its card: the card takes it, its neighbours
  /// feel it, and so does the hand holding the phone.
  void _land() {
    final card = _closeCard;
    final rect = card?._globalRect();
    if (card == null || rect == null) return;
    card._absorbLanding();
    AppHaptics.play(AppHaptics.land);
    const reach = 320.0;
    const maxShift = 9.0;
    for (final other in _CardOpenOriginState._mounted) {
      if (identical(other, card) || !identical(other._route, card._route)) {
        continue;
      }
      final otherRect = other._globalRect();
      if (otherRect == null) continue;
      final away = otherRect.center - rect.center;
      // Gap between the two cards, not between their centres.
      final gap = math.max(
        0.0,
        math.max(
          (away.dx.abs() - (rect.width + otherRect.width) / 2),
          (away.dy.abs() - (rect.height + otherRect.height) / 2),
        ),
      );
      if (gap > reach || away.distance == 0) continue;
      final strength = 1 - gap / reach;
      other._jostle(away / away.distance * maxShift * strength * strength);
    }
  }

  // The transition runs on its own clocks, started only once the heavy frame
  // is behind it (the page's first paint on open, the page below coming
  // back on stage on close), so that frame never shows as a jump. The
  // route's own animation is given room to outlast them and is then snapped
  // to its end.

  bool _visuallyOpen = false;

  void _finishOpen() {
    if (!isActive) return;
    _visuallyOpen = true;
    final controller = this.controller;
    if (controller == null) return;
    if (controller.isCompleted) {
      // The route finished first: now that the page really covers the
      // screen, stop painting the one below.
      if (overlayEntries.isNotEmpty) overlayEntries.first.opaque = true;
    } else if (controller.status == AnimationStatus.forward) {
      controller.value = 1;
    }
  }

  void _finishClose() {
    final controller = this.controller;
    if (controller != null && controller.status == AnimationStatus.reverse) {
      controller.value = 0;
    }
  }

  @override
  void didAdd() {
    // Restored or deep-linked in place: already open, no animation.
    _visuallyOpen = true;
    super.didAdd();
  }

  // Until the transition has visibly opened, the page below must keep
  // painting around it.
  @override
  bool get opaque => _visuallyOpen;

  @override
  void changedInternalState() {
    super.changedInternalState();
    // The router hands over a fresh page object on each rebuild.
    CardOpenPage._routes[settings] = this;
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _closeOriginVersion.dispose();
    super.dispose();
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 1200);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 1200);

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  // The page below stays exactly where it is: the card opens out of it.
  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return (settings as CardOpenPage).child;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _CardOpen(route: this, animation: animation, child: child);
  }
}

enum _Phase { opening, open, dragging, cancelling, closing }

class _CardOpen extends StatefulWidget {
  const _CardOpen({
    required this.route,
    required this.animation,
    required this.child,
  });

  final CardOpenRoute route;
  final Animation<double> animation;
  final Widget child;

  @override
  State<_CardOpen> createState() => _CardOpenState();
}

class _CardOpenState extends State<_CardOpen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// A full-length back swipe pulls the page this far back toward its card:
  /// enough to show where it is going, not so much it reads as closed.
  static const _maxGestureShrink = 0.24;

  /// Springs settle asymptotically; this is close enough to call them done
  /// (a pixel or two at screen scale).
  static const _tolerance = Tolerance(distance: 0.003, velocity: 0.05);

  // Unbounded: the springs may overshoot. Each runs 0 → 1.
  late final AnimationController _open;
  late final AnimationController _close;
  late final AnimationController _settle;

  _Phase _phase = _Phase.opening;
  bool _openScheduled = false;
  bool _landed = false;
  double _lastProgress = 0;
  double _closeFrom = 1;
  double _cancelFrom = 1;
  double _gestureProgress = 0;
  bool _measuredThisGesture = false;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _open = AnimationController.unbounded(vsync: this)
      ..addStatusListener((status) {
        if (status.isCompleted && _phase == _Phase.opening) _becomeOpen();
      });
    _close = AnimationController.unbounded(vsync: this)
      ..addStatusListener((status) {
        if (status.isCompleted) widget.route._finishClose();
      });
    _settle = AnimationController.unbounded(vsync: this)
      ..addStatusListener((status) {
        if (status.isCompleted && _phase == _Phase.cancelling) _becomeOpen();
      });
    widget.animation.addStatusListener(_onRouteStatus);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _CardOpen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(_onRouteStatus);
      widget.animation.addStatusListener(_onRouteStatus);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.animation.removeStatusListener(_onRouteStatus);
    _open.dispose();
    _close.dispose();
    _settle.dispose();
    super.dispose();
  }

  /// Runs [controller] 0 → 1 on [spring], or briefly and flatly when the
  /// system asks for less motion.
  void _run(AnimationController controller, SpringDescription spring) {
    if (_reduceMotion) {
      controller
        ..value = 0
        ..animateTo(1, duration: const Duration(milliseconds: 160));
      return;
    }
    controller.animateWith(
      SpringSimulation(spring, 0, 1, 0, tolerance: _tolerance),
    );
  }

  void _becomeOpen() {
    if (!mounted) return;
    setState(() => _phase = _Phase.open);
    widget.route._finishOpen();
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.reverse) return;
    if (_phase == _Phase.closing || _phase == _Phase.dragging) return;
    _open.stop();
    _settle.stop();
    setState(() {
      _closeFrom = _lastProgress.clamp(0.0, 1.0);
      _phase = _Phase.closing;
    });
    _startCloseAfterThisFrame();
  }

  /// The first frame of a close lays out and paints the page below again —
  /// the heaviest frame of the close. Hold still through it, measure where
  /// the card is now, then run.
  void _startCloseAfterThisFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _phase != _Phase.closing) return;
      widget.route._measureCloseOrigin();
      _run(_close, AppMotion.spatialDefault);
    });
  }

  double _gestureShrink(double progress) =>
      _maxGestureShrink * Curves.easeOutCubic.transform(progress.clamp(0, 1));

  // Predictive back: the page follows the finger back toward its card.

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    final route = widget.route;
    if (backEvent.isButtonEvent || _phase != _Phase.open) return false;
    if (!route.isCurrent || !route.popGestureEnabled) return false;
    route.handleStartBackGesture(progress: 1 - backEvent.progress);
    _measuredThisGesture = false;
    setState(() {
      _phase = _Phase.dragging;
      _gestureProgress = backEvent.progress;
    });
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    if (_phase != _Phase.dragging) return;
    widget.route.handleUpdateBackGestureProgress(
      progress: 1 - backEvent.progress,
    );
    // The page below comes back on stage once the route starts moving;
    // measure its card after that frame lays it out.
    if (!_measuredThisGesture) {
      _measuredThisGesture = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.route._measureCloseOrigin();
      });
    }
    setState(() => _gestureProgress = backEvent.progress);
  }

  @override
  void handleCommitBackGesture() {
    if (_phase != _Phase.dragging) return;
    setState(() {
      _closeFrom = 1 - _gestureShrink(_gestureProgress);
      _phase = _Phase.closing;
    });
    widget.route.handleCommitBackGesture();
    _startCloseAfterThisFrame();
  }

  @override
  void handleCancelBackGesture() {
    if (_phase != _Phase.dragging) return;
    setState(() {
      _cancelFrom = 1 - _gestureShrink(_gestureProgress);
      _phase = _Phase.cancelling;
    });
    widget.route.handleCancelBackGesture();
    _run(_settle, AppMotion.spatialDefault);
  }

  /// 0 is the card, 1 the full page. Springs may carry it a little past 1
  /// on the way open, where the overshoot falls beyond the screen's edges.
  double _progress() {
    switch (_phase) {
      case _Phase.opening:
        return _open.value;
      case _Phase.open:
        return 1;
      case _Phase.dragging:
        return 1 - _gestureShrink(_gestureProgress);
      case _Phase.cancelling:
        return lerpDouble(_cancelFrom, 1, _settle.value)!;
      case _Phase.closing:
        return math.max(0, _closeFrom * (1 - _close.value));
    }
  }

  static double _interval(double t, double begin, double end, [Curve? curve]) {
    final v = ((t - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve == null ? v : curve.transform(v);
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    if (_phase == _Phase.opening && !_openScheduled && !route.offstage) {
      if (widget.animation.isCompleted) {
        // Added in place rather than pushed: nothing to animate.
        _phase = _Phase.open;
      } else {
        // This first onstage frame paints the page for the first time,
        // hidden under the card: its text and images reach the GPU here,
        // not in the middle of the motion. The spring starts after it —
        // and after any content the page asked to wait for.
        _openScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await route._contentReady();
          if (mounted && _phase == _Phase.opening) {
            _run(_open, AppMotion.spatialDefault);
          }
        });
      }
    }
    final reduceMotion = _reduceMotion;
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.animation,
        _open,
        _close,
        _settle,
        route._closeOriginVersion,
      ]),
      child: widget.child,
      builder: (context, child) {
        final size = MediaQuery.sizeOf(context);
        final colors = Theme.of(context).colorScheme;
        final full = Offset.zero & size;
        final p = route.offstage ? 0.0 : _progress();
        _lastProgress = p;
        final settled = _phase == _Phase.open;

        // Nearly home: let the card take the landing. After this frame, as
        // it reaches into another page's cards.
        if (_phase == _Phase.closing && !_landed && p < 0.04 && !reduceMotion) {
          _landed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => route._land());
        }

        // Every frame is only a clip and a flat fill: the page itself never
        // moves, scales or fades through an offscreen layer. A window onto
        // it opens out of the card — top edge rising, bottom edge falling —
        // and a veil in the card's colour lifts off the page inside.
        final origin = reduceMotion ? null : route._origin;
        final begin =
            origin?.rect ??
            Rect.fromCenter(
              center: full.center,
              width: size.width - 32,
              height: 0,
            );
        final rect = reduceMotion ? full : Rect.lerp(begin, full, p)!;
        final beginRadius = origin?.radius ?? 28;
        final radius = reduceMotion || settled
            ? 0.0
            : p < 0.86
            ? lerpDouble(beginRadius, 28, p / 0.86)!
            : math.max(0.0, lerpDouble(28, 0, (p - 0.86) / 0.14)!);

        final pageIn = reduceMotion
            ? 1.0
            : _interval(p, 0.22, 0.72, Curves.easeInOut);
        // Landing: the page lets go and the veil clears, so the card's own
        // content comes back through it rather than popping in at the end.
        final landing = _phase == _Phase.closing && pageIn <= 0;
        final veilColor = Color.lerp(
          origin?.color ?? colors.surface,
          colors.surface,
          _interval(p, 0.04, 0.4),
        )!;
        final veil = settled || reduceMotion
            ? 0.0
            : landing
            ? _interval(p, 0, 0.12)
            : 1 - pageIn;
        final lift = settled || reduceMotion
            ? 0.0
            : math.sin(math.pi * p.clamp(0.0, 1.0));
        final scrim = settled || reduceMotion
            ? 0.0
            : 0.2 * _interval(p, 0, 0.6);

        Widget window = ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: settled ? Clip.none : Clip.antiAlias,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -rect.left,
                top: -rect.top,
                width: size.width,
                height: size.height,
                // Only ever 0 or 1, which never makes a layer.
                child: Opacity(opacity: landing ? 0 : 1, child: child),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: veilColor.withValues(alpha: veilColor.a * veil),
                  ),
                ),
              ),
            ],
          ),
        );
        if (reduceMotion && !settled) {
          // A plain crossfade: the one place a layer is worth it.
          window = Opacity(opacity: p.clamp(0.0, 1.0), child: window);
        }

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(color: colors.scrim.withValues(alpha: scrim)),
              ),
            ),
            Positioned.fromRect(
              rect: rect,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: lift <= 0.02
                      ? null
                      : [
                          BoxShadow(
                            color: colors.shadow.withValues(alpha: 0.16 * lift),
                            blurRadius: 24 * lift,
                            offset: Offset(0, 8 * lift),
                          ),
                        ],
                ),
                child: window,
              ),
            ),
          ],
        );
      },
    );
  }
}
