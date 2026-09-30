import '../glimpses/glimpse_home_adapter.dart';
import '../glimpses/glimpse_open.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/dev_simulation_providers.dart';
import '../../core/services/app_haptics.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/widgets/card_open_transition.dart';
import '../url_detail/url_detail_provider.dart' show UrlDetailSeed;
import '../../shared/widgets/expressive_tap_scale.dart';
import '../../shared/widgets/skeleton.dart';
import '../rediscover/journey_visual.dart';
import 'home_section_header.dart';
import '../rediscover/rediscover_journey_provider.dart';
import '../rediscover/rediscover_memory.dart';

class RediscoverySection extends ConsumerWidget {
  const RediscoverySection({super.key, this.loadJourneys = true});

  final bool loadJourneys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        child: _buildContent(context, ref, duration),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, Duration duration) {
    final dailySetAsync = loadJourneys
        ? ref.watch(glimpseHomeSetProvider)
        : null;
    final memories =
        dailySetAsync?.valueOrNull?.memories ?? const <RediscoverMemory>[];
    final pending = !loadJourneys || (dailySetAsync?.isLoading ?? false);
    final availability = pending && memories.isEmpty
        ? ref.watch(glimpseHomeHasCardsProvider)
        : null;
    if (availability != null &&
        availability.isLoading &&
        !availability.hasValue) {
      return const SizedBox.shrink();
    }
    final showSkeleton =
        pending && memories.isEmpty && (availability?.valueOrNull ?? false);
    final showGlimpsesEntry = memories.isEmpty && !showSkeleton;

    final showTip =
        !ref.watch(hasSeenRediscoverTipProvider) && memories.isNotEmpty;
    // Opening Rediscover is as good as reading the tip.
    void markTipSeen() {
      if (showTip) ref.read(hasSeenRediscoverTipProvider.notifier).set(true);
    }

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
      key: ValueKey(
        showGlimpsesEntry ? 'your-glimpses-entry' : 'rediscover-content',
      ),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(
            title: showGlimpsesEntry
                ? context.l10n.glimpsesTitle
                : context.l10n.rediscover,
            subtitle: showGlimpsesEntry
                ? null
                : context.l10n.rediscoverSubtitle,
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            // Without Rediscover cards the header is "Your Glimpses": go
            // straight there rather than to an empty Rediscover page.
            onTap: () {
              markTipSeen();
              context.push(
                showGlimpsesEntry ? '/glimpses/history' : '/rediscover',
              );
            },
          ),
          if (showTip) _RediscoverTip(onDismiss: markTipSeen),
          if (previewCount > 0 || showSkeleton)
            SizedBox(
              height: cardHeight + 8,
              child: AnimatedSwitcher(
                duration: duration,
                child: showSkeleton
                    ? _RediscoverJourneySkeleton(
                        key: const ValueKey('rediscover-journey-skeleton'),
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                      )
                    : Padding(
                        key: const ValueKey('rediscover-journey-carousel'),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        // The carousel's tap layer covers the cards, so tell
                        // them where the finger went down: a single save
                        // then opens out of its card.
                        child: Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: (event) =>
                              CardOpenOrigin.notePress(event.position),
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
                              markTipSeen();
                              final memory = memories[i];
                              // A single save opens its Details: hand over
                              // the save so its first frame isn't a spinner.
                              final saves = {
                                for (final item in memory.journey.items)
                                  item.url.id: item.url,
                              };
                              if (saves.length == 1) {
                                UrlDetailSeed.offer(saves.values.single);
                              }
                              openGlimpse(
                                context,
                                memory.id,
                                memory.journey.items
                                    .map((item) => item.url.id)
                                    .toList(),
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
                        ),
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
/// First-run note under the Rediscover header: what the cards below are.
/// A quiet tonal surface in the section's own voice, not an alert; it goes
/// away on "Got it" or as soon as a card or the page is opened.
class _RediscoverTip extends StatelessWidget {
  const _RediscoverTip({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: AppIcon(
              AppIcons.rediscover,
              size: 16,
              color: cs.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.rediscoverTip,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSecondaryContainer,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () {
              AppHaptics.play(AppHaptics.tick);
              onDismiss();
            },
            style: TextButton.styleFrom(
              foregroundColor: cs.onSecondaryContainer,
              visualDensity: VisualDensity.compact,
              textStyle: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            child: Text(context.l10n.gotIt),
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
      // Flies into the same card at the top of the Glimpse it opens.
      heroTag: rediscoverCardHeroTag(memory.id),
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
