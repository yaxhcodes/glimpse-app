import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/title_resolver.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import 'glimpse_open.dart';
import 'glimpse_service.dart';
import 'glimpse_tile.dart';
import 'glimpse_synthesis.dart';
import 'glimpse_weekly_review.dart';
import 'glimpse_weekly_preparation.dart';

class GlimpsesScreen extends ConsumerStatefulWidget {
  const GlimpsesScreen({super.key});
  @override
  ConsumerState<GlimpsesScreen> createState() => _GlimpsesScreenState();
}

class _GlimpsesScreenState extends ConsumerState<GlimpsesScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    ref.invalidate(glimpseSourcesProvider);
    ref.invalidate(glimpsesProvider);
    ref.invalidate(prepareWeeklyReviewProvider);
    await ref.read(glimpsesProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(glimpsesProvider);
    final urls = ref.watch(glimpseSourcesProvider).valueOrNull ?? {};
    ref.watch(prepareWeeklyReviewProvider);
    final l = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.rediscover),
        actions: [
          IconButton(
            onPressed: () => context.push('/notifications'),
            tooltip: l.notifications,
            icon: const Icon(AppIcons.notifications),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: state.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ListView(
            children: [TextButton(onPressed: _refresh, child: Text(l.retry))],
          ),
          data: (all) {
            final current = GlimpseService.current(all, DateTime.now());
            final weeklyItem = latestWeeklyReview(all, DateTime.now());
            final week = weeklyItem?.glimpse;
            final preview = weeklyItem == null
                ? null
                : GlimpseSynthesis.cached(
                    weeklyItem,
                    Localizations.localeOf(context).toLanguageTag(),
                  ).firstOrNull?.text;
            final review = week == null
                ? null
                : GlimpseWeeklyReview.build(week, all, urls);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Material(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    title: Text(
                      l.glimpsesTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                    subtitle: Text(l.glimpsesHistorySubtitle),
                    trailing: const Icon(AppIcons.chevronRight, size: 18),
                    onTap: () => context.push('/glimpses/history'),
                  ),
                ),
                const SizedBox(height: 24),
                if (current.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l.glimpsesEmpty),
                  ),
                for (final item in current)
                  GlimpseTile(
                    key: ValueKey(item.glimpse.key),
                    showActions: true,
                    glimpse: item.glimpse,
                    urls: urls,
                    onTap: () => openGlimpse(
                      context,
                      item.glimpse.key,
                      item.glimpse.sourceIds,
                    ),
                  ),
                if (review != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    l.glimpsesWeeklyReview,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Card.outlined(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      title: Text(
                        MaterialLocalizations.of(
                          context,
                        ).formatMediumDate(week!.periodStart ?? week.createdAt),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          preview ??
                              (review.start == null
                                  ? l.glimpsesBrowsePeriod
                                  : l.glimpsesReviewPreview(
                                      TitleResolver.resolveDetailTitle(
                                        review.start!,
                                      ),
                                    )),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: const Icon(AppIcons.chevronRight, size: 18),
                      onTap: () =>
                          context.push('/glimpses/detail', extra: week.key),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
