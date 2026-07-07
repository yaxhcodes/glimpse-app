import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/engagement_event.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/rediscovery_service.dart';
import '../../core/services/tag_analyzer.dart';
import '../../core/services/title_resolver.dart';
import '../../shared/widgets/premium_design_system.dart';
import '../../shared/widgets/swipeable_url_card.dart';
import '../home/home_provider.dart';
import 'journey_visual.dart';
import 'rediscover_journey_provider.dart';
import 'rediscover_memory.dart';
import 'rediscover_provider.dart';

class RediscoverJourneyDetailScreen extends ConsumerWidget {
  const RediscoverJourneyDetailScreen({super.key, required this.journey});

  final RediscoverJourney journey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = visualForJourney(context, journey);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final tagFrequency = ref.watch(tagOccurrenceMapProvider);
    final memory = RediscoverMemory.fromJourney(
      journey,
      tagFrequency: tagFrequency,
    );
    final items = journey.items;
    final connected = items.map((item) => item.url).toList();
    final forgotten = items
        .where((item) => item.url.openedAt == null)
        .take(4)
        .toList();
    final revisit = items
        .where((item) => item.url.isRevisitDue || item.url.openedAt != null)
        .take(4)
        .toList();

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: cs.surface,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Rediscover',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SliverToBoxAdapter(
            child: _JourneyHero(memory: memory, visual: visual),
          ),
          SliverToBoxAdapter(child: _JourneyTimeline(journey: journey)),
          SliverToBoxAdapter(child: _MemoryReasoning(memory: memory)),
          if (revisit.isNotEmpty)
            _JourneyRail(
              title: 'Continue from here',
              items: revisit,
              tagFrequency: tagFrequency,
              onOpen: (url) => _open(context, ref, url, connected),
            ),
          if (forgotten.isNotEmpty)
            _JourneyRail(
              title: 'Forgotten gems',
              items: forgotten,
              tagFrequency: tagFrequency,
              onOpen: (url) => _open(context, ref, url, connected),
            ),
          SliverToBoxAdapter(child: _RelatedInterests(journey: journey)),
          SliverToBoxAdapter(
            child: SectionTitle('Connected saves', count: connected.length),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final url = connected[index];
              final ids = connected.map((item) => item.id).toList();
              return SwipeableUrlCard(
                key: ValueKey(url.id),
                url: url,
                onTap: () => _open(context, ref, url, connected, ids: ids),
              );
            }, childCount: connected.length),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    SavedUrl url,
    List<SavedUrl> connected, {
    List<int>? ids,
  }) async {
    HapticFeedback.lightImpact();
    final service = RediscoveryService(ref.read(isarServiceProvider));
    await service.markResurfaced(url.id);
    await service.markOpened(url.id);
    if (url.isQueued) {
      await ref.read(isarServiceProvider).clearIntent(url.id);
    }
    unawaited(
      ref
          .read(isarServiceProvider)
          .logEvent(
            type: EngagementEventType.cardOpened,
            url: url,
            clusterLabel: journey.topicAnchor ?? journey.title,
          ),
    );
    ref.invalidate(todaysPicksProvider);
    ref.invalidate(revisitQueueProvider);
    ref.invalidate(relatedSavesProvider);
    ref.invalidate(recentlyResurfacedProvider);
    ref.invalidate(rediscoverRecapsProvider);
    ref.invalidate(rediscoverJourneysProvider);
    if (context.mounted) {
      context.push(
        '/url/${url.id}',
        extra: ids ?? connected.map((item) => item.id).toList(),
      );
    }
  }
}

class _MemoryReasoning extends StatelessWidget {
  const _MemoryReasoning({required this.memory});

