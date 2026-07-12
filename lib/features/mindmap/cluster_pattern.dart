import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cluster_pattern_library.dart';

class ClusterPatternSelection {
  const ClusterPatternSelection({
    required this.icons,
    required this.categoryIds,
    required this.seed,
    required this.isFallback,
  });

  final List<IconData> icons;
  final List<String> categoryIds;
  final int seed;
  final bool isFallback;

  String get signature => '${categoryIds.join('|')}:$seed:$isFallback';
}

ClusterPatternSelection resolveClusterPattern({
  required String label,
  required List<String> subtopics,
}) {
  final normalizedLabel = _normalize(label);
  final normalizedSubtopics = subtopics
      .map(_normalize)
      .where((v) => v.isNotEmpty);
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

  ranked.sort((a, b) => b.score.compareTo(a.score));
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
  final icons = isFallback ? abstractPatternIcons : _mergeIcons(matches);
  final seedText = [normalizedLabel, ...normalizedSubtopics].join('|');
  return ClusterPatternSelection(
    icons: icons,
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
    for (var i = 0; i < left.length - 1; i++) left.substring(i, i + 2),
  };
  final rightPairs = <String>{
    for (var i = 0; i < right.length - 1; i++) right.substring(i, i + 2),
  };
  final intersection = leftPairs.intersection(rightPairs).length;
  return (2 * intersection) / (leftPairs.length + rightPairs.length);
}

List<IconData> _mergeIcons(List<PatternCategoryDefinition> categories) {
  final merged = <IconData>[];
  final seen = <String>{};
  var iconIndex = 0;
  while (merged.length < 20) {
    var added = false;
    for (final category in categories) {
      if (iconIndex >= category.icons.length) continue;
      final icon = category.icons[iconIndex];
      final key = '${icon.fontFamily}:${icon.codePoint}';
      if (seen.add(key)) merged.add(icon);
      added = true;
      if (merged.length >= 20) break;
    }
    if (!added) break;
    iconIndex++;
  }
  return List.unmodifiable(merged);
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

enum PatternMotifSize { small, medium, large }

class ClusterPatternPlacement {
  const ClusterPatternPlacement({
    required this.icon,
    required this.center,
    required this.size,
    required this.sizeTier,
    required this.angle,
    required this.opacity,
  });

  final IconData icon;
  final Offset center;
  final double size;
  final PatternMotifSize sizeTier;
  final double angle;
  final double opacity;
}

const _cellWidth = 48.0;
const _cellHeight = 43.0;
const _maximumRotation = 8 * math.pi / 180;

@visibleForTesting
List<ClusterPatternPlacement> generateClusterPatternPlacements({
  required ClusterPatternSelection selection,
  required Size canvasSize,
  required double baseOpacity,
  PatternSafeRegion? contentSafeRegion,
}) {
  final random = math.Random(selection.seed);
  final iconBag = [...selection.icons]..shuffle(random);
  final safeRect = contentSafeRegion?.resolve(canvasSize);
  final placements = <ClusterPatternPlacement>[];
  var iconIndex = 0;
  final rows = ((canvasSize.height * 0.76) / _cellHeight).ceil() + 1;
  final columns = (canvasSize.width / _cellWidth).ceil() + 2;

  for (var row = 0; row < rows; row++) {
    final stagger = row.isOdd ? _cellWidth * 0.48 : 0.0;
    final rowDrift = random.nextDouble() * 14 - 7;
    for (var column = -1; column < columns; column++) {
      if (random.nextDouble() < 0.05) continue;

      final center = Offset(
        column * _cellWidth +
            stagger +
            rowDrift +
            _cellWidth / 2 +
            (random.nextDouble() * 14 - 7),
        row * _cellHeight +
            _cellHeight / 2 -
            8 +
            (random.nextDouble() * 11 - 5.5),
      );
      if (safeRect?.contains(center) ?? false) {
        if (random.nextDouble() < 0.40) continue;
      }
      if (iconIndex >= iconBag.length) {
        iconBag.shuffle(random);
        iconIndex = 0;
      }

      final opacityRoll = random.nextDouble();
      final opacityMultiplier = opacityRoll < 0.80
          ? 0.72
          : opacityRoll < 0.95
          ? 0.98
          : 1.24;
      final opacity = math.min(baseOpacity * opacityMultiplier, 0.14);
      final sizeRoll = random.nextDouble();
      final (sizeTier, baseSize) = sizeRoll < 0.70
          ? (PatternMotifSize.small, 20.0)
          : sizeRoll < 0.95
          ? (PatternMotifSize.medium, 26.0)
          : (PatternMotifSize.large, 35.0);
      final scale = 0.90 + random.nextDouble() * 0.20;
      final angle = (random.nextDouble() * 2 - 1) * _maximumRotation;

      placements.add(
        ClusterPatternPlacement(
          icon: iconBag[iconIndex++],
          center: center,
          size: baseSize * scale,
          sizeTier: sizeTier,
          angle: angle,
          opacity: opacity,
        ),
      );
    }
  }
  return List.unmodifiable(placements);
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
    final placements = generateClusterPatternPlacements(
      selection: selection,
      canvasSize: size,
      baseOpacity: baseOpacity,
      contentSafeRegion: contentSafeRegion,
    );
    for (final placement in placements) {
      _paintIcon(
        canvas,
        icon: placement.icon,
        center: placement.center,
        size: placement.size,
        angle: placement.angle,
        color: tone.withValues(alpha: placement.opacity),
      );
    }

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            surface.withValues(alpha: 0),
            surface.withValues(alpha: 0.16),
            surface,
          ],
          stops: const [0.34, 0.60, 0.91],
        ).createShader(Offset.zero & size),
    );
  }

  void _paintIcon(
    Canvas canvas, {
    required IconData icon,
    required Offset center,
    required double size,
    required double angle,
    required Color color,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          inherit: false,
          color: color,
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
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
