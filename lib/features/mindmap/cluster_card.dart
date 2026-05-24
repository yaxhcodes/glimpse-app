import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

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

enum _InterestKind {
  treks,
  designSystems,
  typography,
  aiAgents,
  websiteGrowth,
  devTools,
  startup,
  agriculture,
  social,
  longReads,
  finance,
  learning,
  gaming,
  travel,
  books,
  productivity,
  creative,
  philosophy,
  vehicles,
  general,
}

class _InterestVisualSpec {
  const _InterestVisualSpec(this.kind, this.accent, this.icon);

  final _InterestKind kind;
  final Color accent;
  final IconData icon;
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
    switch (tier) {
      case ClusterCardTier.hero:
        return _PatternTile(
          cluster: cluster,
          onTap: onTap,
          height: 196,
          borderRadius: 28,
          titleStyle: Theme.of(context).textTheme.displaySmall,
          chipLimit: 3,
          showEyebrow: true,
        );
      case ClusterCardTier.medium:
        return _PatternTile(
          cluster: cluster,
          onTap: onTap,
          height: _mediumTileHeight(cluster),
          borderRadius: 22,
          titleStyle: Theme.of(context).textTheme.titleMedium,
          chipLimit: 2,
          showEyebrow: false,
        );
      case ClusterCardTier.slim:
        return _SlimTile(cluster: cluster, onTap: onTap);
    }
  }
}

double _mediumTileHeight(InterestCluster cluster) {
  if (cluster.saveCount >= 18 || cluster.dominance >= 0.25) return 190;
  if (cluster.saveCount >= 10 || cluster.dominance >= 0.18) return 176;
  return 154;
}

class _PatternTile extends StatelessWidget {
  const _PatternTile({
    required this.cluster,
    required this.onTap,
    required this.height,
    required this.borderRadius,
    required this.titleStyle,
    required this.chipLimit,
    required this.showEyebrow,
  });

  final InterestCluster cluster;
  final VoidCallback onTap;
  final double height;
  final double borderRadius;
  final TextStyle? titleStyle;
  final int chipLimit;
  final bool showEyebrow;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final spec = _visualSpec(context, cluster);
    final accent = spec.accent;
    final containerColor = _tintedSurface(cs, accent, tierElevation: 2);
    final onTile = cs.onSurface;
    final subtopics = cluster.subtopics.take(chipLimit).toList();

