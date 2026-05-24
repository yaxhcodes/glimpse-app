import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'cluster_card.dart' show InterestCluster;

class ClusterBackground extends StatelessWidget {
  const ClusterBackground({super.key, required this.cluster});

  final InterestCluster cluster;

  @override
  Widget build(BuildContext context) {
    final imageUrl = cluster.coverImageUrl?.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, _) => ProceduralCanvas(cluster: cluster),
        errorWidget: (_, _, _) => ProceduralCanvas(cluster: cluster),
      );
    }
    return ProceduralCanvas(cluster: cluster);
  }
}

class ProceduralCanvas extends StatelessWidget {
  const ProceduralCanvas({super.key, required this.cluster});

  final InterestCluster cluster;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ClusterPainter(cluster: cluster, colorScheme: Theme.of(context).colorScheme),
      child: const SizedBox.expand(),
    );
  }
}

enum _ClusterArtKind { mountain, node, grid, wave, bars, abstract }

class ClusterPainter extends CustomPainter {
  const ClusterPainter({required this.cluster, required this.colorScheme});

  final InterestCluster cluster;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final accent = cluster.accentColor ?? accentFromLabel(cluster.label);
    final kind = _kindForLabel(cluster.label);
    final rect = Offset.zero & size;

    final base = switch (kind) {
      _ClusterArtKind.mountain => const Color(0xFF071411),
      _ClusterArtKind.node => const Color(0xFF080E1D),
      _ClusterArtKind.grid => const Color(0xFF120718),
      _ClusterArtKind.wave => const Color(0xFF071408),
      _ClusterArtKind.bars => const Color(0xFF141005),
      _ClusterArtKind.abstract => colorScheme.surfaceContainerHigh,
    };

    canvas.drawRect(rect, Paint()..color = Color.alphaBlend(accent.withValues(alpha: 0.20), base));

