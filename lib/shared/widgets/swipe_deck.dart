import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/services/app_haptics.dart';
import '../theme/app_motion.dart';

/// Swiping between full pages (Details, a Library item) as a deck of cards:
/// while a swipe is under way the pages pull in from the screen's edges and
/// round their corners over a dimmer backdrop, their content drifts a
/// little slower than they do, and the page being left dims. Settled, it is
/// just the page — no clip, offset or veil.
///
/// Cheap on every frame: a clip, a translate and a flat fill per visible
/// page. Nothing is scaled (text would re-rasterise) or faded through a
/// layer.
class SwipeDeck extends StatelessWidget {
  const SwipeDeck({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    this.physics,
    this.onPageChanged,
    this.cards = true,
    this.background,
  });

  final PageController controller;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Defaults to [SwipeDeckPhysics].
  final ScrollPhysics? physics;
  final ValueChanged<int>? onPageChanged;

  /// Whether pages become cards while swiping. Off for pages that carry
  /// their own swipe language (a [background] behind them, say): they then
  /// slide as they are, still settling on the spring.
  final bool cards;

  /// Painted behind the pages, for a backdrop that changes with the swipe
  /// rather than sliding with it. Listen to [controller] for the position.
  final Widget? background;

  /// The gap between two cards at the height of a swipe.
  static const _gutter = 12.0;
  static const _radius = 28.0;

  /// How much slower a page's content moves than the page itself.
  static const _parallax = 0.16;

  static Color _backdrop(ColorScheme cs, Brightness brightness) =>
      brightness == Brightness.dark
      ? cs.surfaceContainerLowest
      : cs.surfaceContainerHigh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = PageView.builder(
      controller: controller,
      physics: physics ?? const SwipeDeckPhysics(),
      itemCount: itemCount,
      onPageChanged: (index) {
        // A notch as the next page takes over.
        AppHaptics.play(AppHaptics.detent);
        onPageChanged?.call(index);
      },
      itemBuilder: (context, index) => cards
          ? _DeckCard(
              controller: controller,
              index: index,
              child: itemBuilder(context, index),
            )
          : itemBuilder(context, index),
    );
    final background = this.background;
    if (background != null) {
      return Stack(fit: StackFit.expand, children: [background, pages]);
    }
    return cards
        ? ColoredBox(
            color: _backdrop(theme.colorScheme, theme.brightness),
            child: pages,
          )
        : pages;
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scrim = Theme.of(context).colorScheme.scrim;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return AnimatedBuilder(
          animation: controller,
          child: child,
          builder: (context, child) {
            final position = _position();
            // How far through a swipe the deck is: 0 settled on a page, 1
            // halfway between two. Engages quickly, so the cards form as
            // soon as the finger moves.
            // A spring settles to within a pixel or so, not exactly: that
            // counts as settled.
            var between = (position - position.roundToDouble()).abs() * 2;
            if (between < 0.01) between = 0;
            final engaged = Curves.easeOut.transform(
              math.min(1.0, between * 3),
            );
            // This page's distance from the middle of the screen, in pages.
            final away = index - position;
            final settled = engaged <= 0.001;
            final inset = SwipeDeck._gutter / 2 * engaged;
            final radius = SwipeDeck._radius * engaged;
            final dim = (0.18 * away.abs().clamp(0.0, 1.0)).toDouble();
            return ClipRRect(
              clipper: _InsetClipper(inset: inset, radius: radius),
              clipBehavior: settled ? Clip.none : Clip.antiAlias,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  Transform.translate(
                    offset: Offset(
                      settled ? 0 : -away * width * SwipeDeck._parallax,
                      0,
                    ),
                    child: child,
                  ),
                  if (!settled && dim > 0.001)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ColoredBox(color: scrim.withValues(alpha: dim)),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  double _position() {
    if (controller.hasClients && controller.position.haveDimensions) {
      return controller.page ?? controller.initialPage.toDouble();
    }
    return controller.initialPage.toDouble();
  }
}

class _InsetClipper extends CustomClipper<RRect> {
  const _InsetClipper({required this.inset, required this.radius});

  final double inset;
  final double radius;

  @override
  RRect getClip(Size size) => RRect.fromRectAndRadius(
    (Offset.zero & size).deflate(inset),
    Radius.circular(radius),
  );

  @override
  bool shouldReclip(_InsetClipper old) =>
      old.inset != inset || old.radius != radius;
}

/// Page snapping on the M3 Expressive spatial spring: a fling carries into
/// the next page, a touch past it, and settles.
class SwipeDeckPhysics extends PageScrollPhysics {
  const SwipeDeckPhysics({super.parent});

  @override
  SwipeDeckPhysics applyTo(ScrollPhysics? ancestor) =>
      SwipeDeckPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring => AppMotion.spatialDefault;
}
