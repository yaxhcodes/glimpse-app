import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/engagement_event.dart';
import '../../core/providers/dev_simulation_providers.dart';
import '../../core/providers/service_providers.dart';
import '../rediscover/journey_visual.dart';
import '../rediscover/rediscover_journey_provider.dart';
import '../rediscover/rediscover_memory.dart';

class RediscoverySection extends ConsumerWidget {
  const RediscoverySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(rediscoverJourneysProvider);
    return async.when(
      skipLoadingOnReload: true,
      data: (journeys) {
        if (journeys.isEmpty) return const SizedBox.shrink();
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
        final cardWidth = isTablet ? 320.0 : (size.width - hPad * 2) * 0.85;
        final cardHeight = (cardWidth / 1.7).clamp(168.0, 196.0);
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 4,
                    ),
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
              SizedBox(
                height: cardHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: hPad),
                  itemCount: previewCount,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => _RediscoverJourneyCard(
                    journey: journeys[i],
                    width: cardWidth,
                    height: cardHeight,
                    onTap: () {
                      unawaited(
                        ref
                            .read(isarServiceProvider)
                            .logEvent(
                              type: EngagementEventType.clusterVisit,
                              clusterLabel:
                                  journeys[i].topicAnchor ?? journeys[i].title,
                            ),
                      );
                      context.push('/rediscover/journey', extra: journeys[i]);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
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
          Icon(Icons.auto_awesome, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Rediscover surfaces related saves when the timing feels right.',
              style: tt.bodySmall?.copyWith(color: cs.onSurface, height: 1.3),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onDismiss,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(Icons.close, size: 16, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _RediscoverJourneyCard extends StatelessWidget {
  const _RediscoverJourneyCard({
    required this.journey,
    required this.onTap,
    required this.width,
    required this.height,
  });

  final RediscoverJourney journey;
  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final memory = RediscoverMemory.fromJourney(journey);
    final visual = visualForJourney(context, journey);
    final title = journey.title.trim().isNotEmpty
        ? journey.title
        : memory.homeCopy.title;
    final hook = journey.hookLine ?? _metadataLine(memory);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Light mode needs a touch more presence for the wash to register.
    final iconWashOpacity = isDark ? 0.22 : 0.32;
    // The fused glyph scales with the card so the bleed stays proportional.
    final iconSize = height * 1.04;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: visual.colors,
            ),
          ),
          child: Stack(
            children: [
              // Fused category icon: oversized, accent-tinted, bleeding off the
              // top-left corner and fading diagonally into the gradient. No
              // chip or frame — the glyph itself is the texture.
              Positioned(
                left: -iconSize * 0.16,
                top: -iconSize * 0.24,
                child: Opacity(
                  opacity: iconWashOpacity,
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          visual.accentColor.withValues(alpha: 1),
                          visual.accentColor.withValues(alpha: 0),
                        ],
                        stops: const [0.08, 0.70],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Icon(
                      visual.icon,
                      size: iconSize,
                      color: visual.accentColor,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: JourneyMotifPainter(
                    motif: visual.motif,
                    color: visual.motifColor,
                    variant: journey.title.hashCode,
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: visual.overlayColors,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Text(
                      visual.eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelSmall?.copyWith(
                        color: visual.mutedForeground.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleLarge?.copyWith(
                        color: visual.foreground,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.14,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      hook,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelMedium?.copyWith(
                        color: visual.mutedForeground.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _metadataLine(RediscoverMemory memory) {
    final n = memory.saveCount;
    final dates = [
      for (final item in memory.journey.items)
        item.url.openedAt ?? item.url.resurfacedAt ?? item.url.savedAt,
    ]..sort((a, b) => b.compareTo(a));
    final opened = dates.isEmpty ? 'recently' : _timeAgo(dates.first);
    return '$n ${n == 1 ? 'save' : 'saves'} · ${memory.waitingLabel} · $opened';
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