    return Semantics(
      button: true,
      label: '${cluster.label}, ${cluster.saveCount} saves',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.06),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredPlaceholder(
                  color: containerColor,
                  accent: accent,
                  kind: spec.kind,
                  seed: cluster.id.hashCode,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        cs.surface.withValues(alpha: 0.02),
                        cs.surface.withValues(alpha: 0.78),
                      ],
                      stops: const [0.18, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showEyebrow)
                        _TileBadge(
                          label: 'Dominant interest',
                          color: onTile,
                        ),
                      const Spacer(),
                      Text(
                        cluster.label,
                        maxLines: tierTitleLines(height),
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle?.copyWith(
                          color: onTile,
                          fontWeight: FontWeight.w700,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        showEyebrow
                            ? '${_saveText(cluster.saveCount)} · your biggest interest'
                            : _saveText(cluster.saveCount),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: onTile.withValues(alpha: 0.68),
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      if (subtopics.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final subtopic in subtopics)
                              _TileChip(label: subtopic, color: onTile),
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

  int tierTitleLines(double tileHeight) => tileHeight >= 170 ? 2 : 1;
}

class _SlimTile extends StatelessWidget {
  const _SlimTile({required this.cluster, required this.onTap});

  final InterestCluster cluster;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final spec = _visualSpec(context, cluster);
    final accent = spec.accent;
    final bg = _tintedSurface(cs, accent, tierElevation: 1);
    final subtopicText = cluster.subtopics.take(2).join(' · ');

    return Semantics(
      button: true,
      label: '${cluster.label}, ${cluster.saveCount} saves',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _InterestIcon(spec: spec),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cluster.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.58),
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

class ColoredPlaceholder extends StatelessWidget {
  const ColoredPlaceholder({
    super.key,
    required this.color,
    required this.accent,
    required this.kind,
    this.seed = 0,
  });

  final Color color;
  final Color accent;
  final _InterestKind kind;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _InterestPatternPainter(
        base: color,
        accent: accent,
        kind: kind,
        seed: seed,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _InterestPatternPainter extends CustomPainter {
  const _InterestPatternPainter({
    required this.base,
    required this.accent,
    required this.kind,
    required this.seed,
  });

  final Color base;
  final Color accent;
  final _InterestKind kind;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(accent.withValues(alpha: 0.24), base),
          Color.alphaBlend(Colors.black.withValues(alpha: 0.16), base),
          Color.alphaBlend(accent.withValues(alpha: 0.30), base),
        ],
        stops: const [0, 0.58, 1],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final softPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = accent.withValues(alpha: 0.12);
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.22);

    switch (kind) {
      case _InterestKind.treks:
      case _InterestKind.travel:
        _paintMountains(canvas, size, softPaint, linePaint);
      case _InterestKind.designSystems:
      case _InterestKind.typography:
      case _InterestKind.creative:
        _paintGrid(canvas, size, softPaint, linePaint);
      case _InterestKind.aiAgents:
      case _InterestKind.devTools:
      case _InterestKind.websiteGrowth:
        _paintNodes(canvas, size, softPaint, linePaint);
      case _InterestKind.agriculture:
      case _InterestKind.finance:
        _paintBars(canvas, size, softPaint, linePaint);
      case _InterestKind.longReads:
      case _InterestKind.books:
      case _InterestKind.learning:
        _paintLines(canvas, size, softPaint, linePaint);
      case _InterestKind.social:
      case _InterestKind.startup:
      case _InterestKind.gaming:
      case _InterestKind.productivity:
      case _InterestKind.philosophy:
      case _InterestKind.vehicles:
      case _InterestKind.general:
        _paintOrbit(canvas, size, softPaint, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _InterestPatternPainter oldDelegate) {
    return oldDelegate.base != base ||
        oldDelegate.accent != accent ||
        oldDelegate.kind != kind ||
        oldDelegate.seed != seed;
  }

  void _paintMountains(
    Canvas canvas,
    Size size,
    Paint fill,
    Paint line,
  ) {
    final back = Path()
      ..moveTo(0, size.height * 0.68)
      ..lineTo(size.width * 0.28, size.height * 0.40)
      ..lineTo(size.width * 0.48, size.height * 0.58)
      ..lineTo(size.width * 0.72, size.height * 0.26)
      ..lineTo(size.width, size.height * 0.50)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(back, fill);
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.62)
        ..lineTo(size.width * 0.34, size.height * 0.48)
        ..lineTo(size.width * 0.58, size.height * 0.62)
        ..lineTo(size.width, size.height * 0.36),
      line,
    );
  }

  void _paintGrid(Canvas canvas, Size size, Paint fill, Paint line) {
    final cell = size.shortestSide * 0.18;
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 5; col++) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.58 + col * cell * 0.75,
            size.height * 0.15 + row * cell * 0.82,
            cell * 0.55,
            cell * 0.55,
          ),
          const Radius.circular(4),
        );
        canvas.drawRRect(rect, fill);
      }
    }
    canvas.drawLine(
      Offset(0, size.height * 0.58),
      Offset(size.width, size.height * 0.44),
      line,
    );
  }

  void _paintNodes(Canvas canvas, Size size, Paint fill, Paint line) {
    final nodes = [
      Offset(size.width * 0.14, size.height * 0.24),
      Offset(size.width * 0.34, size.height * 0.42),
      Offset(size.width * 0.54, size.height * 0.30),
      Offset(size.width * 0.76, size.height * 0.56),
      Offset(size.width * 0.90, size.height * 0.28),
    ];
    for (var i = 0; i < nodes.length - 1; i++) {
      canvas.drawLine(nodes[i], nodes[i + 1], line);
    }
    for (final node in nodes) {
      canvas.drawCircle(node, size.shortestSide * 0.07, fill);
    }
  }

  void _paintBars(Canvas canvas, Size size, Paint fill, Paint line) {
    for (var i = 0; i < 6; i++) {
      final h = size.height * (0.16 + 0.08 * ((i + seed).abs() % 4));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * (0.50 + i * 0.08),
            size.height * 0.72 - h,
            size.width * 0.045,
            h,
          ),
          const Radius.circular(4),
        ),
        fill,
      );
    }
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.72),
      Offset(size.width * 0.92, size.height * 0.34),
      line,
    );
  }

  void _paintLines(Canvas canvas, Size size, Paint fill, Paint line) {
    for (var i = 0; i < 5; i++) {
      final y = size.height * (0.18 + i * 0.13);
      canvas.drawLine(
        Offset(size.width * 0.52, y),
        Offset(size.width * (0.86 - i * 0.04), y),
        line,
      );
    }
    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.28),
        size.shortestSide * 0.12, fill);
  }

  void _paintOrbit(Canvas canvas, Size size, Paint fill, Paint line) {
    final center = Offset(size.width * 0.76, size.height * 0.34);
    canvas.drawCircle(center, size.shortestSide * 0.13, fill);
    canvas.drawArc(
      Rect.fromCenter(
        center: center,
        width: size.shortestSide * 0.55,
        height: size.shortestSide * 0.32,
      ),
      -0.7,
      4.4,
      false,
      line,
    );
  }
}

class _InterestIcon extends StatelessWidget {
  const _InterestIcon({required this.spec});

  final _InterestVisualSpec spec;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          spec.accent.withValues(alpha: 0.14),
          cs.surfaceContainerHighest,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: spec.accent.withValues(alpha: 0.20)),
      ),
      alignment: Alignment.center,
      child: Icon(
        spec.icon,
        color: spec.accent.harmonizeWith(cs.primary),
        size: 21,
      ),
    );
  }
}

