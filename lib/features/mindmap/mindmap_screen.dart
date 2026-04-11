import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/saved_url.dart';
import '../../core/services/title_resolver.dart';
import '../../shared/formatting.dart';
import '../../shared/widgets/category_chip.dart' show faviconUrl;
import '../../shared/widgets/loading_indicator.dart';
import '../home/home_provider.dart';
import 'cluster_theme.dart';
import 'interest_clusters_provider.dart';

// ─── Layout constants ──────────────────────────────────────────────────────

const double _kCenterNodeSize = 80;
const double _kNodeSizeBase = 62;
const double _kNodeSizeMax = 80;
const double _kLabelColumnWidth = 110;

// ─── Helpers ───────────────────────────────────────────────────────────────

SavedUrl? _representativeUrl(List<SavedUrl> urls) {
  for (final u in urls) {
    final t = u.thumbnailUrl?.trim();
    if (t != null && t.isNotEmpty) return u;
  }
  return urls.isEmpty ? null : urls.first;
}

String? _previewImageUrl(SavedUrl u) {
  final t = u.thumbnailUrl?.trim();
  if (t != null && t.isNotEmpty) return t;
  final fav = faviconUrl(u.category);
  if (fav != null) return fav;
  final d = u.domain.trim();
  if (d.isNotEmpty) {
    return 'https://www.google.com/s2/favicons?domain=${Uri.encodeComponent(d)}&sz=128';
  }
  return null;
}

List<Offset> _radialPositions(int count, Offset center, double radius) {
  if (count <= 0) return const [];
  return List.generate(count, (i) {
    final angle = (i / count) * 2 * math.pi - math.pi / 2;
    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
  });
}

double _nodeSize(int urlCount) {
  if (urlCount <= 1) return _kNodeSizeBase;
  if (urlCount >= 15) return _kNodeSizeMax;
  return _kNodeSizeBase +
      (_kNodeSizeMax - _kNodeSizeBase) * ((urlCount - 1) / 14);
}

// ─── Constellation line painter ───────────────────────────────────────────

class _ConstellationPainter extends CustomPainter {
  _ConstellationPainter({
    required this.center,
    required this.nodePositions,
    required this.accentColors,
    required this.progress,
  }) : super(repaint: progress);

  final Offset center;
  final List<Offset> nodePositions;
  final List<Color> accentColors;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;

    for (var i = 0; i < nodePositions.length; i++) {
      final pos = nodePositions[i];
      final color = accentColors[i % accentColors.length];

      // Interpolate line endpoint along the arc for draw-in effect
      final drawPos = Offset.lerp(center, pos, t)!;

      // Draw-in endpoint along curve
      final drawCp = Offset(
        (center.dx + drawPos.dx) / 2,
        (center.dy + drawPos.dy) / 2 - 30 * t,
      );

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(drawCp.dx, drawCp.dy, drawPos.dx, drawPos.dy);

      // Base subtle line
      final basePaint = Paint()
        ..shader = ui.Gradient.linear(center, pos, [
          color.withValues(alpha: 0.18 * t),
          color.withValues(alpha: 0.04 * t),
        ])
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Accent glow on top
      final glowPaint = Paint()
        ..shader = ui.Gradient.linear(
          center,
          pos,
          [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.45 * t),
            color.withValues(alpha: 0.0),
          ],
          [0.0, 0.42, 1.0],
        )
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);

      canvas.drawPath(path, basePaint);
      canvas.drawPath(path, glowPaint);

      // Dot at the node end (fades in last 20% of draw)
      if (t > 0.7) {
        final dotT = ((t - 0.7) / 0.3).clamp(0.0, 1.0);
        final dotPaint = Paint()
          ..color = color.withValues(alpha: 0.55 * dotT)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
        canvas.drawCircle(pos, 4.0 * dotT, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationPainter old) =>
      old.center != center ||
      old.nodePositions != nodePositions ||
      old.accentColors != accentColors;
}

// ─── Center hub node (pulsing) ─────────────────────────────────────────────

class _CenterHubNode extends StatefulWidget {
  const _CenterHubNode({required this.center, required this.cs});

  final Offset center;
  final ColorScheme cs;

  @override
  State<_CenterHubNode> createState() => _CenterHubNodeState();
}

