import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/models/saved_url.dart';
import '../link_card_thumbnail.dart';
import 'notification_preview_resolver.dart';

/// Full-width hero: widescreen media, square PFP (X), or neutral fallback.
class CuratedNotificationHero extends StatelessWidget {
  const CuratedNotificationHero({
    super.key,
    required this.url,
    required this.radius,
    this.blendBottomEdge = false,
    this.showUnreadIndicator = false,
  });

  final SavedUrl url;
  final double radius;

  /// Soft scrim at the bottom of the hero for a clearer transition into text.
  final bool blendBottomEdge;

  /// Unread dot in the top-right corner of the hero (inside bounds).
  final bool showUnreadIndicator;

  @override
  Widget build(BuildContext context) {
    final spec = NotificationPreviewSpec.fromSavedUrl(url);

    late final Widget child;
    switch (spec.visualMode) {
      case NotificationVisualMode.neutralPlaceholder:
        child = ColoredBox(
          color:
              Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.72),
          child: Center(
            child: LinkCardThumbnail.tagLetterPlaceholder(
              url,
              context,
              size: 76,
              borderRadius: 12,
            ),
          ),
        );
      case NotificationVisualMode.networkImage:
        final cs = Theme.of(context).colorScheme;
        child = Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: spec.networkUrl!,
                fit: BoxFit.cover,
                httpHeaders: NotificationPreviewSpec.instagramCdnHeadersFor(spec.networkUrl),
                memCacheHeight:
                    (MediaQuery.devicePixelRatioOf(context) * 400).round(),
                errorWidget: (context, error, stackTrace) => ColoredBox(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.72),
                  child: Center(
                    child: LinkCardThumbnail.tagLetterPlaceholder(
                      url,
                      context,
                      size: 76,
                      borderRadius: 12,
                    ),
                  ),
                ),
              ),
            ),
            if (blendBottomEdge)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 52,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          cs.scrim.withValues(alpha: 0.0),
                          cs.scrim.withValues(
                            alpha: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? 0.28
                                : 0.14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            _UnreadCornerDot(
              visible: showUnreadIndicator,
              color: Theme.of(context).colorScheme.primary,
            ),
            if (spec.showVideoPlayBadge) const _MinimalPlayBadge(),
          ],
        );
    }

    late final Widget framed;
    if (spec.visualMode == NotificationVisualMode.networkImage &&
        spec.heroShape == NotificationHeroShape.square) {
      framed = AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: child,
        ),
      );
    } else {
      framed = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: child,
        ),
      );
    }

    return framed;
  }
}

class _UnreadCornerDot extends StatelessWidget {
  const _UnreadCornerDot({
    required this.visible,
    required this.color,
  });

  final bool visible;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const d = Duration(milliseconds: 180);
    return Positioned(
      top: 8,
      right: 8,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: d,
          curve: Curves.easeOutCubic,
          opacity: visible ? 1.0 : 0.0,
          child: AnimatedScale(
            duration: d,
            curve: Curves.easeOutBack,
            scale: visible ? 1.0 : 0.78,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Container(
                width: 7.5,
                height: 7.5,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 1),
                      spreadRadius: -2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MinimalPlayBadge extends StatelessWidget {
  const _MinimalPlayBadge();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

/// Small rounded square strip cell (consistent with heroes where applicable).
class CuratedNotificationThumbStripItem extends StatelessWidget {
  const CuratedNotificationThumbStripItem({
    super.key,
    required this.url,
    this.size = 48,
    this.squareRadius = 8,
    this.emphasized = false,
  });

  final SavedUrl url;
  final double size;
  final double squareRadius;

  /// Border + light shadow for hub list strips (feels like content, not chrome).
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final spec = NotificationPreviewSpec.fromSavedUrl(url);

    Widget core;
    switch (spec.visualMode) {
      case NotificationVisualMode.networkImage:
        core = CachedNetworkImage(
          imageUrl: spec.networkUrl!,
          fit: BoxFit.cover,
          width: size,
          height: size,
          httpHeaders: NotificationPreviewSpec.instagramCdnHeadersFor(spec.networkUrl),
          errorWidget: (context, error, stackTrace) =>
              LinkCardThumbnail.tagLetterPlaceholder(
            url,
            context,
            size: size,
            borderRadius: squareRadius,
          ),
        );
        if (spec.showVideoPlayBadge) {
          core = Stack(
            alignment: Alignment.bottomRight,
            children: [
              Positioned.fill(child: core),
              const Padding(
                padding: EdgeInsets.only(right: 2, bottom: 2),
                child: Icon(
                  Icons.play_circle_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ],
          );
        }
      case NotificationVisualMode.neutralPlaceholder:
        core = LinkCardThumbnail.tagLetterPlaceholder(
          url,
          context,
          size: size,
          borderRadius: squareRadius,
        );
    }

    final inner = ClipRRect(
      borderRadius: BorderRadius.circular(squareRadius),
      child: SizedBox(width: size, height: size, child: core),
    );

    if (!emphasized) return inner;

    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(squareRadius),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.48),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.09),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: -1,
          ),
        ],
      ),
      child: inner,
    );
  }
}

/// When history has no first URL to resolve (deleted), show a lightweight block.
class CuratedMissingLinkHero extends StatelessWidget {
  const CuratedMissingLinkHero({super.key, this.radius = 14});

  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
          child: Icon(
            Icons.link_off_rounded,
            color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            size: 32,
          ),
        ),
      ),
    );
  }
}
