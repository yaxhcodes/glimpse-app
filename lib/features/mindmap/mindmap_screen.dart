import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading_indicator.dart';
import 'cluster_theme.dart';
import 'interest_clusters_provider.dart';

const double _kCenterNodeSize = 96;
const double _kClusterNodeSizeLarge = 92;
const double _kClusterNodeSizeSmall = 80;
const double _kClusterLabelColumnExtraWidth = 20;

List<Offset> _radialClusterPositions(int count, Offset center, double radius) {
  if (count <= 0) return const [];
  return List.generate(count, (i) {
    final angle = (i / count) * 2 * math.pi - math.pi / 2;
    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
  });
}

class _MindmapLinePainter extends CustomPainter {
  _MindmapLinePainter({
    required this.center,
    required this.nodePositions,
    required this.lineColor,
  });

  final Offset center;
  final List<Offset> nodePositions;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (final pos in nodePositions) {
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          center,
          pos,
          [
            lineColor.withValues(alpha: 0.5),
            lineColor.withValues(alpha: 0.15),
          ],
        )
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(
          (center.dx + pos.dx) / 2,
          (center.dy + pos.dy) / 2 - 30,
          pos.dx,
          pos.dy,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MindmapLinePainter oldDelegate) =>
      oldDelegate.center != center ||
      oldDelegate.nodePositions != nodePositions ||
      oldDelegate.lineColor != lineColor;
}

void _openClusterSheet(BuildContext context, ClusterTheme theme) {
  final cs = Theme.of(context).colorScheme;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${theme.emoji} ${theme.label}',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              subtitle: Text(theme.summary),
            ),
            const Divider(),
            ...theme.urls.map(
              (u) => ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                title: Text(
                  u.title.isNotEmpty ? u.title : u.domain,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  u.domain,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/url/${u.id}');
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Map canvas: layout from real constraints so center and spokes match the screen.
class _MindmapCanvas extends StatelessWidget {
  const _MindmapCanvas({required this.themes});

  final List<ClusterTheme> themes;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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

        final size = Size(w, h);
        final center = Offset(
          size.width / 2,
          size.height * 0.46,
        );
        final radius = size.shortestSide * 0.42;
        final positions =
            _radialClusterPositions(themes.length, center, radius);

        final lineColor = cs.outlineVariant;

        return InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(150),
          minScale: 0.6,
          maxScale: 3.0,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MindmapLinePainter(
                      center: center,
                      nodePositions: positions,
                      lineColor: lineColor,
                    ),
                  ),
                ),
                _CenterHubNode(center: center, cs: cs, tt: tt),
                for (var i = 0; i < themes.length; i++)
                  _ClusterMapNode(
                    cluster: themes[i],
                    position: positions[i],
                    cs: cs,
                    tt: tt,
                    isLarge: themes[i].urls.length >= 4,
                    onTap: () => _openClusterSheet(context, themes[i]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CenterHubNode extends StatelessWidget {
  const _CenterHubNode({
    required this.center,
    required this.cs,
    required this.tt,
  });

  final Offset center;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: center.dx - _kCenterNodeSize / 2,
      top: center.dy - _kCenterNodeSize / 2,
      child: Container(
        width: _kCenterNodeSize,
        height: _kCenterNodeSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.primary,
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.20),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hub_rounded, size: 22, color: cs.onPrimary),
            const SizedBox(height: 4),
            Text(
              'Glimpse',
              style: tt.labelMedium?.copyWith(
                color: cs.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClusterMapNode extends StatelessWidget {
  const _ClusterMapNode({
    required this.cluster,
    required this.position,
    required this.cs,
    required this.tt,
    required this.isLarge,
    required this.onTap,
  });

  final ClusterTheme cluster;
  final Offset position;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isLarge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nodeSize = isLarge ? _kClusterNodeSizeLarge : _kClusterNodeSizeSmall;
    final emojiSize = isLarge ? 26.0 : 22.0;
    final columnWidth = nodeSize + _kClusterLabelColumnExtraWidth;
    final horizontalPad = _kClusterLabelColumnExtraWidth / 2;

    return Positioned(
      left: position.dx - columnWidth / 2,
      top: position.dy - nodeSize / 2,
      child: SizedBox(
        width: columnWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onTap,
              child: Center(
                child: Container(
                  width: nodeSize,
                  height: nodeSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.surfaceContainerHigh,
                    border: Border.all(
                      color: isLarge
                          ? cs.primary.withValues(alpha: 0.4)
                          : cs.outlineVariant,
                      width: isLarge ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      cluster.emoji,
                      style: TextStyle(fontSize: emojiSize),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPad),
              child: Text(
                cluster.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
            if (cluster.urls.length > 1) ...[
              const SizedBox(height: 2),
              Text(
                '${cluster.urls.length} links',
                textAlign: TextAlign.center,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MindmapEmptyState extends StatelessWidget {
  const _MindmapEmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hub_outlined,
              size: 48,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Not enough data yet',
              style: tt.titleMedium?.copyWith(color: cs.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Save more links and I\'ll map out your interests automatically.',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MindmapScreen extends ConsumerWidget {
  const MindmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final themesAsync = ref.watch(interestClusterThemesProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Interest Map',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Your library as a mind map',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              await clearInterestClusterCache();
              ref.invalidate(interestClusterThemesProvider);
            },
          ),
        ],
      ),
      body: themesAsync.when(
        loading: () => const LoadingIndicator(message: 'Mapping your library…'),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not build clusters.\n$e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (themes) {
          if (themes.isEmpty || themes.length < 3) {
            return _MindmapEmptyState();
          }

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  cs.surfaceContainerLow,
                  cs.surface,
                ],
              ),
            ),
            child: _MindmapCanvas(themes: themes),
          );
        },
      ),
    );
  }
}
