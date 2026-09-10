import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/saved_url.dart';
import '../../core/services/title_resolver.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
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
    final theme = Theme.of(context);
    final l = context.l10n;
    final dates = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Text(l.glimpsesWeeklyReview, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final item in reviews)
          Builder(
            builder: (context) {
              final g = item.glimpse;
              final start = g.periodStart ?? g.createdAt;
              final end =
                  (g.periodEnd ??
                          DateTime(start.year, start.month, start.day + 7))
                      .subtract(const Duration(days: 1));
              final pick = GlimpseWeeklyReview.build(g, all, urls).start;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Icon(
                      AppIcons.calendar,
                      size: 24,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      '${dates.formatShortMonthDay(start)} – ${dates.formatShortMonthDay(end)}',
                      style: theme.textTheme.titleSmall,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        pick == null
                            ? l.glimpsesBrowsePeriod
                            : l.glimpsesReviewPreview(
                                TitleResolver.resolveDetailTitle(pick),
                              ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    trailing: const Icon(AppIcons.chevronRight, size: 18),
                    onTap: () => context.push('/glimpses/detail', extra: g.key),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
