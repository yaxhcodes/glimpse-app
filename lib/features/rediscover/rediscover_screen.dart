import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/engagement_event.dart';
import '../../core/providers/service_providers.dart';
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
      ref.read(isarServiceProvider).logEvent(
            type: EngagementEventType.clusterVisit,
            clusterLabel: journey.topicAnchor ?? journey.title,
          ),
    );
    context.push('/rediscover/journey', extra: journey);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final tagFreq = ref.watch(tagOccurrenceMapProvider);
    final statsAsync = ref.watch(rediscoveryStatsProvider);
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
        : 'The quiet threads are still here';

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

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 168,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: visual.colors,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: JourneyMotifPainter(
                        motif: visual.motif,
                        color: visual.motifColor,
                        variant: journey.title.hashCode,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -18,
                    top: -20,
                    child: Icon(
                      visual.icon,
                      size: 136,
                      color: visual.accentColor.withValues(alpha: 0.18),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            visual.eyebrow,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.labelSmall?.copyWith(
                              color: visual.mutedForeground,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              fontSize: 10,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            memory.rediscoverCopy.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tt.headlineSmall?.copyWith(
                              color: visual.foreground,
                              fontWeight: FontWeight.w800,
                              height: 1.08,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            memory.rediscoverCopy.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.labelMedium?.copyWith(
                              color: visual.mutedForeground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memory.rediscoverCopy.body,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  if (memory.primaryTitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      memory.rediscoverCopy.actionLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _MemoryMetaPill('${memory.saveCount} saves'),
                      const SizedBox(width: 8),
                      _MemoryMetaPill(memory.waitingLabel),
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
