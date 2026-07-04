import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/engagement_event.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/rediscovery_service.dart';
import '../../shared/widgets/premium_design_system.dart';
import '../home/home_provider.dart';
import 'journey_visual.dart';
import 'rediscover_journey_provider.dart';
import 'rediscover_memory.dart';
import 'rediscover_provider.dart';

class RediscoverScreen extends ConsumerStatefulWidget {
  const RediscoverScreen({super.key});

  @override
  ConsumerState<RediscoverScreen> createState() => _RediscoverScreenState();
}

class _RediscoverScreenState extends ConsumerState<RediscoverScreen> {
  void _openJourney(RediscoverJourney journey) {
    HapticFeedback.lightImpact();
    unawaited(
      ref
          .read(isarServiceProvider)
          .logEvent(
            type: EngagementEventType.clusterVisit,
            clusterLabel: journey.topicAnchor ?? journey.title,
          ),
    );
    context.push('/rediscover/journey', extra: journey);
  }

  Future<void> _openUrl(SavedUrl url) async {
    HapticFeedback.lightImpact();
    final service = RediscoveryService(ref.read(isarServiceProvider));
    await service.markResurfaced(url.id);
    await service.markOpened(url.id);
    unawaited(
      ref
          .read(isarServiceProvider)
          .logEvent(type: EngagementEventType.cardOpened, url: url),
    );
    ref.invalidate(todaysPicksProvider);
    ref.invalidate(revisitQueueProvider);
    ref.invalidate(interestShelfProvider);
    ref.invalidate(rediscoverTodayProvider);
    ref.invalidate(rediscoverJourneysProvider);
    if (mounted) {
      context.push('/url/${url.id}');
    }
  }

  void _openTodaySlot(RediscoverTodaySlot slot) {
    final journey = slot.journey;
    if (journey != null) {
      _openJourney(journey);
      return;
    }
    final url = slot.item?.url;
    if (url != null) {
      unawaited(_openUrl(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final tagFreq = ref.watch(tagOccurrenceMapProvider);
    final statsAsync = ref.watch(rediscoveryStatsProvider);
    final todayAsync = ref.watch(rediscoverTodayProvider);
    final journeysAsync = ref.watch(rediscoverJourneysProvider);

    return Scaffold(
      backgroundColor: premiumBackground(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: premiumBackground(context),
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Rediscover',
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          SliverToBoxAdapter(child: _IntentHeader(statsAsync: statsAsync)),
          todayAsync.when(
            skipLoadingOnReload: true,
            data: (slots) => slots.isEmpty
                ? const SliverToBoxAdapter(child: SizedBox.shrink())
                : SliverToBoxAdapter(
                    child: _TodaySection(slots: slots, onTap: _openTodaySlot),
                  ),
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          journeysAsync.when(
            skipLoadingOnReload: true,
            data: (journeys) {
              if (journeys.isEmpty) {
                return const SliverToBoxAdapter(child: _NoMemoriesYet());
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final journey = journeys[index];
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      index == 0 ? 10 : 6,
                      16,
                      index == journeys.length - 1 ? 14 : 6,
                    ),
                    child: _MemoryJourneyCard(
                      journey: journey,
                      tagFrequency: tagFreq,
                      onTap: () => _openJourney(journey),
                    ),
                  );
                }, childCount: journeys.length),
              );
            },
            loading: () => const SliverToBoxAdapter(child: _JourneySkeleton()),
            error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }
}

class _IntentHeader extends StatelessWidget {
  final AsyncValue<RediscoveryStats> statsAsync;

  const _IntentHeader({required this.statsAsync});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final stats = statsAsync.valueOrNull;
    final unopened = stats?.unopened ?? 0;

    final headline = unopened > 0
        ? 'A few memories worth returning to'
        : 'The quiet saves are still here';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              letterSpacing: -0.15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            unopened > 0
                ? "$unopened unopened saves, grouped by what they mean."
                : 'Chosen from what you saved, opened, and left for later.',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryJourneyCard extends StatelessWidget {
  const _MemoryJourneyCard({
    required this.journey,
    required this.tagFrequency,
    required this.onTap,
  });

  final RediscoverJourney journey;
  final Map<String, int> tagFrequency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final memory = RediscoverMemory.fromJourney(
      journey,
      tagFrequency: tagFrequency,
    );
    final visual = visualForJourney(context, memory.journey);
    final title = journey.title.trim().isNotEmpty
        ? journey.title
        : memory.rediscoverCopy.title;
    final eyebrow = (journey.categoryLabel ?? visual.eyebrow).toUpperCase();
    final hook = journey.hookLine ?? memory.rediscoverCopy.body;

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: visual.colors,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  visual.icon,
                  color: visual.foreground.withValues(alpha: 0.88),
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w800,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      hook,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _MemoryMetaPill(_metadataLine(memory)),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
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
    final total = memory.saveCount;
    final unopened = memory.unopenedCount;
    if (unopened == total) return '$total saves · all unopened';
    return '$total saves · $unopened unopened';
  }
}

class _TodaySection extends StatelessWidget {
  const _TodaySection({required this.slots, required this.onTap});

  final List<RediscoverTodaySlot> slots;
  final ValueChanged<RediscoverTodaySlot> onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today',
            style: tt.titleMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final slot in slots)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TodaySlotTile(slot: slot, onTap: () => onTap(slot)),
            ),
          Divider(height: 18, color: cs.outlineVariant.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}

class _TodaySlotTile extends StatelessWidget {
  const _TodaySlotTile({required this.slot, required this.onTap});

  final RediscoverTodaySlot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final thumb = slot.item?.url.thumbnailUrl;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: thumb?.trim().isNotEmpty == true
                      ? Image.network(
                          thumb!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _slotIcon(cs),
                        )
                      : _slotIcon(cs),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      slot.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slotIcon(ColorScheme cs) {
    return DecoratedBox(
      decoration: BoxDecoration(color: cs.surfaceContainerHighest),
      child: Icon(slot.icon, color: cs.onSurfaceVariant, size: 22),
    );
  }
}

class _MemoryMetaPill extends StatelessWidget {
  const _MemoryMetaPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(
          color: cs.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NoMemoriesYet extends StatelessWidget {
  const _NoMemoriesYet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: cs.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              'Nothing strong enough today',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              'When a saved thread becomes worth returning to, it will appear here.',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneySkeleton extends StatelessWidget {
  const _JourneySkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        height: 284,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
        ),
      ),
    );
  }
}
