import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import 'glimpse_activity_provider.dart';
import 'glimpse_past_reviews.dart';
import 'glimpse_period_overview.dart';
import 'glimpse_service.dart';
import 'glimpse_weekly_review.dart';
import 'glimpse_weekly_settings.dart';

class GlimpseHistoryScreen extends ConsumerStatefulWidget {
  const GlimpseHistoryScreen({super.key});
  @override
  ConsumerState<GlimpseHistoryScreen> createState() =>
      _GlimpseHistoryScreenState();
}

class _GlimpseHistoryScreenState extends ConsumerState<GlimpseHistoryScreen>
    with WidgetsBindingObserver {
  int _monthOffset = 0;

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
    ref.invalidate(glimpsesProvider);
    ref.invalidate(glimpseSourcesProvider);
    ref.invalidate(glimpseActivityProvider);
    await Future.wait([
      ref.read(glimpsesProvider.future),
      ref.read(glimpseActivityProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(glimpsesProvider);
    final activity = ref.watch(glimpseActivityProvider);
    final a = activity.valueOrNull;
    final now = a?.now ?? DateTime.now();
    final month = DateTime(now.year, now.month - _monthOffset);
    final earliest = a?.sources.lastOrNull?.savedAt ?? now;
    final oldestOffset =
        (now.year - earliest.year) * 12 + now.month - earliest.month;
    final l = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.glimpsesTitle),
        actions: [
          IconButton(
            onPressed: () => showWeeklyReviewSettings(context, ref),
            tooltip: l.glimpsesReviewSettings,
            icon: const Icon(AppIcons.settings),
          ),
          IconButton(
            onPressed: () => context.push('/notifications'),
            tooltip: l.notifications,
            icon: const Icon(AppIcons.notifications),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          children: [
            Text(
              l.glimpsesIntro,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    MaterialLocalizations.of(context).formatMonthYear(month),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: l.glimpsesPreviousMonth,
                  onPressed: _monthOffset < oldestOffset
                      ? () => setState(() => _monthOffset++)
                      : null,
                  icon: const Icon(AppIcons.arrowBack, size: 18),
                ),
                IconButton(
                  tooltip: l.glimpsesNextMonth,
                  onPressed: _monthOffset > 0
                      ? () => setState(() => _monthOffset--)
                      : null,
                  icon: const Icon(AppIcons.arrowForward, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 20),
            activity.when(
              skipLoadingOnReload: true,
              data: (a) => GlimpsePeriodOverview(
                period: a.month(month),
                now: a.now,
                showChart: true,
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => TextButton(
                onPressed: () => ref.invalidate(glimpseActivityProvider),
                child: Text(l.retry),
              ),
            ),
            state.when(
              skipLoadingOnReload: true,
              data: (all) => GlimpsePastReviews(
                reviews: weeklyReviewsInMonth(all, month),
                all: all,
                urls: ref.watch(glimpseSourcesProvider).valueOrNull ?? {},
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => TextButton(
                onPressed: () => ref.invalidate(glimpsesProvider),
                child: Text(l.retry),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
