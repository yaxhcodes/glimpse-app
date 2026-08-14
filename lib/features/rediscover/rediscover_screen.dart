import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/app_glass_surface.dart';
import '../../shared/widgets/premium_design_system.dart';
import 'journey_visual.dart';
import 'rediscover_daily_set.dart';
import 'rediscover_journey_provider.dart';
import 'rediscover_memory.dart';
import 'rediscover_memory_prefs.dart';
import 'rediscover_open_context.dart';
import 'rediscover_provider.dart';

class RediscoverScreen extends ConsumerWidget {
  const RediscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final statsAsync = ref.watch(rediscoveryStatsProvider);
    final dailySetAsync = ref.watch(rediscoverDailySetProvider);
    final recapsAsync = ref.watch(rediscoverRecapsProvider);
    final memories = dailySetAsync.valueOrNull?.memories;
    if (memories != null && memories.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final controller = ref.read(rediscoverDailySetControllerProvider);
        for (var index = 0; index < memories.length; index++) {
          unawaited(
            markRediscoverMemoryShown(
              controller,
              memories[index],
              surface: RediscoverSurface.rediscover,
              position: index,
            ),
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: premiumBackground(context),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(rediscoverDailySetProvider);
          ref.invalidate(rediscoverRecapsProvider);
          ref.invalidate(rediscoveryStatsProvider);
          await ref.read(rediscoverDailySetProvider.future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: AppGlassSurface(
                backgroundColor: premiumBackground(context),
              ),
              title: Text(
                'Rediscover',
                style: tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            SliverToBoxAdapter(child: _IntentHeader(statsAsync: statsAsync)),
            dailySetAsync.when(
              skipLoadingOnReload: true,
              data: (set) => set.memories.isEmpty
                  ? const SliverToBoxAdapter(child: _NoMemoriesToday())
                  : _DailyMemorySection(
                      memories: set.memories,
                      onOpen: (memory, position) =>
                          _openMemory(context, ref, memory, position),
                      onSnooze: (memory, position) =>
                          _snooze(context, ref, memory, position),
                      onLessLikeThis: (memory, position) =>
                          _lessLikeThis(context, ref, memory, position),
                    ),
              loading: () =>
                  const SliverToBoxAdapter(child: _DailySetSkeleton()),
              error: (_, _) =>
                  const SliverToBoxAdapter(child: _NoMemoriesToday()),
            ),
            recapsAsync.when(
              skipLoadingOnReload: true,
              data: (recaps) => _RecapSection(
                recaps: recaps
                    .where(
                      (recap) => recap.cadence != RediscoverRecapCadence.daily,
                    )
                    .toList(),
                onOpen: (recap) => _openRecap(context, ref, recap),
              ),
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, _) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }

  void _openMemory(
    BuildContext context,
    WidgetRef ref,
    RediscoverMemory memory,
    int position,
  ) {
    HapticFeedback.lightImpact();
    final controller = ref.read(rediscoverDailySetControllerProvider);
    final openContext = RediscoverOpenContext.forMemory(
      memory,
      surface: RediscoverSurface.rediscover,
      position: position,
    );
    unawaited(
      markRediscoverMemoryOpened(controller, memory, openContext: openContext),
    );
    context.push(
      '/rediscover/journey',
      extra: RediscoverJourneyRouteArgs(
        journey: memory.journey,
        openContext: openContext,
      ),
    );
  }

  Future<void> _snooze(
    BuildContext context,
    WidgetRef ref,
    RediscoverMemory memory,
    int position,
  ) async {
    HapticFeedback.selectionClick();
    final controller = ref.read(rediscoverDailySetControllerProvider);
    await snoozeRediscoverMemory(
      controller,
      memory,
      openContext: RediscoverOpenContext.forMemory(
        memory,
        surface: RediscoverSurface.rediscover,
        position: position,
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Hidden for 7 days'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _lessLikeThis(
    BuildContext context,
    WidgetRef ref,
    RediscoverMemory memory,
    int position,
  ) async {
    HapticFeedback.selectionClick();
    final controller = ref.read(rediscoverDailySetControllerProvider);
    await suppressRediscoverTopic(
      controller,
      memory,
      openContext: RediscoverOpenContext.forMemory(
        memory,
        surface: RediscoverSurface.rediscover,
        position: position,
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('You’ll see less like this'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _openRecap(
    BuildContext context,
    WidgetRef ref,
    RediscoverRecap recap,
  ) async {
    HapticFeedback.lightImpact();
    await RediscoverMemoryPrefs.markRecapSeen(
      cadence: recap.cadence.name,
      itemIds: recap.items.map((item) => item.url.id).toList(),
    );
    ref.invalidate(rediscoverRecapsProvider);
    if (context.mounted) {
      context.push('/rediscover/recap', extra: recap);
    }
  }
}

class _IntentHeader extends StatelessWidget {
  const _IntentHeader({required this.statsAsync});

  final AsyncValue<RediscoveryStats> statsAsync;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final unopened = statsAsync.valueOrNull?.unopened ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A few memories worth using',
            style: AppTypography.editorial(
              tt.titleSmall,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            unopened > 0
                ? 'Chosen from $unopened unopened saves and what matters now.'
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

class _DailyMemorySection extends StatelessWidget {
  const _DailyMemorySection({
    required this.memories,
    required this.onOpen,
    required this.onSnooze,
    required this.onLessLikeThis,
  });

  final List<RediscoverMemory> memories;
  final void Function(RediscoverMemory, int) onOpen;
  final void Function(RediscoverMemory, int) onSnooze;
  final void Function(RediscoverMemory, int) onLessLikeThis;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(
          child: _SectionHeader(
            title: 'Today',
            subtitle: 'A stable set for today — no endless feed.',
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final memory = memories[index];
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                index == 0 ? 8 : 6,
                16,
                index == memories.length - 1 ? 12 : 6,
              ),
              child: _DailyMemoryCard(
                memory: memory,
                primary: index == 0,
                onOpen: () => onOpen(memory, index),
                onSnooze: () => onSnooze(memory, index),
                onLessLikeThis: () => onLessLikeThis(memory, index),
              ),
            );
          }, childCount: memories.length),
        ),
      ],
    );
  }
}

enum _MemoryMenuAction { snooze, lessLikeThis }

class _DailyMemoryCard extends StatelessWidget {
  const _DailyMemoryCard({
    required this.memory,
    required this.primary,
    required this.onOpen,
    required this.onSnooze,
    required this.onLessLikeThis,
  });

  final RediscoverMemory memory;
  final bool primary;
  final VoidCallback onOpen;
  final VoidCallback onSnooze;
  final VoidCallback onLessLikeThis;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        RediscoverArtworkCard(
          journey: memory.journey,
          title: memory.rediscoverCopy.title,
          supportingText: memory.copyIdentity.reasonForToday,
          metadata: _metadata(memory),
          height: primary ? 220 : 182,
          onTap: onOpen,
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: cs.surface.withValues(alpha: 0.82),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: PopupMenuButton<_MemoryMenuAction>(
              tooltip: 'Rediscover options',
              icon: Icon(Icons.more_horiz_rounded, color: cs.onSurface),
              onSelected: (action) {
                switch (action) {
                  case _MemoryMenuAction.snooze:
                    onSnooze();
                  case _MemoryMenuAction.lessLikeThis:
                    onLessLikeThis();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _MemoryMenuAction.snooze,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.schedule_rounded),
                    title: Text('Not now'),
                    subtitle: Text('Hide for 7 days'),
                  ),
                ),
                PopupMenuItem(
                  value: _MemoryMenuAction.lessLikeThis,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.thumb_down_alt_outlined),
                    title: Text('Less like this'),
                    subtitle: Text('Reduce similar topics'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _metadata(RediscoverMemory memory) {
    final queued = memory.journey.items.any((item) => item.url.isQueued);
    if (queued) {
      return 'Queued · ${memory.saveCount} ${_saveWord(memory.saveCount)}';
    }
    if (memory.journey.kind == RediscoverJourneyKind.forgottenGems) {
      return 'Forgotten gem · ${memory.saveCount} ${_saveWord(memory.saveCount)}';
    }
    if (memory.journey.kind == RediscoverJourneyKind.returningTopic) {
      return 'Back in view · ${memory.saveCount} ${_saveWord(memory.saveCount)}';
    }
    if (memory.journey.kind == RediscoverJourneyKind.onThisDay) {
      return 'From your past · ${memory.saveCount} ${_saveWord(memory.saveCount)}';
    }
    return '${memory.saveCount} ${_saveWord(memory.saveCount)} · ${memory.waitingLabel}';
  }

  String _saveWord(int count) => count == 1 ? 'save' : 'saves';
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: tt.titleMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecapSection extends StatelessWidget {
  const _RecapSection({required this.recaps, required this.onOpen});

  final List<RediscoverRecap> recaps;
  final ValueChanged<RediscoverRecap> onOpen;

  @override
  Widget build(BuildContext context) {
    if (recaps.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(
          child: _SectionHeader(
            title: 'Recaps',
            subtitle: 'Weekly and monthly patterns from your own saves.',
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final recap = recaps[index];
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                index == 0 ? 8 : 6,
                16,
                index == recaps.length - 1 ? 8 : 6,
              ),
              child: _RecapCard(recap: recap, onTap: () => onOpen(recap)),
            );
          }, childCount: recaps.length),
        ),
      ],
    );
  }
}

class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.recap, required this.onTap});

  final RediscoverRecap recap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final label = switch (recap.cadence) {
      RediscoverRecapCadence.daily => 'Daily recap',
      RediscoverRecapCadence.weekly => 'Weekly recap',
      RediscoverRecapCadence.monthly => 'Monthly recap',
    };
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 15),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      recap.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.editorial(
                        tt.titleMedium,
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${recap.subtitle} · ${recap.items.length} saves',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoMemoriesToday extends StatelessWidget {
  const _NoMemoriesToday();

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
            AppIcon(AppIcons.rediscover, color: cs.onSurfaceVariant, size: 28),
            const SizedBox(height: 12),
            Text(
              'Nothing strong enough today',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              'Rediscover will stay quiet until a save is genuinely worth bringing back.',
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

class _DailySetSkeleton extends StatelessWidget {
  const _DailySetSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}