class _CenterHubNodeState extends State<_CenterHubNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _scale = Tween<double>(
      begin: 1.0,
      end: 1.055,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _glow = Tween<double>(
      begin: 12.0,
      end: 26.0,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.center.dx - _kCenterNodeSize / 2,
      top: widget.center.dy - _kCenterNodeSize / 2,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: Container(
              width: _kCenterNodeSize,
              height: _kCenterNodeSize,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.cs.primary,
                boxShadow: [
                  BoxShadow(
                    color: widget.cs.primary.withValues(alpha: 0.50),
                    blurRadius: _glow.value,
                    spreadRadius: (_glow.value - 12) * 0.25,
                  ),
                  BoxShadow(
                    color: widget.cs.primary.withValues(alpha: 0.20),
                    blurRadius: _glow.value * 2.2,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: SvgPicture.asset(
          'assets/glimpse3.svg',
          width: _kCenterNodeSize,
          height: _kCenterNodeSize,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          colorFilter: ColorFilter.mode(widget.cs.onPrimary, BlendMode.srcIn),
        ),
      ),
    );
  }
}

// ─── Circle image preview ──────────────────────────────────────────────────

class _CirclePreview extends StatelessWidget {
  const _CirclePreview({
    required this.urls,
    required this.size,
    required this.fallbackLetter,
    required this.accentColor,
  });

  final List<SavedUrl> urls;
  final double size;
  final String fallbackLetter;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final rep = _representativeUrl(urls);
    final imageUrl = rep != null ? _previewImageUrl(rep) : null;

    Widget child;
    if (imageUrl != null) {
      child = CachedNetworkImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 250),
        placeholder: (_, _) => _LetterFallback(
          letter: fallbackLetter,
          size: size,
          accentColor: accentColor,
        ),
        errorWidget: (_, _, _) => _LetterFallback(
          letter: fallbackLetter,
          size: size,
          accentColor: accentColor,
        ),
      );
    } else {
      child = _LetterFallback(
        letter: fallbackLetter,
        size: size,
        accentColor: accentColor,
      );
    }

    return ClipOval(
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

class _LetterFallback extends StatelessWidget {
  const _LetterFallback({
    required this.letter,
    required this.size,
    required this.accentColor,
  });

  final String letter;
  final double size;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final ch = letter.isNotEmpty ? letter[0].toUpperCase() : '?';
    return Container(
      color: accentColor.withValues(alpha: 0.18),
      child: Center(
        child: Text(
          ch,
          style: TextStyle(
            color: accentColor,
            fontWeight: FontWeight.w700,
            fontSize: (size * 0.38).clamp(14.0, 24.0),
          ),
        ),
      ),
    );
  }
}

// ─── Cluster map node ─────────────────────────────────────────────────────

class _ClusterMapNode extends StatelessWidget {
  const _ClusterMapNode({
    required this.cluster,
    required this.position,
    required this.cs,
    required this.tt,
    required this.onTap,
    required this.entranceAnim,
  });

  final ClusterTheme cluster;
  final Offset position;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onTap;
  final Animation<double> entranceAnim;

