import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shared/widgets/expressive_tap_scale.dart';
import '../../shared/widgets/tag_group.dart' show tagChipColors;

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
  double height;
  final saves = cluster.saveCount;
  if (saves >= 24) {
    height = 206;
  } else if (saves >= 18) {
    height = 194;
  } else if (saves >= 13) {
    height = 182;
  } else if (saves >= 9) {
    height = 170;
  } else if (saves >= 6) {
    height = 160;
  } else {
    height = 150;
  }
  // A second chip row needs a little more room — and adds organic variation.
  if (cluster.subtopics.length >= 2) height += 8;
  return height;
}

/// A quiet tone drawn from the Material palette — gives each card a faint,
/// cohesive identity without any custom/“flashy” colour.
Color _toneFor(ColorScheme cs, InterestCluster cluster) {
  final palette = [cs.primary, cs.secondary, cs.tertiary];
  return palette[cluster.id.hashCode.abs() % palette.length];
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
    final tt = Theme.of(context).textTheme;

    final Widget tile;
    switch (tier) {
      case ClusterCardTier.hero:
        tile = _InterestTile(
          cluster: cluster,
          onTap: onTap,
          height: 196,
          radius: 24,
          titleStyle: tt.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            height: 1.04,
          ),
          chipLimit: 3,
          isHero: true,
        );
      case ClusterCardTier.medium:
        final height = mediumClusterTileHeight(cluster);
        tile = _InterestTile(
          cluster: cluster,
          onTap: onTap,
          height: height,
          radius: 22,
          titleStyle: tt.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            fontSize: height >= 182 ? 20 : 18,
            height: 1.1,
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
    // Full-bleed texture: subtle, but light surfaces need a touch more.
    final isLight = cs.brightness == Brightness.light;
    final patternAlpha = isLight ? 0.13 : 0.10;
    final subtopics = cluster.subtopics.take(chipLimit).toList();
    final titleLines = isHero ? 2 : (height >= 170 ? 2 : 1);

    return Semantics(
      button: true,
      label: '${cluster.label}, ${cluster.saveCount} saves',
      child: Material(
        // Plain app surface — same as the Collections grid cards.
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(radius),
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
                // A subtle full-bleed texture that hints at the topic, fading
                // out before the text.
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TexturePainter(
                      kind: _textureFor(cluster),
                      tone: tone,
                      surface: cs.surfaceContainerLow,
                      alpha: patternAlpha,
                    ),
                  ),
                ),
                Padding(
                  padding: isHero
                      ? const EdgeInsets.fromLTRB(18, 16, 18, 17)
                      : const EdgeInsets.fromLTRB(15, 14, 15, 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isHero) _DominantBadge(tone: tone),
                      const Spacer(),
                      Text(
                        cluster.label,
                        maxLines: titleLines,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle?.copyWith(color: cs.onSurface),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isHero
                            ? '${_saveText(cluster.saveCount)} · strongest pattern'
                            : _saveText(cluster.saveCount),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (subtopics.isNotEmpty) ...[
                        const SizedBox(height: 10),
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
// Texture — a fine, full-bleed pattern that hints at the card's topic. Not a
// spot illustration (those read as hand-drawn) but a precise repeating texture:
// contour lines for terrain, a lattice for networks, rising bars for growth…
// All share one monochrome Material tone and weight; only the geometry differs.
// A surface gradient fades the lower half so the title/chips stay clean.
// ─────────────────────────────────────────────────────────────────────────────

enum _TextureKind { contour, lattice, grid, bars, ruled, wave, dots }

/// Match on the **label first**, then subtopics — so a stray subtopic (e.g. a
/// "Food & Cooking" tag on a Dev Tools card) can't hijack the texture.
_TextureKind _textureFor(InterestCluster cluster) {
  return _matchTexture(cluster.label.toLowerCase()) ??
      _matchTexture(cluster.subtopics.join(' ').toLowerCase()) ??
      _TextureKind.dots;
}

_TextureKind? _matchTexture(String l) {
  if (_hasAny(l, [
    'trek',
    'hike',
    'trail',
    'mountain',
    'valley',
    'summit',
    'climb',
    'outdoor',
    'camp',
    'alpine',
    'travel',
    'trip',
    'destination',
    'nature',
    'farm',
    'agri',
    'garden',
    'eco',
  ])) {
    return _TextureKind.contour;
  }
  if (_hasAny(l, [
    'agent',
    'llm',
    'gpt',
    'neural',
    'machine learning',
    'prompt',
    'automation',
    'workflow',
    'graph',
    'network',
    'social',
    'community',
    'people',
  ])) {
    return _TextureKind.lattice;
  }
  if (_hasAny(l, [
    'dev',
    'code',
    'coding',
    'software',
    'oss',
    'github',
    'sdk',
    'framework',
    'library',
    'backend',
    'frontend',
    'engineering',
    'tool',
    'programming',
    'design',
    'figma',
    'layout',
    'component',
    'typography',
    'font',
    'productivity',
    'document',
    'game',
    'pixel',
  ])) {
    return _TextureKind.grid;
  }
  if (_hasAny(l, [
    'seo',
    'website',
    'growth',
    'traffic',
    'analytics',
    'audience',
    'conversion',
    'marketing',
    'startup',
    'launch',
    'founder',
    'build',
    'venture',
    'finance',
    'money',
    'crypto',
    'invest',
    'market',
    'stock',
    'revenue',
    'sales',
  ])) {
    return _TextureKind.bars;
  }
  if (_hasAny(l, [
    'book',
    'read',
    'essay',
    'article',
    'news',
    'blog',
    'writing',
    'paper',
    'study',
    'journal',
    'learn',
    'course',
  ])) {
    return _TextureKind.ruled;
  }
  if (_hasAny(l, [
    'music',
    'song',
    'playlist',
    'audio',
    'track',
    'album',
    'sound',
    'podcast',
  ])) {
    return _TextureKind.wave;
  }
  return null;
}

class _TexturePainter extends CustomPainter {
  const _TexturePainter({
    required this.kind,
    required this.tone,
    required this.surface,
    required this.alpha,
  });

  final _TextureKind kind;
  final Color tone;
  final Color surface;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = tone.withValues(alpha: alpha);
    final connector = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = tone.withValues(alpha: alpha * 0.55);
    final dot = Paint()..color = tone.withValues(alpha: alpha);
    final solid = Paint()..color = tone.withValues(alpha: alpha * 0.9);

    switch (kind) {
      case _TextureKind.contour:
        _contour(canvas, size, stroke);
      case _TextureKind.lattice:
        _lattice(canvas, size, connector, dot);
      case _TextureKind.grid:
        _grid(canvas, size, connector);
      case _TextureKind.bars:
        _bars(canvas, size, solid);
      case _TextureKind.ruled:
        _ruled(canvas, size, stroke);
      case _TextureKind.wave:
        _wave(canvas, size, solid);
      case _TextureKind.dots:
        _dots(canvas, size, dot);
    }

    // Fade the texture into the surface so the lower half stays clean.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [surface.withValues(alpha: 0.0), surface],
          stops: const [0.40, 0.82],
        ).createShader(Offset.zero & size),
    );
  }

  // Topographic contour lines — flowing parallel curves (terrain / nature).
  void _contour(Canvas canvas, Size size, Paint p) {
    final w = size.width, h = size.height;
    for (var i = 0; i < 6; i++) {
      final yb = h * (0.08 + i * 0.11);
      final path = Path()..moveTo(0, yb);
      for (var x = 0.0; x <= w; x += w / 32) {
        path.lineTo(
          x,
          yb + math.sin(x / w * math.pi * 2 + i * 0.8) * h * 0.045,
        );
      }
      canvas.drawPath(path, p);
    }
  }

  // Node lattice — a dot grid with faint connectors (networks / AI).
  void _lattice(Canvas canvas, Size size, Paint connector, Paint dot) {
    const gap = 26.0;
    final cols = (size.width / gap).ceil();
    final rows = (size.height / gap).ceil();
    for (var r = 0; r <= rows; r++) {
      for (var c = 0; c <= cols; c++) {
        final p = Offset(c * gap + 6, r * gap + 6);
        if (c < cols) canvas.drawLine(p, Offset(p.dx + gap, p.dy), connector);
        if (r < rows) canvas.drawLine(p, Offset(p.dx, p.dy + gap), connector);
        canvas.drawCircle(p, 1.5, dot);
      }
    }
  }

  // Fine modular grid (code / design / structured topics).
  void _grid(Canvas canvas, Size size, Paint p) {
    const gap = 22.0;
    for (var x = gap; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = gap; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  // Rising bars (growth / finance / startup).
  void _bars(Canvas canvas, Size size, Paint p) {
    final w = size.width, h = size.height;
    const gap = 16.0;
    final n = (w / gap).floor();
    final baseline = h * 0.52;
    for (var i = 0; i < n; i++) {
      final frac = n <= 1 ? 1.0 : i / (n - 1);
      final bh = h * (0.08 + 0.30 * frac) * (0.85 + 0.15 * math.sin(i * 0.9));
      final x = gap * i + gap * 0.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 2.5, baseline - bh, 5, bh),
          const Radius.circular(2),
        ),
        p,
      );
    }
  }

  // Ruled text lines (reading / writing).
  void _ruled(Canvas canvas, Size size, Paint p) {
    const gap = 15.0;
    for (var y = gap; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  // Equalizer bars (music / audio).
  void _wave(Canvas canvas, Size size, Paint p) {
    final w = size.width, h = size.height;
    const gap = 14.0;
    final n = (w / gap).floor();
    final mid = h * 0.30;
    for (var i = 0; i < n; i++) {
      final bh = h * (0.06 + 0.16 * (0.5 + 0.5 * math.sin(i * 1.1)));
      final x = gap * i + gap * 0.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 2, mid - bh, 4, bh * 2),
          const Radius.circular(2),
        ),
        p,
      );
    }
  }

  // Soft dot field (fallback / general).
  void _dots(Canvas canvas, Size size, Paint p) {
    for (var y = 14.0; y < size.height; y += 14) {
      for (var x = 14.0; x < size.width; x += 14) {
        canvas.drawCircle(Offset(x, y), 1.3, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TexturePainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.tone != tone ||
        oldDelegate.surface != surface ||
        oldDelegate.alpha != alpha;
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
    final chip = tagChipColors(cs);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 152),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: chip.background,
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
              color: chip.foreground,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

class _DominantBadge extends StatelessWidget {
  const _DominantBadge({required this.tone});

  final Color tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 4, 11, 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: tone),
          ),
          const SizedBox(width: 7),
          Text(
            'Dominant interest',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
