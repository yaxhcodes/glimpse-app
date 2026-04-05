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

const double _kCenterNodeSize = 76;
const double _kClusterNodeSizeLarge = 72;
const double _kClusterNodeSizeSmall = 64;
const double _kClusterLabelColumnExtraWidth = 24;

/// Prefer a URL that has a real preview image for cluster representation.
SavedUrl? _representativeUrl(List<SavedUrl> urls) {
  for (final u in urls) {
    final t = u.thumbnailUrl?.trim();
    if (t != null && t.isNotEmpty) return u;
  }
  return urls.isEmpty ? null : urls.first;
}

/// Thumbnail, known-platform favicon, or Google favicon for the saved domain.
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
            lineColor.withValues(alpha: 0.14),
            lineColor.withValues(alpha: 0.04),
          ],
        )
        ..strokeWidth = 0.85
        ..style = PaintingStyle.stroke;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(
          (center.dx + pos.dx) / 2,
          (center.dy + pos.dy) / 2 - 24,
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

class _MindmapCirclePreview extends StatelessWidget {
  const _MindmapCirclePreview({
    required this.urls,
    required this.size,
    required this.fallbackLetter,
  });

  final List<SavedUrl> urls;
  final double size;
  final String fallbackLetter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rep = _representativeUrl(urls);
    final imageUrl = rep != null ? _previewImageUrl(rep) : null;

    Widget child;
    if (imageUrl != null) {
      child = CachedNetworkImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, _) => ColoredBox(color: cs.surfaceContainerHighest),
        errorWidget: (_, _, _) => _LetterFallback(
          letter: fallbackLetter,
          size: size,
        ),
      );
    } else {
      child = _LetterFallback(letter: fallbackLetter, size: size);
    }

    return ClipOval(child: SizedBox(width: size, height: size, child: child));
  }
}

class _LetterFallback extends StatelessWidget {
  const _LetterFallback({
    required this.letter,
    required this.size,
  });

  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ch = letter.isNotEmpty ? letter[0].toUpperCase() : '?';
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Text(
          ch,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: (size * 0.38).clamp(14.0, 22.0),
              ),
        ),
      ),
    );
  }
}

void _openClusterSheet(
  BuildContext context,
  ClusterTheme theme,
  Map<String, int> tagFrequency,
) {
  final rootCtx = context;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final tt = Theme.of(ctx).textTheme;

      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    theme.label,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                      height: 1.3,
                    ),
                  ),
                  if (theme.summary.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      theme.summary,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${theme.urls.length} saved ${theme.urls.length == 1 ? 'link' : 'links'}',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
            SizedBox(
              height: (MediaQuery.sizeOf(ctx).height * 0.52).clamp(220.0, 480.0),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                itemCount: theme.urls.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  indent: 68,
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                ),
                itemBuilder: (context, i) {
                  final u = theme.urls[i];
                  return _ClusterUrlListRow(
                    url: u,
                    tagFrequency: tagFrequency,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(ctx);
                      rootCtx.push('/url/${u.id}');
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

class _ClusterUrlListRow extends StatelessWidget {
  const _ClusterUrlListRow({
    required this.url,
    required this.tagFrequency,
    required this.onTap,
  });

  final SavedUrl url;
  final Map<String, int> tagFrequency;
  final VoidCallback onTap;

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
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: _thumb,
                  height: _thumb,
                  child: previewUrl != null
                      ? CachedNetworkImage(
                          imageUrl: previewUrl,
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 150),
                          placeholder: (_, _) =>
                              ColoredBox(color: cs.surfaceContainerHighest),
                          errorWidget: (_, _, _) => _LetterFallback(
                            letter: url.domain.isNotEmpty ? url.domain[0] : '?',
                            size: _thumb,
                          ),
                        )
                      : _LetterFallback(
                          letter: url.domain.isNotEmpty ? url.domain[0] : '?',
                          size: _thumb,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 4),
                    Text(
                      url.domain,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Map canvas: layout from real constraints so center and spokes match the screen.
class _MindmapCanvas extends StatelessWidget {
  const _MindmapCanvas({
    required this.themes,
    required this.tagFrequency,
  });

  final List<ClusterTheme> themes;
  final Map<String, int> tagFrequency;

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
                _CenterHubNode(center: center, cs: cs),
                for (var i = 0; i < themes.length; i++)
                  _ClusterMapNode(
                    cluster: themes[i],
                    position: positions[i],
                    cs: cs,
                    tt: tt,
                    isLarge: themes[i].urls.length >= 4,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _openClusterSheet(context, themes[i], tagFrequency);
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

class _CenterHubNode extends StatelessWidget {
  const _CenterHubNode({
    required this.center,
    required this.cs,
  });

  final Offset center;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: center.dx - _kCenterNodeSize / 2,
      top: center.dy - _kCenterNodeSize / 2,
      child: Semantics(
        label: 'Glimpse library hub',
        child: Container(
          width: _kCenterNodeSize,
          height: _kCenterNodeSize,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.primary,
            border: Border.all(
              color: cs.onPrimary.withValues(alpha: 0.14),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SvgPicture.asset(
            'assets/glimpse3.svg',
            width: _kCenterNodeSize,
            height: _kCenterNodeSize,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            colorFilter: ColorFilter.mode(
              cs.onPrimary,
              BlendMode.srcIn,
            ),
          ),
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
    final mq = MediaQuery.sizeOf(context);
    final labelColumnWidth = math.max(
      nodeSize + _kClusterLabelColumnExtraWidth,
      (mq.width * 0.52).clamp(128.0, 360.0),
    );
    final horizontalPad = _kClusterLabelColumnExtraWidth / 2;
    final rep = _representativeUrl(cluster.urls);
    final letter = rep != null && rep.domain.isNotEmpty ? rep.domain[0] : '·';
    final count = cluster.urls.length;

    return Positioned(
      left: position.dx - labelColumnWidth / 2,
      top: position.dy - nodeSize / 2,
      child: SizedBox(
        width: labelColumnWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label:
                  '${cluster.label}, ${formatLinkCount(count)}. Double tap to open.',
              button: true,
              child: Tooltip(
                message: cluster.label,
                child: GestureDetector(
                  onTap: onTap,
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: nodeSize,
                          height: nodeSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.95),
                              width: isLarge ? 1.25 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: cs.shadow.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: _MindmapCirclePreview(
                              urls: cluster.urls,
                              size: nodeSize - 4,
                              fallbackLetter: letter,
                            ),
                          ),
                        ),
                        if (count > 1)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              constraints:
                                  const BoxConstraints(minWidth: 22),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: cs.outlineVariant
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              child: Text(
                                '$count',
                                textAlign: TextAlign.center,
                                style: tt.bodySmall?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurfaceVariant,
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
            ),
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPad),
              child: Text(
                cluster.label,
                textAlign: TextAlign.center,
                softWrap: true,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  fontSize: 12,
                ),
              ),
            ),
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
              Icons.account_tree_outlined,
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
  const MindmapScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final themesAsync = ref.watch(interestClusterThemesProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Interest Map',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Tap a topic to browse saves',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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

          return ColoredBox(
            color: cs.surface,
            child: _MindmapCanvas(
              themes: themes,
              tagFrequency: ref.watch(tagOccurrenceMapProvider),
            ),
          );
        },
      ),
    );
  }
}
