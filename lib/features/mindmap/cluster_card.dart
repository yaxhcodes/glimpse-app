import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../shared/widgets/expressive_tap_scale.dart';
import 'cluster_pattern.dart';
import '../../shared/theme/topic_visual.dart';
import '../../shared/widgets/topic_emblem.dart';
import '../../shared/widgets/surface_grain.dart';

class InterestCluster {
  const InterestCluster({
    required this.id,
    required this.label,
    required this.saveCount,
    required this.subtopics,
    required this.dominance,
    required this.coverImageUrl,
    required this.accentColor,
  });

  final String id;
  final String label;
  final int saveCount;
  final List<String> subtopics;
  final double dominance;
  final String? coverImageUrl;
  final Color? accentColor;
}

enum ClusterCardTier { hero, medium, slim }

double mediumClusterTileHeight(InterestCluster cluster) {
  if (cluster.saveCount >= 13) return 208;
  if (cluster.saveCount >= 7) return 196;
  return 184;
}

TopicVisual visualForInterest(InterestCluster cluster) {
  final pattern = resolveClusterPattern(
    label: cluster.label,
    subtopics: cluster.subtopics,
  );
  return TopicVisual.forCategory(pattern.categoryIds.first);
}

class ClusterCard extends StatelessWidget {
  const ClusterCard({
    super.key,
    required this.cluster,
    required this.tier,
    required this.onTap,
  });

  final InterestCluster cluster;
  final ClusterCardTier tier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final visual = visualForInterest(cluster);
    final isHero = tier == ClusterCardTier.hero;
    final isSlim = tier == ClusterCardTier.slim;
    final subtopics = cluster.subtopics.take(2).join(' · ');
    final count = context.l10n.saveCount(cluster.saveCount);
    final titleSize = isHero ? 22.0 : 16.0;
    final minHeight = isHero ? 192.0 : mediumClusterTileHeight(cluster);

    return Semantics(
      button: true,
      onTap: onTap,
      label:
          '${cluster.label}, $count${subtopics.isEmpty ? '' : ', $subtopics'}',
      excludeSemantics: true,
      child: ExpressiveTapScale(
        child: Material(
          color: isHero
              ? visual.cardSurface(cs, opacity: .45)
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(isSlim ? 20 : 24),
          clipBehavior: Clip.antiAlias,
          child: SurfaceGrain(
            strength: .8,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.all(isHero ? 0 : 16),
                child: isSlim
                    ? Row(
                        children: [
                          TopicEmblem(visual: visual, size: 40),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cluster.label,
                                  style: theme.textTheme.titleSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    count,
                                    if (subtopics.isNotEmpty) subtopics,
                                  ].join(' · '),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: cs.onSurfaceVariant,
                          ),
                        ],
                      )
                    : isHero
                    ? _HeroInterestContent(
                        cluster: cluster,
                        visual: visual,
                        count: count,
                        subtopics: subtopics,
                        theme: theme,
                        colorScheme: cs,
                      )
                    : ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: minHeight - (isHero ? 40 : 32),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                TopicEmblem(
                                  visual: visual,
                                  size: isHero ? 48 : 40,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    count,
                                    textAlign: TextAlign.end,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cluster.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontSize: titleSize,
                                      fontWeight: isHero
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      height: 1.2,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  if (subtopics.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      subtopics,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontSize: 12,
                                            height: 1.3,
                                            color: cs.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroInterestContent extends StatelessWidget {
  const _HeroInterestContent({
    required this.cluster,
    required this.visual,
    required this.count,
    required this.subtopics,
    required this.theme,
    required this.colorScheme,
  });

  final InterestCluster cluster;
  final TopicVisual visual;
  final String count;
  final String subtopics;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final artworkWidth = constraints.maxWidth * .33;
      return Stack(
        children: [
          Positioned(
            right: -4,
            top: 62,
            bottom: -40,
            width: artworkWidth,
            child: const IgnorePointer(child: TopSignalArtwork()),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 200),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TopicEmblem(visual: visual, size: 48),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Text(
                                count,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 24, right: artworkWidth - 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cluster.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (subtopics.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            subtopics,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              height: 1.3,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Background-free decoration, sized by the hero's reserved right third.
class TopSignalArtwork extends StatelessWidget {
  const TopSignalArtwork({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      'assets/interests/top_signal_cutout.png',
      fit: BoxFit.contain,
      alignment: Alignment.bottomRight,
      cacheWidth:
          (MediaQuery.sizeOf(context).width *
                  .33 *
                  MediaQuery.devicePixelRatioOf(context))
              .ceil()
              .clamp(1, 768),
      excludeFromSemantics: true,
      filterQuality: FilterQuality.medium,
    ),
  );
}