  @override
  Widget build(BuildContext context) {
    final size = _nodeSize(cluster.urls.length);
    final count = cluster.urls.length;
    final accent = cluster.accentColor;
    final rep = _representativeUrl(cluster.urls);
    final letter = rep != null && rep.domain.isNotEmpty ? rep.domain[0] : 'G';

    return Positioned(
      left: position.dx - _kLabelColumnWidth / 2,
      top: position.dy - size / 2,
      child: SizedBox(
        width: _kLabelColumnWidth,
        child: AnimatedBuilder(
          animation: entranceAnim,
          builder: (context, child) {
            final t = entranceAnim.value;
            return Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(scale: 0.55 + 0.45 * t, child: child),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label:
                    '${cluster.label}, ${formatLinkCount(count)}. Double tap to open.',
                button: true,
                child: GestureDetector(
                  onTap: onTap,
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Outer glow ring
                        Container(
                          width: size + 8,
                          height: size + 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.22),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        // Main node
                        Container(
                          width: size,
                          height: size,
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accent.withValues(alpha: 0.70),
                              width: 1.75,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: _CirclePreview(
                              urls: cluster.urls,
                              size: size - 4,
                              fallbackLetter: letter,
                              accentColor: accent,
                            ),
                          ),
                        ),
                        // Count badge
                        if (count > 1)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 22),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.40),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                '$count',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                cluster.label,
                textAlign: TextAlign.center,
                softWrap: true,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  fontSize: 11.5,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mindmap canvas (animated) ─────────────────────────────────────────────

class _MindmapCanvas extends StatefulWidget {
  const _MindmapCanvas({required this.themes, required this.tagFrequency});

  final List<ClusterTheme> themes;
  final Map<String, int> tagFrequency;

  @override
  State<_MindmapCanvas> createState() => _MindmapCanvasState();
}

class _MindmapCanvasState extends State<_MindmapCanvas>
    with TickerProviderStateMixin {
  late final AnimationController _lineCtrl;
  late final AnimationController _nodesCtrl;
  late final Animation<double> _lineAnim;

  @override
  void initState() {
    super.initState();

    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _nodesCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _lineAnim = CurvedAnimation(parent: _lineCtrl, curve: Curves.easeInOut);

    // Lines draw first, then nodes pop in
    _lineCtrl.forward().then((_) {
      if (mounted) _nodesCtrl.forward();
    });
  }

  @override
  void dispose() {
    _lineCtrl.dispose();
    _nodesCtrl.dispose();
    super.dispose();
  }

  Animation<double> _nodeEntrance(int i, int total) {
    const windowSize = 0.38;
    final step = total > 1 ? (1.0 - windowSize) / (total - 1) : 0.0;
    final start = (i * step).clamp(0.0, 1.0 - windowSize);
    final end = (start + windowSize).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _nodesCtrl,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final themes = widget.themes;

    return LayoutBuilder(
      builder: (context, constraints) {
        var w = constraints.maxWidth;
        var h = constraints.maxHeight;
        if (!w.isFinite || !h.isFinite) {
          final mq = MediaQuery.sizeOf(context);
          if (!w.isFinite) w = mq.width;
          if (!h.isFinite) h = mq.height;
        }
        w = w.clamp(1.0, double.infinity);
        h = h.clamp(1.0, double.infinity);

        final center = Offset(w / 2, h * 0.46);
        final radius = (w * 0.5).clamp(120.0, 220.0);
        final positions = _radialPositions(themes.length, center, radius);
        final accentColors = themes.map((t) => t.accentColor).toList();

        return InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(160),
          minScale: 0.55,
          maxScale: 3.0,
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Constellation lines
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ConstellationPainter(
                      center: center,
                      nodePositions: positions,
                      accentColors: accentColors,
                      progress: _lineAnim,
                    ),
                  ),
                ),

                // Pulsing center hub
                _CenterHubNode(center: center, cs: cs),

                // Cluster nodes
                for (var i = 0; i < themes.length; i++)
                  _ClusterMapNode(
                    cluster: themes[i],
                    position: positions[i],
                    cs: cs,
                    tt: tt,
                    entranceAnim: _nodeEntrance(i, themes.length),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _openClusterSheet(
                        context,
                        themes[i],
                        widget.tagFrequency,
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Cluster bottom sheet ─────────────────────────────────────────────────

void _openClusterSheet(
  BuildContext context,
  ClusterTheme theme,
  Map<String, int> tagFrequency,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Theme sets BottomSheetThemeData.showDragHandle: true; we draw our own
    // handle inside [_ClusterSheet] for [DraggableScrollableSheet] sizing.
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ClusterSheet(
      theme: theme,
      tagFrequency: tagFrequency,
      rootCtx: context,
    ),
  );
}

// ─── Cluster bottom sheet (stateful for sub-cluster filter) ───────────────

class _ClusterSheet extends StatefulWidget {
  const _ClusterSheet({
    required this.theme,
    required this.tagFrequency,
    required this.rootCtx,
  });

  final ClusterTheme theme;
  final Map<String, int> tagFrequency;
  final BuildContext rootCtx;

  @override
  State<_ClusterSheet> createState() => _ClusterSheetState();
}

class _ClusterSheetState extends State<_ClusterSheet> {
  // null = "All"; non-null = index into theme.subClusters
  int? _selectedSub;

  // Maps each url.id -> the sub-cluster label it belongs to (for the "All" view)
  late final Map<int, String> _urlSubLabel;

  final _sheetController = DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _urlSubLabel = {};
    for (final sub in widget.theme.subClusters) {
      for (final u in sub.urls) {
        _urlSubLabel[u.id] = sub.label;
      }
    }
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  List<SavedUrl> get _visibleUrls {
    if (_selectedSub == null) return widget.theme.urls;
    return widget.theme.subClusters[_selectedSub!].urls;
  }

  String? _subLabelFor(SavedUrl u) {
    if (!widget.theme.hasSubClusters) return null;
    // Only show the sub-label in the "All" view
    if (_selectedSub != null) return null;
    return _urlSubLabel[u.id];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = widget.theme.accentColor;
    final hasSubs = widget.theme.hasSubClusters;
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;
    final sheetBg = cs.brightness == Brightness.dark
        ? cs.surfaceContainerLow
        : cs.surface;

    // Starts at ~65 % height; snaps to fullscreen on drag up.
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 1.0,
      snap: true,
      snapSizes: const [0.65, 1.0],
      expand: false,
      builder: (ctx, scrollCtrl) {
        return ListenableBuilder(
          listenable: _sheetController,
          builder: (context, child) {
            final size = _sheetController.isAttached
                ? _sheetController.size
                : 0.65;
            final radius = size >= 0.99 ? 0.0 : 28.0;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(radius)),
              ),
              child: child,
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Drag handle ──────────────────────────────────────────────
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.theme.label,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        height: 1.25,
                      ),
                    ),
                    if (widget.theme.summary.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        widget.theme.summary,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.theme.urls.length} ${widget.theme.urls.length == 1 ? 'link' : 'links'}',
                        style: tt.labelSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.40),
              ),

              // ── Sub-cluster chip bar ──────────────────────────────────────
              if (hasSubs) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _SubChip(
                          label: 'All',
                          count: widget.theme.urls.length,
                          selected: _selectedSub == null,
                          accent: accent,
                          cs: cs,
                          tt: tt,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedSub = null);
                          },
                        ),
                        for (
                          var i = 0;
                          i < widget.theme.subClusters.length;
                          i++
                        ) ...[
                          const SizedBox(width: 8),
                          _SubChip(
                            label: widget.theme.subClusters[i].label,
                            count: widget.theme.subClusters[i].urls.length,
                            selected: _selectedSub == i,
                            accent: accent,
                            cs: cs,
                            tt: tt,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedSub = i);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              // ── URL list (fills remaining height) ─────────────────────────
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + bottomPad),
                  itemCount: _visibleUrls.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: 72,
                    color: cs.outlineVariant.withValues(alpha: 0.30),
                  ),
                  itemBuilder: (context, i) {
                    final u = _visibleUrls[i];
                    return _ClusterUrlRow(
                      url: u,
                      tagFrequency: widget.tagFrequency,
                      accentColor: accent,
                      subLabel: _subLabelFor(u),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        widget.rootCtx.push('/url/${u.id}');
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Sub-cluster filter chip ──────────────────────────────────────────────

class _SubChip extends StatelessWidget {
  const _SubChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.accent,
    required this.cs,
    required this.tt,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final Color accent;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Selected → solid accent fill with white text.
    // Unselected → translucent surface with muted text and a faint border.
    final bgColor = selected
        ? accent
        : cs.surfaceContainerHighest.withValues(alpha: 0.55);
    final textColor = selected ? Colors.white : cs.onSurfaceVariant;
    final badgeBg = selected
        ? Colors.white.withValues(alpha: 0.22)
        : cs.onSurfaceVariant.withValues(alpha: 0.10);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                  width: 1.0,
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: tt.labelSmall?.copyWith(
                color: textColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClusterUrlRow extends StatelessWidget {
  const _ClusterUrlRow({
    required this.url,
    required this.tagFrequency,
    required this.accentColor,
    required this.onTap,
    this.subLabel,
  });

  final SavedUrl url;
  final Map<String, int> tagFrequency;
  final Color accentColor;
  final VoidCallback onTap;

  /// When non-null, shown as a small tag on the row (visible in "All" view
  /// so users can see which sub-cluster each URL belongs to).
  final String? subLabel;

  static const double _thumb = 52;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final previewUrl = _previewImageUrl(url);
    final title = TitleResolver.resolve(url, tagFrequency: tagFrequency);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Thumbnail
              Container(
                width: _thumb,
                height: _thumb,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: previewUrl != null
                    ? CachedNetworkImage(
                        imageUrl: previewUrl,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 150),
                        placeholder: (_, _) => Container(
                          color: accentColor.withValues(alpha: 0.10),
                          child: Center(
                            child: Text(
                              url.domain.isNotEmpty
                                  ? url.domain[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: accentColor.withValues(alpha: 0.10),
                          child: Center(
                            child: Text(
                              url.domain.isNotEmpty
                                  ? url.domain[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: accentColor.withValues(alpha: 0.10),
                        child: Center(
                          child: Text(
                            url.domain.isNotEmpty
                                ? url.domain[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: cs.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            url.domain,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 11.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (subLabel != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              subLabel!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────

class _MindmapEmptyState extends StatelessWidget {
  const _MindmapEmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surfaceContainerHighest,
              ),
              child: Icon(
                Icons.hub_outlined,
                size: 34,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your interest map is empty',
              style: tt.titleSmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Save at least 3 links and the map will auto-generate clusters of your interests.',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Main screen ───────────────────────────────────────────────────────────

class MindmapScreen extends ConsumerWidget {
  const MindmapScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final themesAsync = ref.watch(interestClusterThemesProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Interest Map',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              'Tap a cluster to browse saves',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Rebuild map',
            onPressed: () async {
              HapticFeedback.lightImpact();
              await clearInterestClusterCache();
              ref.invalidate(interestClusterThemesProvider);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: themesAsync.when(
        loading: () =>
            const LoadingIndicator(message: 'Mapping your interests...'),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 40, color: cs.error),
                const SizedBox(height: 14),
                Text(
                  'Could not build clusters',
                  style: tt.titleSmall?.copyWith(color: cs.onSurface),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        data: (themes) {
          if (themes.isEmpty || themes.length < 3) {
            return const _MindmapEmptyState();
          }

          return _MindmapCanvas(
            themes: themes,
            tagFrequency: ref.watch(tagOccurrenceMapProvider),
          );
        },
      ),
    );
  }
}