class _TileChip extends StatelessWidget {
  const _TileChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 148),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                ),
          ),
        ),
      ),
    );
  }
}

class _TileBadge extends StatelessWidget {
  const _TileBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color.withValues(alpha: 0.78),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
      ),
    );
  }
}

_InterestVisualSpec _visualSpec(BuildContext context, InterestCluster cluster) {
  final cs = Theme.of(context).colorScheme;
  final lower = [
    cluster.label,
    ...cluster.subtopics,
  ].join(' ').toLowerCase();

  _InterestVisualSpec spec(
    _InterestKind kind,
    int color,
    IconData icon,
  ) {
    return _InterestVisualSpec(
      kind,
      Color(color).harmonizeWith(cs.primary),
      icon,
    );
  }

  if (_hasAny(lower, ['trek', 'route', 'mountain', 'himalayan'])) {
    return spec(_InterestKind.treks, 0xFF2D7FF9, Icons.terrain_rounded);
  }
  if (_hasAny(lower, ['typography', 'font'])) {
    return spec(_InterestKind.typography, 0xFFFF4FA3, Icons.text_fields_rounded);
  }
  if (_hasAny(lower, ['design system', 'ui tool', 'pattern', 'design'])) {
    return spec(
      _InterestKind.designSystems,
      0xFF8B5CF6,
      Icons.grid_view_rounded,
    );
  }
  if (_hasAny(lower, ['ai', 'agent', 'llm', 'prompt', 'claude', 'openai'])) {
    return spec(_InterestKind.aiAgents, 0xFF00B8A9, Icons.account_tree_rounded);
  }
  if (_hasAny(lower, ['seo', 'website', 'search console', 'growth'])) {
    return spec(
      _InterestKind.websiteGrowth,
      0xFF1DB954,
      Icons.trending_up_rounded,
    );
  }
  if (_hasAny(lower, ['github', 'oss', 'code', 'software', 'react', 'next'])) {
    return spec(_InterestKind.devTools, 0xFFFFC857, Icons.code_rounded);
  }
  if (_hasAny(lower, ['startup', 'founder', 'users'])) {
    return spec(_InterestKind.startup, 0xFFFF8A00, Icons.rocket_launch_rounded);
  }
  if (_hasAny(lower, ['farm', 'agri'])) {
    return spec(_InterestKind.agriculture, 0xFF7CB342, Icons.eco_rounded);
  }
  if (_hasAny(lower, ['social', 'instagram', 'reddit', 'x.com'])) {
    return spec(_InterestKind.social, 0xFFFF5A5F, Icons.groups_rounded);
  }
  if (_hasAny(lower, ['book', 'essay', 'read'])) {
    return spec(_InterestKind.longReads, 0xFFBA8C63, Icons.menu_book_rounded);
  }
  if (_hasAny(lower, ['finance', 'market'])) {
    return spec(_InterestKind.finance, 0xFF00A884, Icons.show_chart_rounded);
  }
  if (_hasAny(lower, ['learn', 'course', 'engineering'])) {
    return spec(_InterestKind.learning, 0xFF4C8BF5, Icons.school_rounded);
  }
  if (_hasAny(lower, ['game'])) {
    return spec(_InterestKind.gaming, 0xFFB35CFF, Icons.extension_rounded);
  }
  if (_hasAny(lower, ['travel', 'destination'])) {
    return spec(_InterestKind.travel, 0xFF00B8A9, Icons.map_rounded);
  }
  if (_hasAny(lower, ['philosophy', 'self-improvement', 'development'])) {
    return spec(_InterestKind.philosophy, 0xFF7E8BFF, Icons.psychology_rounded);
  }
  if (_hasAny(lower, ['bike', 'motorcycle', 'vehicle'])) {
    return spec(_InterestKind.vehicles, 0xFFE57373, Icons.two_wheeler_rounded);
  }
  if (_hasAny(lower, ['document', 'office', 'productivity'])) {
    return spec(
      _InterestKind.productivity,
      0xFF6C8EBF,
      Icons.description_rounded,
    );
  }

  final raw = cluster.accentColor ?? cs.primary;
  return _InterestVisualSpec(
    _InterestKind.general,
    raw.harmonizeWith(cs.primary),
    Icons.category_rounded,
  );
}

Color _tintedSurface(
  ColorScheme cs,
  Color accent, {
  required double tierElevation,
}) {
  final surface = ElevationOverlay.applySurfaceTint(
    cs.surfaceContainerLow,
    cs.surfaceTint,
    tierElevation,
  );
  final alpha = cs.brightness == Brightness.dark ? 0.24 : 0.12;
  return Color.alphaBlend(accent.withValues(alpha: alpha), surface);
}

bool _hasAny(String text, List<String> needles) {
  return needles.any(text.contains);
}

String _saveText(int count) => count == 1 ? '1 save' : '$count saves';
