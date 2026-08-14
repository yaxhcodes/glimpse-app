import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/engagement_event.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/rediscovery_service.dart';
import '../../core/services/rediscover_utility_profile.dart';
import '../../core/services/tag_analyzer.dart';
import '../../core/services/title_resolver.dart';
import '../../shared/widgets/app_glass_surface.dart';
import '../../shared/widgets/premium_design_system.dart';
import '../home/home_provider.dart';
import 'journey_visual.dart';
import 'rediscover_daily_set.dart';
import 'rediscover_journey_provider.dart';
import 'rediscover_memory.dart';
import 'rediscover_open_context.dart';
import 'rediscover_provider.dart';

class RediscoverJourneyDetailScreen extends ConsumerWidget {
  const RediscoverJourneyDetailScreen({
    super.key,
    required this.journey,
    this.openContext,
  });

  final RediscoverJourney journey;
  final RediscoverOpenContext? openContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final tagFrequency = ref.watch(tagOccurrenceMapProvider);
    final memory = RediscoverMemory.fromJourney(
      journey,
      tagFrequency: tagFrequency,
    );
    final urls = _uniqueUrls(journey);
    final featured = _featuredUrl(journey, urls);
    final supporting = urls.where((url) => url.id != featured?.id).toList();
    final allIds = urls.map((url) => url.id).toList();
    final attribution =
        openContext ??
        RediscoverOpenContext.forMemory(
          memory,
          surface: RediscoverSurface.rediscover,
          position: 0,
        );

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: const AppGlassSurface(),
            title: Text(
              'Rediscover',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SliverToBoxAdapter(child: _MemoryHero(memory: memory)),
          SliverToBoxAdapter(child: _WhyToday(memory: memory)),
          SliverToBoxAdapter(
            child: _MemoryActions(
              onSnooze: () => _snooze(context, ref, memory, attribution),
              onLessLikeThis: () =>
                  _lessLikeThis(context, ref, memory, attribution),
            ),
          ),
          if (featured != null) ...[
            const SliverToBoxAdapter(child: SectionTitle('Start here')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                child: _MemorySaveTile(
                  url: featured,
                  badge: _badgeFor(featured, journey.kind),
                  reason: _reasonFor(featured, journey),
                  tagFrequency: tagFrequency,
                  featured: true,
                  onTap: () => _openUrl(
                    context,
                    ref,
                    memory,
                    featured,
                    allIds,
                    attribution,
                  ),
                ),
              ),
            ),
          ],
          if (supporting.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionTitle(
                'More in ${memory.topicLabel}',
                count: supporting.length,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final url = supporting[index];
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    index == 0 ? 2 : 5,
                    16,
                    index == supporting.length - 1 ? 10 : 5,
                  ),
                  child: _MemorySaveTile(
                    url: url,
                    badge: _badgeFor(url, journey.kind),
                    reason: _reasonFor(url, journey),
                    tagFrequency: tagFrequency,
                    onTap: () => _openUrl(
                      context,
                      ref,
                      memory,
                      url,
                      allIds,
                      attribution,
                    ),
                  ),
                );
              }, childCount: supporting.length),
            ),
          ],
          SliverToBoxAdapter(
            child: _RelatedInterests(memory: memory, journey: journey),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Future<void> _openUrl(
    BuildContext context,
    WidgetRef ref,
    RediscoverMemory memory,
    SavedUrl url,
    List<int> ids,
    RediscoverOpenContext attribution,
  ) async {
    HapticFeedback.lightImpact();
    final service = RediscoveryService(ref.read(isarServiceProvider));
    await service.markResurfaced(url.id);
    await service.markOpened(url.id);
    if (url.isQueued) {
      await ref.read(isarServiceProvider).clearIntent(url.id);
    }
    await ref
        .read(isarServiceProvider)
        .logEvent(
          type: EngagementEventType.cardOpened,
          url: url,
          clusterLabel: memory.topicKey,
          memoryId: attribution.memoryId,
          topicKey: attribution.topicKey,
          surface: attribution.surface.name,
          position: attribution.position,
          reasonCode: attribution.reasonCode.name,
          confidenceTier: attribution.confidenceTier,
          algorithmVersion: attribution.algorithmVersion,
          exposureId: attribution.exposureId,
        );
    ref.invalidate(rediscoverUtilityProfileProvider);
    ref.invalidate(todaysPicksProvider);
    ref.invalidate(revisitQueueProvider);
    ref.invalidate(relatedSavesProvider);
    ref.invalidate(recentlyResurfacedProvider);
    ref.invalidate(rediscoverRecapsProvider);
    if (context.mounted) {
      context.push(
        '/url/${url.id}',
        extra: UrlDetailRouteArgs(
          siblingIds: ids,
          rediscoverContext: attribution,
        ),
      );
    }
  }

  Future<void> _snooze(
    BuildContext context,
    WidgetRef ref,
    RediscoverMemory memory,
    RediscoverOpenContext attribution,
  ) async {
    HapticFeedback.selectionClick();
    await snoozeRediscoverMemory(
      ref.read(rediscoverDailySetControllerProvider),
      memory,
      openContext: attribution,
    );
    if (context.mounted) context.pop();
  }

  Future<void> _lessLikeThis(
    BuildContext context,
    WidgetRef ref,
    RediscoverMemory memory,
    RediscoverOpenContext attribution,
  ) async {
    HapticFeedback.selectionClick();
    await suppressRediscoverTopic(
      ref.read(rediscoverDailySetControllerProvider),
      memory,
      openContext: attribution,
    );
    if (context.mounted) context.pop();
  }
}

