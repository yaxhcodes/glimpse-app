import 'package:flutter/material.dart';

import '../../shared/widgets/expressive_tap_scale.dart';
import 'cluster_pattern.dart';

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

/// Height of a medium cluster tile. Exposed so the masonry layout in
/// [InterestMapView] can estimate column heights with the exact same value the
/// card renders at — keeping the staggered Pinterest layout aligned.
double mediumClusterTileHeight(InterestCluster cluster) {
  if (cluster.saveCount >= 13) return 200;
  if (cluster.saveCount >= 7) return 184;
  return 168;
}

/// A quiet tone drawn from the Material palette — gives each card a faint,
/// cohesive identity without any custom/“flashy” colour.
Color _toneFor(ColorScheme cs, InterestCluster cluster) {
  final palette = [cs.primary, cs.secondary, cs.tertiary];
  return palette[cluster.id.hashCode.abs() % palette.length];
}

const _heroPatternSafeRegion = PatternSafeRegion(
  left: 0.04,
  top: 0.38,
  right: 0.94,
  bottom: 1,
);
const _mediumPatternSafeRegion = PatternSafeRegion(
  left: 0.06,
  top: 0.32,
  right: 0.96,
  bottom: 1,
);

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
    final tt = Theme.of(context).textTheme;

    final Widget tile;
    switch (tier) {
      case ClusterCardTier.hero:
        tile = _InterestTile(
          cluster: cluster,
          onTap: onTap,
          height: 176,
          radius: 24,
          titleStyle: tt.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            height: 1.12,
          ),
          chipLimit: 2,
          isHero: true,
        );
      case ClusterCardTier.medium:
        final height = mediumClusterTileHeight(cluster);
        tile = _InterestTile(
          cluster: cluster,
          onTap: onTap,
          height: height,
          radius: 20,
          titleStyle: tt.titleSmall?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            height: 1.2,
          ),
          chipLimit: 2,
          isHero: false,
        );
      case ClusterCardTier.slim:
        tile = _SlimTile(cluster: cluster, onTap: onTap);
    }
    return ExpressiveTapScale(child: tile);
  }
}

class _InterestTile extends StatelessWidget {
  const _InterestTile({
    required this.cluster,
    required this.onTap,
    required this.height,
    required this.radius,
    required this.titleStyle,
    required this.chipLimit,
    required this.isHero,
  });

  final InterestCluster cluster;
  final VoidCallback onTap;
  final double height;
  final double radius;
  final TextStyle? titleStyle;
  final int chipLimit;
  final bool isHero;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final tone = _toneFor(cs, cluster);
    final isLight = cs.brightness == Brightness.light;
    final pattern = resolveClusterPattern(
      label: cluster.label,
      subtopics: cluster.subtopics,
    );
    final patternOpacity = isHero
        ? (isLight ? 0.092 : 0.102)
        : (isLight ? 0.066 : 0.072);
    final tintOpacity = isHero
        ? (isLight ? 0.04 : 0.055)
        : (isLight ? 0.02 : 0.03);
    final useCompactVerticalRhythm =
        !isHero && MediaQuery.textScalerOf(context).scale(1) > 1.15;
    final subtopics = cluster.subtopics.take(chipLimit).toList();
    final surface = cs.surfaceContainerLow;

    return Semantics(
      button: true,
      label: '${cluster.label}, ${cluster.saveCount} saves',
      child: Material(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: cs.primary.withValues(alpha: 0.07),
          highlightColor: cs.primary.withValues(alpha: 0.04),
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Color.alphaBlend(
                          tone.withValues(alpha: tintOpacity),
                          surface,
                        ),
                        surface,
                        surface,
                      ],
                      stops: const [0, 0.58, 1],
                    ),
                  ),
                ),
                // A subtle full-bleed texture that hints at the topic, fading
                // out before the text.
                Positioned.fill(
                  child: CustomPaint(
                    painter: ClusterPatternPainter(
                      selection: pattern,
                      tone: tone,
                      surface: surface,
                      baseOpacity: patternOpacity,
                      contentSafeRegion: isHero
                          ? _heroPatternSafeRegion
                          : _mediumPatternSafeRegion,
                    ),
                  ),
                ),
                Padding(
                  padding: isHero
                      ? const EdgeInsets.fromLTRB(20, 18, 20, 18)
                      : useCompactVerticalRhythm
                      ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
                      : const EdgeInsets.fromLTRB(16, 16, 16, 17),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      Text(
                        cluster.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle?.copyWith(color: cs.onSurface),
                      ),
                      SizedBox(height: useCompactVerticalRhythm ? 3 : 5),
                      Text(
                        _saveText(cluster.saveCount),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      if (subtopics.isNotEmpty) ...[
                        SizedBox(height: useCompactVerticalRhythm ? 7 : 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final subtopic in subtopics)
                              _TileChip(label: subtopic),
                          ],
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
    );
  }
}

