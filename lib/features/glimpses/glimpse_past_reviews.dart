import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/saved_url.dart';
import '../../core/services/app_haptics.dart';
import '../../core/services/title_resolver.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import 'glimpse.dart';
import 'glimpse_page_frame.dart';
import 'glimpse_store.dart';
import 'glimpse_weekly_review.dart';

class GlimpsePastReviews extends StatelessWidget {
  const GlimpsePastReviews({
    super.key,
    required this.reviews,
    required this.all,
    required this.urls,
  });
  final List<StoredGlimpse> reviews;
  final List<StoredGlimpse> all;
  final Map<int, SavedUrl> urls;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlimpseSectionTitle(l.glimpsesWeeklyReview),
        GlimpseGroupedList(
          children: [
            for (final item in reviews)
              GlimpseWeekRow(
                week: item.glimpse,
                preview: _preview(context, item.glimpse),
              ),
          ],
        ),
      ],
    );
  }

  String _preview(BuildContext context, Glimpse week) {
    final l = context.l10n;
    final pick = GlimpseWeeklyReview.build(week, all, urls).start;
    return pick == null
        ? l.glimpsesBrowsePeriod
        : l.glimpsesReviewPreview(TitleResolver.resolveDetailTitle(pick));
  }
}

/// One weekly review: a small calendar leaf for the week's first day, the
/// date range, and where the review starts.
class GlimpseWeekRow extends StatelessWidget {
  const GlimpseWeekRow({
    super.key,
    required this.week,
    required this.preview,
    this.previewLines = 2,
  });

  final Glimpse week;
  final String preview;
  final int previewLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final dates = MaterialLocalizations.of(context);
    final start = week.periodStart ?? week.createdAt;
    final end =
        (week.periodEnd ?? DateTime(start.year, start.month, start.day + 7))
            .subtract(const Duration(days: 1));
    return InkWell(
      onTap: () {
        AppHaptics.play(AppHaptics.tap);
        context.push('/glimpses/detail', extra: week.key);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        child: Row(
          children: [
            _CalendarLeaf(date: start),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${dates.formatShortMonthDay(start)} – '
                    '${dates.formatShortMonthDay(end)}',
                    style: tt.titleSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preview,
                    maxLines: previewLines,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              AppIcons.chevronRight,
              size: 20,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarLeaf extends StatelessWidget {
  const _CalendarLeaf({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    // A fixed-size leaf: the dates are also in the row's title, so the
    // leaf caps text scaling rather than growing.
    return ExcludeSemantics(
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: Container(
          width: 48,
          height: 52,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 16,
                color: cs.primary.withValues(alpha: 0.16),
                alignment: Alignment.center,
                child: Text(
                  DateFormat.MMM(locale).format(date).toUpperCase(),
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    height: 1,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${date.day}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