    switch (kind) {
      case _ClusterArtKind.mountain:
        _paintMountain(canvas, size, accent);
      case _ClusterArtKind.node:
        _paintNode(canvas, size, accent);
      case _ClusterArtKind.grid:
        _paintGrid(canvas, size, accent);
      case _ClusterArtKind.wave:
        _paintWave(canvas, size, accent);
      case _ClusterArtKind.bars:
        _paintBars(canvas, size, accent);
      case _ClusterArtKind.abstract:
        _paintAbstract(canvas, size, accent);
    }
  }

  @override
  bool shouldRepaint(covariant ClusterPainter oldDelegate) {
    return oldDelegate.cluster != cluster || oldDelegate.colorScheme != colorScheme;
  }

  _ClusterArtKind _kindForLabel(String label) {
    final l = label.toLowerCase();
    if (_hasAny(l, ['trek', 'hike', 'mountain', 'valley', 'pass', 'route'])) {
      return _ClusterArtKind.mountain;
    }
    if (_hasAny(l, ['ai', 'agent', 'llm', 'ml', 'model', 'workflow'])) {
      return _ClusterArtKind.node;
    }
    if (_hasAny(l, ['design', 'ui', 'ux', 'type', 'font', 'figma', 'css'])) {
      return _ClusterArtKind.grid;
    }
    if (_hasAny(l, ['farm', 'agri', 'grow', 'plant', 'nature', 'bird'])) {
      return _ClusterArtKind.wave;
    }
    if (_hasAny(l, ['growth', 'seo', 'revenue', 'finance', 'market', 'invest'])) {
      return _ClusterArtKind.bars;
    }
    return _ClusterArtKind.abstract;
  }

  void _paintMountain(Canvas canvas, Size size, Color accent) {
    final ridgeColors = [
      accent.withValues(alpha: 0.10),
      accent.withValues(alpha: 0.16),
      accent.withValues(alpha: 0.22),
    ];
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.80 - i * 0.13);
      final path = Path()
        ..moveTo(0, size.height)
        ..lineTo(0, y)
        ..cubicTo(size.width * 0.18, y - 32, size.width * 0.28, y - 54, size.width * 0.42, y - 24)
        ..cubicTo(size.width * 0.58, y + 8, size.width * 0.68, y - 72, size.width * 0.88, y - 38)
        ..cubicTo(size.width * 0.95, y - 26, size.width, y - 16, size.width, y - 24)
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = ridgeColors[i]);
    }

    final random = math.Random(cluster.label.hashCode);
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.24);
    for (var i = 0; i < 8; i++) {
      canvas.drawCircle(
        Offset(size.width * random.nextDouble(), size.height * 0.30 * random.nextDouble()),
        1.2 + random.nextDouble() * 1.4,
        starPaint,
      );
    }
  }

  void _paintNode(Canvas canvas, Size size, Color accent) {
    final points = [
      Offset(size.width * 0.16, size.height * 0.25),
      Offset(size.width * 0.35, size.height * 0.44),
      Offset(size.width * 0.52, size.height * 0.34),
      Offset(size.width * 0.70, size.height * 0.60),
      Offset(size.width * 0.86, size.height * 0.30),
      Offset(size.width * 0.58, size.height * 0.72),
    ];
    final line = Paint()
      ..color = accent.withValues(alpha: 0.30)
      ..strokeWidth = 1;
    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], line);
    }
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], i == 0 ? 14 : 6 + (i % 3) * 3, Paint()..color = accent.withValues(alpha: 0.35));
    }
  }

  void _paintGrid(Canvas canvas, Size size, Color accent) {
    final gap = 6.0;
    final cellW = (size.width * 0.46 - gap * 3) / 4;
    final cellH = (size.height * 0.38 - gap * 2) / 3;
    final startX = size.width * 0.50;
    final startY = size.height * 0.14;
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 4; col++) {
        final alpha = (row + col).isEven ? 0.25 : 0.12;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(startX + col * (cellW + gap), startY + row * (cellH + gap), cellW, cellH),
            const Radius.circular(5),
          ),
          Paint()..color = accent.withValues(alpha: alpha),
        );
      }
    }
  }

  void _paintWave(Canvas canvas, Size size, Color accent) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.30);
    for (var wave = 0; wave < 3; wave++) {
      final path = Path();
      final yBase = size.height * (0.35 + wave * 0.16);
      path.moveTo(0, yBase);
      for (var x = 0.0; x <= size.width; x += 12) {
        final y = yBase + math.sin((x / size.width) * math.pi * 2 + wave) * 14;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
    canvas.drawCircle(Offset(size.width * 0.84, size.height * 0.22), 16, Paint()..color = accent.withValues(alpha: 0.15));
  }

  void _paintBars(Canvas canvas, Size size, Color accent) {
    final barW = size.width / 10;
    final heights = [0.20, 0.34, 0.26, 0.48, 0.62, 0.78];
    for (var i = 0; i < heights.length; i++) {
      final h = size.height * heights[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.42 + i * barW * 0.88, size.height * 0.78 - h, barW * 0.52, h),
          const Radius.circular(4),
        ),
        Paint()..color = accent.withValues(alpha: 0.40),
      );
    }
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.70)
      ..lineTo(size.width * 0.26, size.height * 0.54)
      ..lineTo(size.width * 0.42, size.height * 0.59)
      ..lineTo(size.width * 0.62, size.height * 0.38)
      ..lineTo(size.width * 0.90, size.height * 0.25);
    canvas.drawPath(
      path,
      Paint()
        ..color = accent.withValues(alpha: 0.80)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintAbstract(Canvas canvas, Size size, Color accent) {
    canvas.drawCircle(Offset(size.width * 0.22, size.height * 0.28), size.shortestSide * 0.22, Paint()..color = accent.withValues(alpha: 0.12));
    canvas.drawCircle(Offset(size.width * 0.68, size.height * 0.18), size.shortestSide * 0.18, Paint()..color = accent.withValues(alpha: 0.08));
    canvas.drawCircle(Offset(size.width * 0.80, size.height * 0.72), size.shortestSide * 0.28, Paint()..color = accent.withValues(alpha: 0.05));
  }
}

Color accentFromLabel(String label) {
  final hash = label.toLowerCase().hashCode;
  const colors = [
    Color(0xFF7B6FD4),
    Color(0xFF4EADA0),
    Color(0xFF6B9E5E),
    Color(0xFFB07C3A),
    Color(0xFF4A8DC4),
    Color(0xFFB05A7A),
  ];
  return colors[hash.abs() % colors.length];
}

bool _hasAny(String text, List<String> needles) => needles.any(text.contains);