class _SlimTile extends StatelessWidget {
  const _SlimTile({required this.cluster, required this.onTap});

  final InterestCluster cluster;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final subtopicText = cluster.subtopics.take(2).join(' · ');

    return Semantics(
      button: true,
      label: '${cluster.label}, ${cluster.saveCount} saves',
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: cs.primary.withValues(alpha: 0.07),
          highlightColor: cs.primary.withValues(alpha: 0.04),
          child: SizedBox(
            height: 68,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Single, monochrome glyph — restrained, not a colour swatch.
                  Icon(
                    _iconForCluster(cluster),
                    size: 22,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cluster.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleSmall?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            _saveText(cluster.saveCount),
                            if (subtopicText.isNotEmpty) subtopicText,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(
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
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chips & badge — built on the app's canonical chip colours.
// ─────────────────────────────────────────────────────────────────────────────

class _TileChip extends StatelessWidget {
  const _TileChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isLight = cs.brightness == Brightness.light;
    final background = cs.onSurfaceVariant.withValues(
      alpha: isLight ? 0.075 : 0.11,
    );
    final foreground = cs.onSurfaceVariant.withValues(
      alpha: isLight ? 0.78 : 0.82,
    );
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 152),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(100),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: tt.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w500,
                fontSize: 10.5,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category → icon (used only by the slim rows)
// ─────────────────────────────────────────────────────────────────────────────

IconData _iconForCluster(InterestCluster cluster) {
  final lower = [cluster.label, ...cluster.subtopics].join(' ').toLowerCase();

  if (_hasAny(lower, ['trek', 'route', 'mountain', 'himalayan'])) {
    return Icons.terrain_rounded;
  }
  if (_hasAny(lower, ['typography', 'font'])) return Icons.text_fields_rounded;
  if (_hasAny(lower, ['design system', 'ui tool', 'pattern', 'design'])) {
    return Icons.grid_view_rounded;
  }
  if (_hasAny(lower, ['ai', 'agent', 'llm', 'prompt', 'claude', 'openai'])) {
    return Icons.account_tree_rounded;
  }
  if (_hasAny(lower, ['seo', 'website', 'search console', 'growth'])) {
    return Icons.trending_up_rounded;
  }
  if (_hasAny(lower, ['github', 'oss', 'code', 'software', 'react', 'next'])) {
    return Icons.code_rounded;
  }
  if (_hasAny(lower, ['startup', 'founder', 'users'])) {
    return Icons.rocket_launch_rounded;
  }
  if (_hasAny(lower, ['farm', 'agri'])) return Icons.eco_rounded;
  if (_hasAny(lower, ['social', 'instagram', 'reddit', 'x.com'])) {
    return Icons.groups_rounded;
  }
  if (_hasAny(lower, ['book', 'essay', 'read'])) return Icons.menu_book_rounded;
  if (_hasAny(lower, ['finance', 'market'])) return Icons.show_chart_rounded;
  if (_hasAny(lower, ['learn', 'course', 'engineering'])) {
    return Icons.school_rounded;
  }
  if (_hasAny(lower, ['game'])) return Icons.extension_rounded;
  if (_hasAny(lower, ['travel', 'destination'])) return Icons.map_rounded;
  if (_hasAny(lower, ['philosophy', 'self-improvement', 'development'])) {
    return Icons.psychology_rounded;
  }
  if (_hasAny(lower, ['bike', 'motorcycle', 'vehicle'])) {
    return Icons.two_wheeler_rounded;
  }
  if (_hasAny(lower, ['document', 'office', 'productivity'])) {
    return Icons.description_rounded;
  }
  return Icons.category_rounded;
}

bool _hasAny(String text, List<String> needles) {
  return needles.any(text.contains);
}

String _saveText(int count) => count == 1 ? '1 save' : '$count saves';