List<SavedUrl> _uniqueUrls(RediscoverJourney journey) {
  final seen = <int>{};
  return [
    for (final item in journey.items)
      if (seen.add(item.url.id)) item.url,
  ];
}

SavedUrl? _featuredUrl(RediscoverJourney journey, List<SavedUrl> urls) {
  final preferredId = journey.recommendedFirstSaveId;
  if (preferredId != null) {
    for (final url in urls) {
      if (url.id == preferredId) return url;
    }
  }
  return urls.firstOrNull;
}

String _badgeFor(SavedUrl url, RediscoverJourneyKind kind) {
  if (url.isQueued) return 'Queued';
  if (url.openedAt != null) return 'Previously opened';
  if (kind == RediscoverJourneyKind.returningTopic) return 'Back in view';
  if (kind == RediscoverJourneyKind.onThisDay) return 'From your past';
  if (kind == RediscoverJourneyKind.forgottenGems ||
      DateTime.now().difference(url.savedAt).inDays >= 21) {
    return 'Forgotten gem';
  }
  return 'Unopened';
}

String _reasonFor(SavedUrl url, RediscoverJourney journey) {
  for (final item in journey.items) {
    if (item.url.id == url.id) return '${item.reason} · ${item.timeAgo}';
  }
  return _badgeFor(url, journey.kind);
}

class _MemoryHero extends StatelessWidget {
  const _MemoryHero({required this.memory});

  final RediscoverMemory memory;

  @override
  Widget build(BuildContext context) {
    final count = memory.saveCount;
    final metadata = memory.journey.kind == RediscoverJourneyKind.returningTopic
        ? 'Back in view · ${count == 1 ? '1 earlier save' : '$count earlier saves'}'
        : (count == 1 ? '1 save' : '$count connected saves');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: RediscoverArtworkCard(
        journey: memory.journey,
        title: memory.rediscoverCopy.title,
        supportingText: memory.rediscoverCopy.subtitle,
        metadata: metadata,
        height: 232,
        hero: true,
        borderRadius: 28,
      ),
    );
  }
}

class _WhyToday extends StatelessWidget {
  const _WhyToday({required this.memory});

  final RediscoverMemory memory;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final narrative = memory.journey.narrative?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHY TODAY',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            memory.copyIdentity.reasonForToday,
            style: tt.bodyLarge?.copyWith(
              color: cs.onSurface,
              height: 1.38,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (narrative != null && narrative.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              narrative,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.38,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemoryActions extends StatelessWidget {
  const _MemoryActions({required this.onSnooze, required this.onLessLikeThis});

  final VoidCallback onSnooze;
  final VoidCallback onLessLikeThis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onSnooze,
              icon: const Icon(Icons.schedule_rounded, size: 18),
              label: const Text('Not now'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onLessLikeThis,
              icon: const Icon(Icons.thumb_down_alt_outlined, size: 18),
              label: const Text('Less like this'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemorySaveTile extends StatelessWidget {
  const _MemorySaveTile({
    required this.url,
    required this.badge,
    required this.reason,
    required this.tagFrequency,
    required this.onTap,
    this.featured = false,
  });

  final SavedUrl url;
  final String badge;
  final String reason;
  final Map<String, int> tagFrequency;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final thumbnail = url.thumbnailUrl?.trim();
    return Material(
      color: featured
          ? cs.secondaryContainer.withValues(alpha: 0.34)
          : cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(featured ? 20 : 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(featured ? 14 : 11),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(featured ? 14 : 12),
                child: SizedBox(
                  width: featured ? 72 : 54,
                  height: featured ? 72 : 54,
                  child: thumbnail != null && thumbnail.isNotEmpty
                      ? Image.network(
                          thumbnail,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _fallback(cs),
                        )
                      : _fallback(cs),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge,
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      TitleResolver.resolveDetailTitle(
                        url,
                        tagFrequency: tagFrequency,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: (featured ? tt.titleSmall : tt.bodyMedium)
                          ?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      reason,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback(ColorScheme cs) {
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.bookmark_outline_rounded, color: cs.onSurfaceVariant),
    );
  }
}

class _RelatedInterests extends StatelessWidget {
  const _RelatedInterests({required this.memory, required this.journey});

  final RediscoverMemory memory;
  final RediscoverJourney journey;

  @override
  Widget build(BuildContext context) {
    final topics = _topics();
    if (topics.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
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
              for (final topic in topics.take(5))
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
    final identity = '${memory.topicLabel} ${memory.rediscoverCopy.title}'
        .toLowerCase();
    final sorted =
        counts.entries
            .where(
              (entry) =>
                  entry.value >= 2 &&
                  !identity.contains(entry.key.toLowerCase()) &&
                  !entry.key.toLowerCase().contains(
                    memory.topicKey.toLowerCase(),
                  ),
            )
            .toList()
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