  final RediscoverMemory memory;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final narrative = memory.journey.narrative ?? memory.rediscoverCopy.body;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            narrative,
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurface,
              height: 1.38,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (memory.rediscoverCopy.actionLabel.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              memory.rediscoverCopy.actionLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tt.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _JourneyHero extends StatelessWidget {
  const _JourneyHero({required this.memory, required this.visual});

  final RediscoverMemory memory;
  final JourneyVisual visual;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final title = memory.journey.title.trim().isNotEmpty
        ? memory.journey.title
        : memory.rediscoverCopy.title;
    final subtitle = memory.journey.hookLine ?? memory.rediscoverCopy.subtitle;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconWashOpacity = isDark ? 0.22 : 0.32;
    const height = 232.0;
    const iconSize = height * 1.02;
    return Container(
      height: height,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: visual.colors,
        ),
      ),
      child: Stack(
        children: [
          // Fused category glyph: oversized, accent-tinted, bleeding off the
          // top-left and fading diagonally — same language as the home card.
          Positioned(
            left: -iconSize * 0.15,
            top: -iconSize * 0.22,
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
                variant: memory.id.hashCode,
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
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Text(
                  visual.eyebrow,
                  style: tt.labelSmall?.copyWith(
                    color: visual.mutedForeground.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: tt.headlineSmall?.copyWith(
                    color: visual.foreground,
                    fontWeight: FontWeight.w800,
                    height: 1.04,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(
                    color: visual.mutedForeground,
                    fontWeight: FontWeight.w600,
                    height: 1.28,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyTimeline extends StatelessWidget {
  const _JourneyTimeline({required this.journey});

  final RediscoverJourney journey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sorted = [...journey.items]
      ..sort((a, b) => b.url.savedAt.compareTo(a.url.savedAt));
    final first = sorted.isNotEmpty ? sorted.last.url.savedAt : null;
    final latest = sorted.isNotEmpty ? sorted.first.url.savedAt : null;
    final unopened = journey.items
        .where((item) => item.url.openedAt == null)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
      child: Row(
        children: [
          Expanded(
            child: _TimelinePoint(
              label: 'Started',
              value: first == null ? 'Recently' : _timeAgo(first),
            ),
          ),
          Container(
            width: 1,
            height: 34,
            color: cs.outlineVariant.withValues(alpha: 0.55),
          ),
          Expanded(
            child: _TimelinePoint(
              label: 'Waiting',
              value: unopened == 0 ? 'Fresh picks' : '$unopened unopened',
            ),
          ),
          Container(
            width: 1,
            height: 34,
            color: cs.outlineVariant.withValues(alpha: 0.55),
          ),
          Expanded(
            child: _TimelinePoint(
              label: 'Latest',
              value: latest == null ? 'Today' : _timeAgo(latest),
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'today';
    if (diff.inHours < 24) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}

class _TimelinePoint extends StatelessWidget {
  const _TimelinePoint({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.labelMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedInterests extends StatelessWidget {
  const _RelatedInterests({required this.journey});

  final RediscoverJourney journey;

  @override
  Widget build(BuildContext context) {
    final topics = _topics();
    if (topics.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Related interests',
            style: tt.titleSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final topic in topics.take(6))
                MonochromePill(topic, compact: true),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _topics() {
    final counts = <String, int>{};
    for (final item in journey.items) {
      for (final tag in TagAnalyzer.notificationTopicTags(item.url.tags)) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((entry) => _titleCase(entry.key)).toList();
  }

  String _titleCase(String value) {
    return value
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _JourneyRail extends StatelessWidget {
  const _JourneyRail({
    required this.title,
    required this.items,
    required this.tagFrequency,
    required this.onOpen,
  });

  final String title;
  final List<RediscoveryItem> items;
  final Map<String, int> tagFrequency;
  final ValueChanged<SavedUrl> onOpen;

  @override
  Widget build(BuildContext context) {
    final metrics = CinematicRailMetrics.of(context);
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title, count: items.length),
          SizedBox(
            height: metrics.listHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return SizedBox(
                  width: metrics.cardWidth,
                  child: CinematicCard(
                    imageUrl: item.url.thumbnailUrl,
                    title: TitleResolver.resolveDetailTitle(
                      item.url,
                      tagFrequency: tagFrequency,
                    ),
                    subtitle: '${item.reason} · ${item.timeAgo}',
                    reason: item.reason,
                    tags: item.url.tags.take(2).toList(),
                    onTap: () => onOpen(item.url),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
