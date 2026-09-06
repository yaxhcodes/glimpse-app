import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/dev_simulation_providers.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/expressive_tap_scale.dart';
import '../rediscover/journey_visual.dart';
import '../rediscover/rediscover_daily_set.dart';
import '../rediscover/rediscover_journey_provider.dart';
import '../rediscover/rediscover_memory.dart';
import '../rediscover/rediscover_open_context.dart';

class RediscoverySection extends ConsumerWidget {
  const RediscoverySection({super.key, this.loadJourneys = true});

  final bool loadJourneys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailySetAsync = loadJourneys
        ? ref.watch(rediscoverDailySetProvider)
        : null;
    final memories =
        dailySetAsync?.valueOrNull?.memories ?? const <RediscoverMemory>[];
    final dailySetPending =
        !loadJourneys || (dailySetAsync?.isLoading ?? false);
    final showJourneySkeleton = memories.isEmpty && dailySetPending;
    if (memories.isEmpty && !showJourneySkeleton) {
      return const SizedBox.shrink();
    }
    if (memories.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final controller = ref.read(rediscoverDailySetControllerProvider);
        for (var index = 0; index < memories.length; index++) {
          unawaited(
            markRediscoverMemoryShown(
              controller,
              memories[index],
              surface: RediscoverSurface.home,
              position: index,
            ),
          );
        }
      });
    }

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final seenTip = ref.watch(hasSeenRediscoverTipProvider);
    final size = MediaQuery.sizeOf(context);
    final isTablet = size.width > 600;
    // Keep the next card visible, while reserving height for enlarged text.
    const hPad = 16.0;
    final cardWidth = isTablet ? 320.0 : (size.width - hPad * 2) * 0.80;
    final cardHeight = RediscoverArtworkCard.resolvedHeight(context, 224);
    final previewCount = isTablet
        ? memories.length
        : memories.length.clamp(0, 3);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!seenTip)
            _RediscoverTip(
              onDismiss: () =>
                  ref.read(hasSeenRediscoverTipProvider.notifier).set(true),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 2),
            child: InkWell(
              onTap: () => context.push('/rediscover'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.rediscover,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            context.l10n.rediscoverSubtitle,
                            style: tt.labelSmall?.copyWith(
                              fontSize: 10,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
          if (previewCount > 0 || showJourneySkeleton)
            SizedBox(
              height: cardHeight + 8,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: previewCount > 0
                    ? Padding(
                        key: const ValueKey('rediscover-journey-carousel'),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: CarouselView(
                          itemExtent: cardWidth + 12,
                          shrinkExtent: 0,
                          itemSnapping: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          itemClipBehavior: Clip.antiAlias,
                          onTap: (i) {
                            final memory = memories[i];
                            final controller = ref.read(
                              rediscoverDailySetControllerProvider,
                            );
                            final openContext = RediscoverOpenContext.forMemory(
                              memory,
                              surface: RediscoverSurface.home,
                              position: i,
                            );
                            unawaited(
                              markRediscoverMemoryOpened(
                                controller,
                                memory,
                                openContext: openContext,
                              ),
                            );
                            context.push(
                              '/rediscover/journey',
                              extra: RediscoverJourneyRouteArgs(
                                journey: memory.journey,
                                openContext: openContext,
                              ),
                            );
                          },
                          children: [
                            for (var i = 0; i < previewCount; i++)
                              ClipRect(
                                child: OverflowBox(
                                  alignment: AlignmentDirectional.centerStart,
                                  minWidth: cardWidth,
                                  maxWidth: cardWidth,
                                  child: ExpressiveTapScale(
                                    child: _RediscoverJourneyCard(
                                      memory: memories[i],
                                      height: 224,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : _RediscoverJourneySkeleton(
                        key: const ValueKey('rediscover-journey-skeleton'),
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RediscoverJourneySkeleton extends StatelessWidget {
  const _RediscoverJourneySkeleton({
    super.key,
    required this.cardWidth,
    required this.cardHeight,
  });

  final double cardWidth;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 0, 4),
      child: ClipRect(
        child: SkeletonShimmer(
          child: Row(
            children: [
              SkeletonBox(
                width: cardWidth,
                height: cardHeight,
                borderRadius: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SkeletonBox(
                  width: double.infinity,
                  height: cardHeight,
                  borderRadius: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One-time explainer shown the first time the Rediscover row appears.
class _RediscoverTip extends StatelessWidget {
  const _RediscoverTip({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          AppIcon(AppIcons.rediscover, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.rediscoverTip,
              style: tt.bodySmall?.copyWith(color: cs.onSurface, height: 1.3),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onDismiss,
            tooltip: context.l10n.dismissRediscoverTip,
            icon: Icon(Icons.close, size: 16, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _RediscoverJourneyCard extends StatelessWidget {
  const _RediscoverJourneyCard({required this.memory, required this.height});

  final RediscoverMemory memory;
  final double height;

  @override
  Widget build(BuildContext context) {
    return RediscoverArtworkCard(
      journey: memory.journey,
      title: memory.homeCopy.title,
      supportingText: memory.homeCopy.subtitle,
      metadata: _metadataLine(context, memory),
      height: height,
    );
  }

  String _metadataLine(BuildContext context, RediscoverMemory memory) {
    final strings = context.l10n;
    final waiting = memory.unopenedCount == 0
        ? strings.ready
        : strings.waitingCount(memory.unopenedCount);
    if (memory.journey.kind == RediscoverJourneyKind.returningTopic) {
      return '${strings.backInView} · $waiting';
    }
    final dates = [
      for (final item in memory.journey.items)
        item.url.openedAt ?? item.url.resurfacedAt ?? item.url.savedAt,
    ]..sort((a, b) => b.compareTo(a));
    final opened = dates.isEmpty
        ? strings.justNow
        : _timeAgo(context, dates.first);
    return '$waiting · $opened';
  }

  String _timeAgo(BuildContext context, DateTime date) {
    final strings = context.l10n;
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return strings.justNow;
    if (diff.inMinutes < 60) return strings.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return strings.hoursAgo(diff.inHours);
    if (diff.inDays == 1) return strings.yesterday;
    if (diff.inDays < 7) return strings.daysAgo(diff.inDays);
    if (diff.inDays < 30) return strings.weeksAgo((diff.inDays / 7).floor());
    if (diff.inDays < 365) {
      return strings.monthsAgo((diff.inDays / 30).floor());
    }
    return strings.yearsAgo((diff.inDays / 365).floor());
  }
}
