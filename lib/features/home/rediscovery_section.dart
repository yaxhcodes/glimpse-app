import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/engagement_event.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/dev_simulation_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/rediscovery_service.dart';
import '../../core/services/title_resolver.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/widgets/skeleton.dart';
import '../rediscover/journey_visual.dart';
import '../rediscover/rediscover_journey_provider.dart';
import '../rediscover/rediscover_memory.dart';
import '../rediscover/rediscover_provider.dart';

class RediscoverySection extends ConsumerWidget {
  const RediscoverySection({super.key, this.loadJourneys = true});

  final bool loadJourneys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journeysAsync = loadJourneys
        ? ref.watch(rediscoverJourneysProvider)
        : null;
    final resurfacedAsync = ref.watch(recentlyResurfacedProvider);
    final journeys = journeysAsync?.valueOrNull ?? const <RediscoverJourney>[];
    final resurfaced = resurfacedAsync.valueOrNull ?? const <RediscoveryItem>[];
    final journeysPending =
        !loadJourneys || (journeysAsync?.isLoading ?? false);
    final resurfacedPending = resurfacedAsync.isLoading;
    final showJourneySkeleton = journeys.isEmpty && journeysPending;
    final showResurfacedSkeleton = resurfaced.isEmpty && resurfacedPending;
    if (journeys.isEmpty &&
        resurfaced.isEmpty &&
        !showJourneySkeleton &&
        !showResurfacedSkeleton) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final seenTip = ref.watch(hasSeenRediscoverTipProvider);
    final size = MediaQuery.sizeOf(context);
    final isTablet = size.width > 600;
    // Proportional sizing: the card width is a fixed share of the viewport
    // (leaving a peek of the next card to signal the row scrolls), and the
    // height is derived from a locked aspect ratio and clamped so it stays
    // balanced from compact phones up through tablets.
    const hPad = 16.0;
    final cardWidth = isTablet ? 320.0 : (size.width - hPad * 2) * 0.80;
    final cardHeight = (cardWidth / 1.7).clamp(168.0, 196.0) + 24.0;
    final previewCount = isTablet
        ? journeys.length
        : journeys.length.clamp(0, 4);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
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
                            'Rediscover',
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Worth picking back up',
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
                      Icons.chevron_right,
                      size: 20,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
          if (resurfaced.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: _RecentMemoryTile(
                item: resurfaced.first,
                onTap: () =>
                    _openResurfaced(context, ref, resurfaced.first.url),
              ),
            ),
          if (showResurfacedSkeleton)
            const Padding(
              key: ValueKey('rediscover-resurfaced-skeleton'),
              padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: SkeletonShimmer(
                child: SkeletonBox(
                  width: double.infinity,
                  height: 58,
                  borderRadius: 16,
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
                            unawaited(
                              ref
                                  .read(isarServiceProvider)
                                  .logEvent(
                                    type: EngagementEventType.clusterVisit,
                                    clusterLabel:
                                        journeys[i].topicAnchor ??
                                        journeys[i].title,
                                  ),
                            );
                            context.push(
                              '/rediscover/journey',
                              extra: journeys[i],
                            );
                          },
                          children: [
                            for (var i = 0; i < previewCount; i++)
                              _RediscoverJourneyCard(
                                journey: journeys[i],
                                height: cardHeight,
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

  void _openResurfaced(BuildContext context, WidgetRef ref, SavedUrl url) {
    final service = RediscoveryService(ref.read(isarServiceProvider));
    final container = ProviderScope.containerOf(context, listen: false);
    unawaited(context.push('/url/${url.id}'));
    unawaited(_recordResurfacedOpen(container, service, url));
  }

  Future<void> _recordResurfacedOpen(
    ProviderContainer container,
    RediscoveryService service,
    SavedUrl url,
  ) async {
    try {
      await service.markResurfaced(url.id);
      await service.markOpened(url.id);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to record a resurfaced save open.',
        name: 'RediscoverySection',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    unawaited(
      container
          .read(isarServiceProvider)
          .logEvent(type: EngagementEventType.cardOpened, url: url),
    );
    container.invalidate(recentlyResurfacedProvider);
    container.invalidate(rediscoverJourneysProvider);
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

class _RecentMemoryTile extends StatelessWidget {
  const _RecentMemoryTile({required this.item, required this.onTap});

  final RediscoveryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.history_rounded,
                  size: 20,
                  color: cs.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Back in view',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      TitleResolver.resolveDetailTitle(item.url),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 21,
                color: cs.onSurfaceVariant,
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
              'Rediscover surfaces related saves when the timing feels right.',
              style: tt.bodySmall?.copyWith(color: cs.onSurface, height: 1.3),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onDismiss,
            tooltip: 'Dismiss Rediscover tip',
            icon: Icon(Icons.close, size: 16, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _RediscoverJourneyCard extends StatelessWidget {
  const _RediscoverJourneyCard({required this.journey, required this.height});

  final RediscoverJourney journey;
  final double height;

  @override
  Widget build(BuildContext context) {
    final memory = RediscoverMemory.fromJourney(journey);

    return RediscoverArtworkCard(
      journey: journey,
      title: memory.homeCopy.title,
      supportingText: memory.homeCopy.subtitle,
      metadata: _metadataLine(memory),
      height: height,
    );
  }

  String _metadataLine(RediscoverMemory memory) {
    final dates = [
      for (final item in memory.journey.items)
        item.url.openedAt ?? item.url.resurfacedAt ?? item.url.savedAt,
    ]..sort((a, b) => b.compareTo(a));
    final opened = dates.isEmpty ? 'recently' : _timeAgo(dates.first);
    return '${memory.waitingLabel} · $opened';
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}
