import 'dart:async';
import 'dart:math' as math;
import '../onboarding/first_use_guide.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/app_haptics.dart';
import '../../core/services/title_resolver.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import '../../shared/widgets/expressive_tap_scale.dart';
import '../rediscover/journey_visual.dart';
import 'glimpse_activity_provider.dart';
import 'glimpse_open.dart';
import 'glimpse_page_frame.dart';
import 'glimpse_past_reviews.dart';
import 'glimpse_service.dart';
import 'glimpse_tile.dart';
import 'glimpse_synthesis.dart';
import 'glimpse_weekly_review.dart';
import 'glimpse_weekly_preparation.dart';

/// Rediscover: today's few memories first, then this week's review, then the
/// way into Your Glimpses with a glance at the month's saving.
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
    return GlimpsePageFrame(
      title: l.rediscover,
      subtitle: l.rediscoverSubtitle,
      onRefresh: _refresh,
      actions: [
        IconButton(
          onPressed: () => context.push('/notifications'),
          tooltip: l.notifications,
          icon: const Icon(AppIcons.notifications),
        ),
      ],
      children: state.when(
        skipLoadingOnReload: true,
        loading: () => const [
          Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: ExpressiveLoadingIndicator()),
          ),
        ],
        error: (_, _) => [
          Center(
            child: TextButton(onPressed: _refresh, child: Text(l.retry)),
          ),
        ],
        data: (all) {
          final current = GlimpseService.current(all, DateTime.now());
          final weeklyItem = latestWeeklyReview(all, DateTime.now());
          final week = weeklyItem?.glimpse;
          final synthesis = weeklyItem == null
              ? null
              : GlimpseSynthesis.cached(
                  weeklyItem,
                  Localizations.localeOf(context).toLanguageTag(),
                ).firstOrNull?.text;
          final review = week == null
              ? null
              : GlimpseWeeklyReview.build(week, all, urls);
          return [
            if (current.isNotEmpty) ...[
              const FirstUseGuide(kind: FirstUseKind.rediscover),
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
            ] else
              const _NothingToday(),
            if (week != null && review != null) ...[
              GlimpseSectionTitle(l.glimpsesWeeklyReview),
              GlimpseGroupedList(
                children: [
                  GlimpseWeekRow(
                    week: week,
                    previewLines: 3,
                    preview:
                        synthesis ??
                        (review.start == null
                            ? l.glimpsesBrowsePeriod
                            : l.glimpsesReviewPreview(
                                TitleResolver.resolveDetailTitle(review.start!),
                              )),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 28),
            const _YourGlimpsesCard(),
          ];
        },
      ),
    );
  }
}

/// Nothing to bring back today: said calmly, with the house illustration.
class _NothingToday extends StatelessWidget {
  const _NothingToday();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const RediscoverIllustration(
            artwork: RediscoverArtworkTheme.general,
            size: 88,
          ),
          const SizedBox(height: 18),
          Text(
            context.l10n.glimpsesEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// The way into Your Glimpses, showing what's inside: this month's saves as
/// a small day-by-day spark, and the count.
class _YourGlimpsesCard extends ConsumerWidget {
  const _YourGlimpsesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = context.l10n;
    final activity = ref.watch(glimpseActivityProvider).valueOrNull;
    final month = activity?.month(activity.now);
    final counts = month == null
        ? const <int>[]
        : [
            for (var d = 1; d <= activity!.now.day; d++)
              month
                      .days[DateTime(month.start.year, month.start.month, d)]
                      ?.length ??
                  0,
          ];
    final hasSaves = month != null && month.sources.isNotEmpty;

    return ExpressiveTapScale(
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            AppHaptics.play(AppHaptics.tap);
            context.push('/glimpses/history');
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.glimpsesTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l.glimpsesHistorySubtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      AppIcons.chevronRight,
                      size: 20,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ],
                ),
                if (hasSaves) ...[
                  const SizedBox(height: 18),
                  ExcludeSemantics(
                    child: SizedBox(
                      height: 40,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _SparkPainter(
                          counts,
                          DateTime(
                            month.start.year,
                            month.start.month + 1,
                            0,
                          ).day,
                          cs.primary,
                          cs.outlineVariant,
                          Directionality.of(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${MaterialLocalizations.of(context).formatMonthYear(month.start)}'
                    ' · ${l.saveCount(month.sources.length)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// This month so far, one slim bar per day; today in full colour.
class _SparkPainter extends CustomPainter {
  const _SparkPainter(
    this.counts,
    this.daysInMonth,
    this.color,
    this.empty,
    this.direction,
  );

  /// Saves per day from the 1st to today.
  final List<int> counts;

  /// The month's length: the rest of it shows as faint dots still to come.
  final int daysInMonth;
  final Color color;
  final Color empty;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    if (counts.isEmpty) return;
    final maximum = math.max(1, counts.reduce(math.max));
    final slots = math.max(daysInMonth, counts.length);
    final slot = size.width / slots;
    final barWidth = math.min(slot * .6, 8.0);
    final paint = Paint();
    double slotLeft(int i) =>
        (direction == TextDirection.rtl ? slots - i - 1 : i) * slot;
    for (var i = counts.length; i < slots; i++) {
      paint.color = empty.withValues(alpha: .6);
      canvas.drawCircle(
        Offset(slotLeft(i) + slot / 2, size.height - 1.5),
        math.min(1.5, barWidth / 2),
        paint,
      );
    }
    for (var i = 0; i < counts.length; i++) {
      final left = slotLeft(i) + (slot - barWidth) / 2;
      final height = counts[i] == 0
          ? 3.0
          : math.max(6.0, counts[i] / maximum * size.height);
      paint.color = counts[i] == 0
          ? empty.withValues(alpha: .7)
          : color.withValues(alpha: i == counts.length - 1 ? 1 : .4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - height, barWidth, height),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      !listEquals(old.counts, counts) ||
      old.daysInMonth != daysInMonth ||
      old.color != color ||
      old.empty != empty ||
      old.direction != direction;
}
