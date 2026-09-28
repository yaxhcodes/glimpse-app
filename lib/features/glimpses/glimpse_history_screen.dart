import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../core/services/app_haptics.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import 'glimpse_activity_provider.dart';
import 'glimpse_page_frame.dart';
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
    VoidCallback? stepMonth(int delta, bool allowed) => allowed
        ? () {
            AppHaptics.play(AppHaptics.tick);
            setState(() => _monthOffset += delta);
          }
        : null;
    return GlimpsePageFrame(
      title: l.glimpsesTitle,
      subtitle: l.glimpsesIntro,
      onRefresh: _refresh,
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
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  MaterialLocalizations.of(context).formatMonthYear(month),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.3,
                  ),
                ),
              ),
              IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                tooltip: l.glimpsesPreviousMonth,
                onPressed: stepMonth(1, _monthOffset < oldestOffset),
                icon: const Icon(AppIcons.arrowBack, size: 16),
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                tooltip: l.glimpsesNextMonth,
                onPressed: stepMonth(-1, _monthOffset > 0),
                icon: const Icon(AppIcons.arrowForward, size: 18),
              ),
            ],
          ),
        ),
        activity.when(
          skipLoadingOnReload: true,
          data: (a) => GlimpsePeriodOverview(
            period: a.month(month),
            now: a.now,
            showChart: true,
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: ExpressiveLoadingIndicator()),
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
    );
  }
}
