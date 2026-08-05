import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cluster_pattern_library.dart';

class ClusterPatternSelection {
  const ClusterPatternSelection({
    required this.recipe,
    required this.categoryIds,
    required this.seed,
    required this.isFallback,
  });

  final PatternRecipe recipe;
  final List<String> categoryIds;
  final int seed;
  final bool isFallback;

  String get signature =>
      '${categoryIds.join('|')}:${recipe.signature}:$seed:$isFallback';
}

ClusterPatternSelection resolveClusterPattern({
  required String label,
  required List<String> subtopics,
}) {
  final normalizedLabel = _normalize(label);
  final normalizedSubtopics = subtopics
      .map(_normalize)
      .where((value) => value.isNotEmpty);
  final ranked = <({PatternCategoryDefinition category, int score})>[];

  for (final category in clusterPatternLibrary) {
    final labelScore = _sourceScore(normalizedLabel, category) * 4;
    final subtopicScore = normalizedSubtopics.fold<int>(
      0,
      (score, subtopic) => score + _sourceScore(subtopic, category),
    );
    final total = labelScore + subtopicScore;
    if (total > 0) ranked.add((category: category, score: total));
  }

  ranked.sort((left, right) => right.score.compareTo(left.score));
  var matches = <PatternCategoryDefinition>[];
  if (ranked.isNotEmpty) {
    final strongest = ranked.first.score;
    matches.add(ranked.first.category);
    for (final candidate in ranked.skip(1)) {
      if (matches.length >= 2) break;
      if (candidate.score >= 8 && candidate.score >= strongest * 0.38) {
        matches.add(candidate.category);
      }
    }
  } else {
    final semanticMatch = _closestSemanticCategory(
      [normalizedLabel, ...normalizedSubtopics].join(' '),
    );
    if (semanticMatch != null) matches = [semanticMatch];
  }

  final isFallback = matches.isEmpty;
  final seedText = [normalizedLabel, ...normalizedSubtopics].join('|');
  return ClusterPatternSelection(
    recipe: isFallback ? abstractPatternRecipe : matches.first.recipe,
    categoryIds: isFallback
        ? const ['abstract']
        : [for (final category in matches) category.id],
    seed: _stableHash(seedText),
    isFallback: isFallback,
  );
}

int _sourceScore(String source, PatternCategoryDefinition category) {
  if (source.isEmpty) return 0;
  final sourceTokens = _tokens(source);
  var best = 0;

  for (final rawAlias in [category.id, ...category.aliases]) {
    final alias = _normalize(rawAlias);
    if (source == alias) return 24;
    if (_containsPhrase(source, alias)) {
      best = math.max(best, alias.contains(' ') ? 16 : 12);
      continue;
    }

    final aliasTokens = _tokens(alias);
    final overlap = aliasTokens.intersection(sourceTokens).length;
    if (overlap > 0) {
      final coverage = overlap / aliasTokens.length;
      best = math.max(best, (4 + coverage * 6).round());
    }
  }
  return best;
}

bool _containsPhrase(String source, String phrase) {
  return ' $source '.contains(' $phrase ');
}

PatternCategoryDefinition? _closestSemanticCategory(String source) {
  final sourceTokens = _tokens(source);
  if (sourceTokens.isEmpty) return null;

  PatternCategoryDefinition? closest;
  var closestScore = 0.0;
  for (final category in clusterPatternLibrary) {
    for (final alias in category.aliases) {
      for (final sourceToken in sourceTokens) {
        for (final aliasToken in _tokens(_normalize(alias))) {
          final score = _bigramSimilarity(sourceToken, aliasToken);
          if (score > closestScore) {
            closestScore = score;
            closest = category;
          }
        }
      }
    }
  }
  return closestScore >= 0.54 ? closest : null;
}

