import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import '../rediscover/journey_visual.dart';
import 'glimpse_activity.dart';
import 'glimpse_activity_chart.dart';
import 'glimpse_copy.dart';
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Icon(AppIcons.bookmark, color: cs.onSurfaceVariant, size: 28),
            const SizedBox(height: 14),
            Text(
              l.glimpsesNoSavesPeriod,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            children: [
              Text(
                l.saveCount(period.sources.length),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.4,
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: AlignmentDirectional.centerStart,
                ),
                onPressed: () => showGlimpseSources(
                  context,
                  title: MaterialLocalizations.of(
                    context,
                  ).formatMonthYear(period.start),
                  subtitle: l.saveCount(period.sources.length),
                  sources: period.sources,
                ),
                icon: const Icon(AppIcons.arrowForward, size: 16),
                iconAlignment: IconAlignment.end,
                label: Text(l.glimpsesBrowsePeriod),
              ),
            ],
          ),
        ),
        if (showChart) ...[
          const SizedBox(height: 20),
          GlimpseActivityChart(period: period, now: now),
        ],
        if (period.topics.isNotEmpty) ...[
          Divider(height: 40, color: cs.outlineVariant.withValues(alpha: .4)),
          Text(l.glimpsesTopTopics, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (index, topic) in period.topics.take(5).indexed) ...[
                  if (index > 0)
                    Divider(
                      height: 1,
                      indent: 4,
                      endIndent: 4,
                      color: cs.outlineVariant.withValues(alpha: .4),
                    ),
                  _TopicRow(topic: topic, period: period, rank: index + 1),
                ],
              ],
            ),
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
    required this.rank,
  });
  final GlimpseTopic topic;
  final GlimpsePeriod period;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = context.l10n;
    return InkWell(
      onTap: () => showGlimpseSources(
        context,
        title: glimpseTopicLabel(topic.subject.key, l),
        sources: period.sources
            .where((u) => topic.sourceIds.contains(u.id))
            .toList(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Text(
                '$rank',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            ExcludeSemantics(
              child: RediscoverIllustration(
                artwork: glimpseTopicArtwork(topic.subject.key),
                size: 36,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    glimpseTopicLabel(topic.subject.key, l),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.saveCount(topic.sourceIds.length),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ExcludeSemantics(
                    child: LinearProgressIndicator(
                      value: topic.sourceIds.length / period.sources.length,
                      minHeight: 2,
                      borderRadius: BorderRadius.circular(4),
                      color: cs.onSurfaceVariant.withValues(alpha: .55),
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(AppIcons.chevronRight, size: 14, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
