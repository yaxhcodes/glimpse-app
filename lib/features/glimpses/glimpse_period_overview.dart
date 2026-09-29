import 'package:flutter/material.dart';

import '../../core/services/app_haptics.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import '../rediscover/journey_visual.dart';
import 'glimpse_activity.dart';
import 'glimpse_activity_chart.dart';
import 'glimpse_copy.dart';
import 'glimpse_page_frame.dart';
import 'glimpse_source_sheet.dart';

RediscoverArtworkTheme glimpseTopicArtwork(String? key) => switch (key) {
  'recipes' => RediscoverArtworkTheme.food,
  'anime_manga' || 'movies_watchlist' => RediscoverArtworkTheme.film,
  'music' => RediscoverArtworkTheme.music,
  'fitness' => RediscoverArtworkTheme.fitness,
  'wildlife_nature' => RediscoverArtworkTheme.nature,
  'travel_places' || 'motorcycles' => RediscoverArtworkTheme.travel,
  'books_reading' => RediscoverArtworkTheme.books,
  'spirituality' || 'personal_growth' => RediscoverArtworkTheme.philosophy,
  'history_society' => RediscoverArtworkTheme.history,
  'finance_economics' => RediscoverArtworkTheme.finance,
  'design_creativity' => RediscoverArtworkTheme.design,
  'software_ai' => RediscoverArtworkTheme.software,
  'science' => RediscoverArtworkTheme.science,
  _ => RediscoverArtworkTheme.general,
};

/// A period at a glance: how much was saved (with the day-by-day chart on
/// one card), then the topics it went to.
class GlimpsePeriodOverview extends StatelessWidget {
  const GlimpsePeriodOverview({
    super.key,
    required this.period,
    required this.now,
    this.showChart = false,
  });
  final GlimpsePeriod period;
  final DateTime now;
  final bool showChart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = context.l10n;
    if (period.sources.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            const RediscoverIllustration(
              artwork: RediscoverArtworkTheme.general,
              size: 72,
            ),
            const SizedBox(height: 16),
            Text(
              l.glimpsesNoSavesPeriod,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    final topics = period.topics.take(5).toList(growable: false);
    final topCount = topics.isEmpty ? 1 : topics.first.sourceIds.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    l.saveCount(period.sources.length),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      letterSpacing: -0.4,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      AppHaptics.play(AppHaptics.tap);
                      showGlimpseSources(
                        context,
                        title: MaterialLocalizations.of(
                          context,
                        ).formatMonthYear(period.start),
                        subtitle: l.saveCount(period.sources.length),
                        sources: period.sources,
                      );
                    },
                    icon: const Icon(AppIcons.arrowForward, size: 16),
                    iconAlignment: IconAlignment.end,
                    label: Text(l.glimpsesBrowsePeriod),
                  ),
                ],
              ),
              if (showChart) ...[
                const SizedBox(height: 18),
                GlimpseActivityChart(period: period, now: now),
              ],
            ],
          ),
        ),
        if (topics.isNotEmpty) ...[
          GlimpseSectionTitle(l.glimpsesTopTopics),
          GlimpseGroupedList(
            children: [
              for (final topic in topics)
                _TopicRow(topic: topic, period: period, topCount: topCount),
            ],
          ),
        ],
      ],
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.topic,
    required this.period,
    required this.topCount,
  });
  final GlimpseTopic topic;
  final GlimpsePeriod period;

  /// The leading topic's count: bars are measured against it, so the top
  /// topic fills its track and the rest read as shares of it.
  final int topCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = context.l10n;
    final label = glimpseTopicLabel(topic.subject.key, l);
    final count = topic.sourceIds.length;
    return InkWell(
      onTap: () {
        AppHaptics.play(AppHaptics.tap);
        showGlimpseSources(
          context,
          title: label,
          sources: period.sources
              .where((u) => topic.sourceIds.contains(u.id))
              .toList(),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            ExcludeSemantics(
              child: RediscoverIllustration(
                artwork: glimpseTopicArtwork(topic.subject.key),
                size: 40,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.saveCount(count),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ExcludeSemantics(
                    child: LinearProgressIndicator(
                      value: count / topCount,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(4),
                      color: cs.primary.withValues(alpha: .75),
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
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