double _bigramSimilarity(String left, String right) {
  if (left == right) return 1;
  if (left.length < 3 || right.length < 3) return 0;
  final leftPairs = <String>{
    for (var index = 0; index < left.length - 1; index++)
      left.substring(index, index + 2),
  };
  final rightPairs = <String>{
    for (var index = 0; index < right.length - 1; index++)
      right.substring(index, index + 2),
  };
  final intersection = leftPairs.intersection(rightPairs).length;
  return (2 * intersection) / (leftPairs.length + rightPairs.length);
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp('[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

Set<String> _tokens(String value) {
  return {
    for (final word in value.split(' '))
      if (word.length >= 2) _stem(word),
  };
}

String _stem(String word) {
  const replacements = {
    'healthy': 'health',
    'movies': 'movie',
    'recipes': 'recipe',
    'books': 'book',
    'gadgets': 'gadget',
    'devices': 'device',
    'languages': 'language',
    'podcasts': 'podcast',
  };
  final replacement = replacements[word];
  if (replacement != null) return replacement;
  if (word.length > 4 && word.endsWith('s')) {
    return word.substring(0, word.length - 1);
  }
  return word;
}

int _stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

class PatternSafeRegion {
  const PatternSafeRegion({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  }) : assert(left >= 0 && left <= 1),
       assert(top >= 0 && top <= 1),
       assert(right >= 0 && right <= 1),
       assert(bottom >= 0 && bottom <= 1),
       assert(left <= right),
       assert(top <= bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  Rect resolve(Size size) {
    return Rect.fromLTRB(
      size.width * left,
      size.height * top,
      size.width * right,
      size.height * bottom,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PatternSafeRegion &&
        other.left == left &&
        other.top == top &&
        other.right == right &&
        other.bottom == bottom;
  }

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

class ClusterPatternPainter extends CustomPainter {
  const ClusterPatternPainter({
    required this.selection,
    required this.tone,
    required this.surface,
    required this.baseOpacity,
    required this.contentSafeRegion,
  });

  final ClusterPatternSelection selection;
  final Color tone;
  final Color surface;
  final double baseOpacity;
  final PatternSafeRegion contentSafeRegion;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final random = math.Random(selection.seed);
    final recipe = selection.recipe;
    final strokeOpacity = math.min(
      baseOpacity * (0.76 + recipe.density * 0.32),
      0.12,
    );
    final stroke = Paint()
      ..color = tone.withValues(alpha: strokeOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.72 + recipe.scale * 0.42
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = tone.withValues(alpha: strokeOpacity * 0.32)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    switch (recipe.grammar) {
      case PatternGrammar.circuitGrid:
        _paintCircuitGrid(canvas, size, recipe, random, stroke, fill);
      case PatternGrammar.dataGraph:
        _paintDataGraph(canvas, size, recipe, random, stroke, fill);
      case PatternGrammar.topographicMesh:
        _paintTopographicMesh(canvas, size, recipe, random, stroke);
      case PatternGrammar.waveform:
        _paintWaveform(canvas, size, recipe, random, stroke);
      case PatternGrammar.synthwave:
        _paintSynthwave(canvas, size, recipe, random, stroke, fill);
      case PatternGrammar.orbital:
        _paintOrbital(canvas, size, recipe, random, stroke, fill);
      case PatternGrammar.kineticTrack:
        _paintKineticTrack(canvas, size, recipe, random, stroke);
      case PatternGrammar.editorialGrid:
        _paintEditorialGrid(canvas, size, recipe, random, stroke, fill);
      case PatternGrammar.concentricGeometry:
        _paintConcentricGeometry(canvas, size, recipe, random, stroke, fill);
      case PatternGrammar.apertureFrames:
        _paintApertureFrames(canvas, size, recipe, random, stroke, fill);
      case PatternGrammar.ribbonMesh:
        _paintRibbonMesh(canvas, size, recipe, random, stroke, fill);
      case PatternGrammar.contourRings:
        _paintContourRings(canvas, size, recipe, random, stroke);
      case PatternGrammar.architecturalBlueprint:
        _paintArchitecturalBlueprint(canvas, size, recipe, random, stroke);
      case PatternGrammar.organicCells:
        _paintOrganicCells(canvas, size, recipe, random, stroke, fill);
      case PatternGrammar.sparseGeometry:
        _paintSparseGeometry(canvas, size, recipe, random, stroke, fill);
    }
    _paintContentFade(canvas, size);
    canvas.restore();
  }

  Offset _focus(Size size, PatternComposition composition) {
    return switch (composition) {
      PatternComposition.fullBleed => Offset(
        size.width * 0.52,
        size.height * 0.30,
      ),
      PatternComposition.cornerFocus => Offset(
        size.width * 0.82,
        size.height * 0.20,
      ),
      PatternComposition.diagonalFlow => Offset(
        size.width * 0.70,
        size.height * 0.24,
      ),
      PatternComposition.horizon => Offset(
        size.width * 0.50,
        size.height * 0.40,
      ),
      PatternComposition.centralFocus => Offset(
        size.width * 0.62,
        size.height * 0.28,
      ),
      PatternComposition.edgeWeighted => Offset(
        size.width * 0.88,
        size.height * 0.30,
      ),
    };
  }

  void _paintCircuitGrid(
    Canvas canvas,
    Size size,
    PatternRecipe recipe,
    math.Random random,
    Paint stroke,
    Paint fill,
  ) {
    final cell = 25.0 * recipe.scale;
    final count = 8 + (recipe.density * 11).round();
    final focus = _focus(size, recipe.composition);
    for (var index = 0; index < count; index++) {
      final start = Offset(
        _mixedCoordinate(random, size.width, focus.dx, recipe.composition),
        random.nextDouble() * size.height * 0.68,
      );
      final horizontal = random.nextBool() ? 1.0 : -1.0;
      final vertical = random.nextBool() ? 1.0 : -1.0;
      final path = Path()..moveTo(start.dx, start.dy);
      var point = start;
      for (var segment = 0; segment < 2 + random.nextInt(3); segment++) {
        point = segment.isEven
            ? Offset(point.dx + horizontal * cell, point.dy)
            : Offset(point.dx, point.dy + vertical * cell * 0.72);
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, stroke);
      canvas.drawCircle(start, 2.1 * recipe.scale, fill);
      if (index.isEven) canvas.drawCircle(point, 3.4 * recipe.scale, stroke);
    }
  }

  void _paintDataGraph(
    Canvas canvas,
    Size size,
    PatternRecipe recipe,
    math.Random random,
    Paint stroke,
    Paint fill,
  ) {
    final graphTop = size.height * 0.08;
    final graphBottom = size.height * 0.63;
    final gridPaint = Paint()
      ..color = stroke.color.withValues(alpha: stroke.color.a * 0.38)
      ..strokeWidth = 0.65;
    for (var index = 1; index < 5; index++) {
      final y = graphTop + (graphBottom - graphTop) * index / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final seriesCount = 2 + (recipe.density * 2).round();
    for (var series = 0; series < seriesCount; series++) {
      final path = Path();
      Offset? previous;
      for (var index = 0; index < 7; index++) {
        final x = size.width * index / 6;
        final trend = recipe.composition == PatternComposition.diagonalFlow
            ? (1 - index / 6) * size.height * 0.18
            : 0.0;
        final y =
            graphTop +
            trend +
            random.nextDouble() * (graphBottom - graphTop) * 0.68 +
            series * 3;
        final point = Offset(x, y);
        if (previous == null) {
          path.moveTo(point.dx, point.dy);
        } else {
          final midpoint = (previous.dx + point.dx) / 2;
          path.cubicTo(
            midpoint,
            previous.dy,
            midpoint,
            point.dy,
            point.dx,
            point.dy,
          );
        }
        previous = point;
        if (index == 2 || index == 5) canvas.drawCircle(point, 2.4, fill);
      }
      canvas.drawPath(path, stroke);
    }
  }

  void _paintTopographicMesh(
    Canvas canvas,
    Size size,
    PatternRecipe recipe,
    math.Random random,
    Paint stroke,
  ) {
    final count = 7 + (recipe.density * 9).round();
    final spacing = size.height * 0.72 / count;
    final phase = random.nextDouble() * math.pi * 2;
    for (var row = -2; row < count; row++) {
      final path = Path();
      for (var x = -12.0; x <= size.width + 12; x += 8) {
        final diagonal = recipe.composition == PatternComposition.diagonalFlow
            ? x * 0.10
            : 0.0;
        final wave =
            math.sin(x / (31 * recipe.scale) + phase + row * 0.52) *
            (8 + recipe.density * 9);
        final secondary = math.cos(x / 18 + row) * 3.5;
        final y = row * spacing + 12 + diagonal + wave + secondary;
        if (x == -12) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, stroke);
    }
  }

  void _paintWaveform(
    Canvas canvas,
    Size size,
    PatternRecipe recipe,
    math.Random random,
    Paint stroke,
  ) {
    final count = 3 + (recipe.density * 4).round();
    final center = _focus(size, recipe.composition);
    for (var row = 0; row < count; row++) {
      final path = Path();
      final amplitude = (8 + row * 3.5) * recipe.scale;
      final frequency = 17 + random.nextDouble() * 15;
      for (var x = -8.0; x <= size.width + 8; x += 5) {
        final envelope = math.sin(math.pi * x / size.width).abs();
        final wave =
            math.sin(x / frequency + row * 0.84) * amplitude * envelope;
        final y = center.dy + (row - count / 2) * 12 + wave;
        if (x == -8) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, stroke);
    }
  }

  void _paintSynthwave(
    Canvas canvas,
    Size size,
    PatternRecipe recipe,
    math.Random random,
    Paint stroke,
    Paint fill,
  ) {
    final horizon = size.height * (0.33 + random.nextDouble() * 0.08);
    final vanishing = Offset(
      size.width * (0.42 + random.nextDouble() * 0.22),
      horizon,
    );
    final rays = 7 + (recipe.density * 6).round();
    for (var index = 0; index <= rays; index++) {
      final targetX = size.width * index / rays;
      canvas.drawLine(vanishing, Offset(targetX, size.height * 0.78), stroke);
    }
    for (var index = 1; index < 7; index++) {
      final progress = index / 7;
      final y = horizon + math.pow(progress, 1.7) * size.height * 0.43;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), stroke);
    }
    final frameCount = 2 + (recipe.density * 2).round();
    for (var index = 0; index < frameCount; index++) {
      final width = 28.0 + random.nextDouble() * 32;
      final rect = Rect.fromCenter(
        center: Offset(
          random.nextDouble() * size.width,
          12 + random.nextDouble() * horizon * 0.75,
        ),
        width: width,
        height: width * (0.55 + random.nextDouble() * 0.3),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        index.isEven ? stroke : fill,
      );
    }
  }

  void _paintOrbital(
    Canvas canvas,
    Size size,
    PatternRecipe recipe,
    math.Random random,
    Paint stroke,
    Paint fill,
  ) {
    final center = _focus(size, recipe.composition);
    final count = 4 + (recipe.density * 4).round();
    for (var index = 0; index < count; index++) {
      final radius = (24 + index * 14) * recipe.scale;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-0.55 + index * 0.22 + random.nextDouble() * 0.1);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 2,
          height: radius * (0.72 + random.nextDouble() * 0.35),
        ),
        stroke,
      );
      final angle = random.nextDouble() * math.pi * 2;
      canvas.drawCircle(
        Offset(math.cos(angle) * radius, math.sin(angle) * radius * 0.45),
        2 + index % 2,
        fill,
      );
      canvas.restore();
    }
  }

  void _paintKineticTrack(
    Canvas canvas,
    Size size,
    PatternRecipe recipe,
    math.Random random,
    Paint stroke,
  ) {
    final count = 4 + (recipe.density * 5).round();
    final rise = recipe.composition == PatternComposition.horizon ? 0.12 : 0.34;
    for (var lane = 0; lane < count; lane++) {
      final offset = lane * 10.0 * recipe.scale;
      final path = Path()
        ..moveTo(-18, size.height * 0.68 + offset)
        ..cubicTo(
          size.width * 0.24,
          size.height * (0.70 - rise) + offset,
          size.width * 0.62,
          size.height * (0.18 + random.nextDouble() * 0.08) + offset * 0.25,
          size.width + 20,
          size.height * 0.16 + offset * 0.15,
        );
      canvas.drawPath(path, stroke);
    }
    for (var index = 0; index < 7; index++) {
      final x = size.width * (0.15 + index * 0.13);
      final y = size.height * (0.57 - index * 0.055);
      canvas.drawLine(Offset(x, y), Offset(x + 8, y - 8), stroke);
    }
  }

  void _paintEditorialGrid(
    Canvas canvas,
    Size size,
    PatternRecipe recipe,
    math.Random random,
    Paint stroke,
    Paint fill,
  ) {
    final focus = _focus(size, recipe.composition);
    final columns = 3 + (recipe.density * 3).round();
    final columnWidth = size.width / columns;
    for (var column = 0; column < columns; column++) {
      final left = column * columnWidth + 5;
      final top = random.nextDouble() * size.height * 0.24;
      final height = 24 + random.nextDouble() * size.height * 0.35;
      final rect = Rect.fromLTWH(left, top, columnWidth - 10, height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        column.isEven ? stroke : fill,
      );
      for (var line = 1; line < 4; line++) {
        final y = rect.top + rect.height * line / 5;
        canvas.drawLine(
          Offset(rect.left + 6, y),
          Offset(rect.right - 6 - line * 2, y),
          stroke,
        );
      }
    }
    canvas.drawLine(
      Offset(focus.dx - 42, focus.dy + 42),
      Offset(focus.dx + 58, focus.dy + 42),
      stroke,
    );
  }

  void _paintConcentricGeometry(
    Canvas canvas,
    Size size,
    PatternRecipe recipe,
    math.Random random,
    Paint stroke,
    Paint fill,
  ) {
    final center = _focus(size, recipe.composition);
    final count = 5 + (recipe.density * 5).round();
    for (var index = 0; index < count; index++) {
      final radius = (14 + index * 13) * recipe.scale;
      final rect = Rect.fromCenter(
        center: center + Offset(index * 1.6, -index * 0.8),
        width: radius * 2,
        height: radius * (1.3 + random.nextDouble() * 0.45),
      );
      canvas.drawArc(
        rect,
        -math.pi * (0.86 + random.nextDouble() * 0.2),
        math.pi * (1.25 + random.nextDouble() * 0.55),
        false,
        stroke,
      );
    }
    canvas.drawCircle(center, 3.2, fill);
  }

  void _paintApertureFrames(
    Canvas canvas,
    Size size,
    PatternRecipe recipe,
    math.Random random,
    Paint stroke,
    Paint fill,
  ) {
    final center = _focus(size, recipe.composition);
    final count = 4 + (recipe.density * 3).round();
    for (var index = count; index >= 1; index--) {
      final width = (26 + index * 18) * recipe.scale;
      final rect = Rect.fromCenter(
        center: center + Offset(index * 2.5, -index * 1.5),
        width: width,
        height: width * (0.62 + random.nextDouble() * 0.18),
      );
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate((index - count / 2) * 0.055);
      canvas.translate(-rect.center.dx, -rect.center.dy);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(4 + index.toDouble())),
        stroke,
      );
      canvas.restore();
    }
    final marker = Rect.fromCenter(center: center, width: 18, height: 18);
    canvas.drawRect(marker, fill);
  }

  void _paintRibbonMesh(
    Canvas canvas,
    Size size,
    PatternRecipe recipe,
    math.Random random,
    Paint stroke,
    Paint fill,
  ) {
    final count = 3 + (recipe.density * 4).round();
    for (var index = 0; index < count; index++) {
      final startY = -16 + index * 18.0;
      final path = Path()
        ..moveTo(-20, startY)
        ..cubicTo(
          size.width * 0.28,
          size.height * (0.12 + random.nextDouble() * 0.28),
          size.width * 0.54,
          size.height * (0.02 + random.nextDouble() * 0.38),
          size.width + 20,
          size.height * (0.28 + index * 0.055),
        );
      final ribbon = Paint()
        ..color = fill.color.withValues(alpha: fill.color.a * 1.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (8 + index * 2.6) * recipe.scale
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, ribbon);
      canvas.drawPath(path, stroke);
    }
  }

  void _paintContourRings(
    Canvas canvas,
    Size size,
    PatternRecipe recipe,
    math.Random random,
    Paint stroke,
  ) {
    final center = _focus(size, recipe.composition);
    final rings = 5 + (recipe.density * 5).round();
    for (var ring = 1; ring <= rings; ring++) {
      final radius = ring * 11.5 * recipe.scale;
      final points = <Offset>[];
      for (var index = 0; index < 16; index++) {
        final angle = math.pi * 2 * index / 16;
        final variation = 0.84 + random.nextDouble() * 0.28;
        points.add(
          center +
              Offset(
                math.cos(angle) * radius * variation,
                math.sin(angle) * radius * variation * 0.72,
              ),
        );
      }
      final path = Path();
      for (var index = 0; index < points.length; index++) {
        final point = points[index];
        final next = points[(index + 1) % points.length];
        final midpoint = Offset(
          (point.dx + next.dx) / 2,
          (point.dy + next.dy) / 2,
        );
        if (index == 0) {
          path.moveTo(midpoint.dx, midpoint.dy);
        } else {
          path.quadraticBezierTo(point.dx, point.dy, midpoint.dx, midpoint.dy);
        }
      }
      path.close();
      canvas.drawPath(path, stroke);
    }
  }

  void _paintArchitecturalBlueprint(
    Canvas canvas,
    Size size,
    PatternRecipe recipe,
    math.Random random,
    Paint stroke,
  ) {
    final unit = 24.0 * recipe.scale;
    final xOffset = recipe.composition == PatternComposition.edgeWeighted
        ? size.width * 0.42
        : -unit;
    for (var x = xOffset; x < size.width + unit; x += unit) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height * 0.68), stroke);
    }
    for (var y = 8.0; y < size.height * 0.68; y += unit) {
      canvas.drawLine(Offset(xOffset, y), Offset(size.width, y), stroke);
    }
    final count = 3 + (recipe.density * 4).round();
    for (var index = 0; index < count; index++) {
      final left =
          math.max(0.0, xOffset) + random.nextDouble() * size.width * 0.58;
      final top = random.nextDouble() * size.height * 0.42;
      final rect = Rect.fromLTWH(
        left,
        top,
        unit * (1 + random.nextInt(2)),
        unit * (0.7 + random.nextDouble()),
      );
      canvas.drawRect(rect, stroke);
      canvas.drawLine(rect.topLeft, rect.bottomRight, stroke);
    }
  }

  void _paintOrganicCells(
    Canvas canvas,
    Size size,
    PatternRecipe recipe,
    math.Random random,
    Paint stroke,
    Paint fill,
  ) {
    final radius = 15.0 * recipe.scale;
    final horizontalStep = radius * 1.65;
    final verticalStep = radius * 1.45;
    final rows = (size.height * 0.7 / verticalStep).ceil() + 1;
    final columns = (size.width / horizontalStep).ceil() + 1;
    for (var row = -1; row < rows; row++) {
      for (var column = -1; column < columns; column++) {
        if (random.nextDouble() > 0.42 + recipe.density * 0.48) continue;
        final center = Offset(
          column * horizontalStep + (row.isOdd ? horizontalStep * 0.5 : 0),
          row * verticalStep,
        );
        final sides = 5 + random.nextInt(3);
        final path = Path();
        for (var side = 0; side < sides; side++) {
          final angle = math.pi * 2 * side / sides;
          final localRadius = radius * (0.78 + random.nextDouble() * 0.3);
          final point =
              center + Offset(math.cos(angle), math.sin(angle)) * localRadius;
          if (side == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
        canvas.drawPath(path, random.nextDouble() < 0.16 ? fill : stroke);
      }
    }
  }

  void _paintSparseGeometry(
    Canvas canvas,
    Size size,
    PatternRecipe recipe,
    math.Random random,
    Paint stroke,
    Paint fill,
  ) {
    final count = 3 + (recipe.density * 6).round();
    final focus = _focus(size, recipe.composition);
    for (var index = 0; index < count; index++) {
      final center = Offset(
        _mixedCoordinate(random, size.width, focus.dx, recipe.composition),
        random.nextDouble() * size.height * 0.58,
      );
      final extent = (10 + random.nextDouble() * 25) * recipe.scale;
      switch (index % 3) {
        case 0:
          canvas.drawCircle(center, extent, stroke);
        case 1:
          canvas.drawRect(
            Rect.fromCenter(
              center: center,
              width: extent * 1.6,
              height: extent,
            ),
            stroke,
          );
        case 2:
          final path = Path()
            ..moveTo(center.dx, center.dy - extent)
            ..lineTo(center.dx + extent, center.dy + extent)
            ..lineTo(center.dx - extent, center.dy + extent)
            ..close();
          canvas.drawPath(path, index == count - 1 ? fill : stroke);
      }
    }
  }

  double _mixedCoordinate(
    math.Random random,
    double extent,
    double focus,
    PatternComposition composition,
  ) {
    if (composition == PatternComposition.fullBleed) {
      return random.nextDouble() * extent;
    }
    final focused = focus + (random.nextDouble() * 2 - 1) * extent * 0.34;
    return focused.clamp(-extent * 0.1, extent * 1.1);
  }

  void _paintContentFade(Canvas canvas, Size size) {
    final safeRect = contentSafeRegion.resolve(size);
    canvas.drawRect(
      safeRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            surface.withValues(alpha: 0),
            surface.withValues(alpha: 0.58),
            surface,
          ],
          stops: const [0, 0.52, 0.88],
        ).createShader(safeRect),
    );
    final fadeRect = Offset.zero & size;
    canvas.drawRect(
      fadeRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            surface.withValues(alpha: 0),
            surface.withValues(alpha: 0.08),
            surface,
          ],
          stops: const [0.34, 0.62, 0.94],
        ).createShader(fadeRect),
    );
  }

  @override
  bool shouldRepaint(covariant ClusterPatternPainter oldDelegate) {
    return oldDelegate.selection.signature != selection.signature ||
        oldDelegate.tone != tone ||
        oldDelegate.surface != surface ||
        oldDelegate.baseOpacity != baseOpacity ||
        oldDelegate.contentSafeRegion != contentSafeRegion;
  }
}
