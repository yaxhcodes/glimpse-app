import 'package:flutter/material.dart';

import 'rediscover_journey_provider.dart';

enum JourneyMotif {
  software,
  nature,
  travel,
  food,
  philosophy,
  business,
  science,
  history,
  books,
  finance,
  photography,
  general,
}

class JourneyVisual {
  const JourneyVisual({
    required this.colors,
    required this.icon,
    required this.eyebrow,
    required this.motif,
    required this.foreground,
    required this.mutedForeground,
    required this.iconBackground,
    required this.iconForeground,
    required this.accentColor,
    required this.motifColor,
    required this.overlayColors,
  });

  final List<Color> colors;
  final IconData icon;
  final String eyebrow;
  final JourneyMotif motif;
  final Color foreground;
  final Color mutedForeground;
  final Color iconBackground;
  final Color iconForeground;
  final Color accentColor;
  final Color motifColor;
  final List<Color> overlayColors;
}

JourneyVisual visualForJourney(BuildContext context, RediscoverJourney journey) {
  final cs = Theme.of(context).colorScheme;
  final type = _motifForJourney(journey);
  final colors = _colorsFor(cs, type);

  return JourneyVisual(
    colors: colors,
    icon: _iconFor(type, journey.kind),
    eyebrow: _eyebrowFor(type, journey.kind),
    motif: type,
    foreground: _foregroundFor(cs, colors),
    mutedForeground: _mutedForegroundFor(cs, colors),
    iconBackground: _iconBackgroundFor(cs, colors),
    iconForeground: _iconForegroundFor(cs, colors),
    accentColor: _accentColorFor(cs, type),
    motifColor: _motifColorFor(cs, colors),
    overlayColors: _overlayFor(cs),
  );
}

/// Picks the motif by majority vote across the journey's items, so a single
/// tech-tagged save can't mislabel a whole philosophy journey as "Software".
///
/// The old version concatenated every item + the title and matched motifs in
/// priority order — and since `software` is checked first against the broadest
/// keyword net (ai, agent, code, github, mcp…), any journey that grazed one of
/// those words came back "Software". Voting per item makes the dominant content
/// win instead. Platform/source names carry no motif, so they don't vote.
JourneyMotif _motifForJourney(RediscoverJourney journey) {
  final votes = <JourneyMotif, int>{};
  var total = 0;
  for (final item in journey.items) {
    total++;
    final text = [
      item.url.category,
      ...item.url.tags.take(10),
    ].join(' ').toLowerCase();
    votes.update(_motifFor(text), (v) => v + 1, ifAbsent: () => 1);
  }

  // Strongest specific (non-general) motif among the items.
  JourneyMotif? best;
  var bestCount = 0;
  votes.forEach((motif, count) {
    if (motif == JourneyMotif.general) return;
    if (count > bestCount) {
      best = motif;
      bestCount = count;
    }
  });

  // Only let a specific motif label the journey if it represents a real share
  // of the items — otherwise one off-topic save (e.g. a lone AI link inside an
  // Agriculture cluster) hijacks the eyebrow. Below the bar, defer to the
  // title's own wording, then to neutral.
  final threshold = total <= 3 ? 2 : (total * 0.34).ceil();
  if (best != null && bestCount >= threshold) {
    return best!;
  }
  return _motifFor(journey.title.toLowerCase());
}

JourneyMotif _motifFor(String text) {
  if (_has(text, const [
    'ai',
    'agent',
    'llm',
    'openai',
    'claude',
    'flutter',
    'code',
    'software',
    'developer',
    'terminal',
    'github',
    'mcp',
  ])) {
    return JourneyMotif.software;
  }
  if (_has(text, const [
    'trek',
    'hike',
    'trail',
    'camp',
    'kyoto',
    'japan',
    'trip',
    'travel',
    'mountain',
    'route',
  ])) {
    return JourneyMotif.travel;
  }
  if (_has(text, const [
    'wildlife',
    'forest',
    'nature',
    'bird',
    'animal',
    'garden',
    'plant',
    'ecology',
    'agriculture',
    'farming',
    'crop',
    'soil',
    'harvest',
    'agritech',
  ])) {
    return JourneyMotif.nature;
  }
  if (_has(text, const [
    'recipe',
    'cook',
    'food',
    'meal',
    'bowl',
    'kitchen',
    'ramen',
    'tea',
  ])) {
    return JourneyMotif.food;
  }
  if (_has(text, const [
    'philosophy',
    'stoicism',
    'stoic',
    'gita',
    'meaning',
    'ethics',
  ])) {
    return JourneyMotif.philosophy;
  }
  if (_has(text, const [
    'startup',
    'business',
    'growth',
    'marketing',
    'founder',
    'portfolio',
    'career',
  ])) {
    return JourneyMotif.business;
  }
  if (_has(text, const [
    'science',
    'biology',
    'space',
    'physics',
    'research',
    'medical',
    'chemistry',
  ])) {
    return JourneyMotif.science;
  }
  if (_has(text, const [
    'history',
    'ancient',
    'museum',
    'architecture',
    'heritage',
    'temple',
  ])) {
    return JourneyMotif.history;
  }
  if (_has(text, const ['book', 'read', 'literature', 'essay', 'writing'])) {
    return JourneyMotif.books;
  }
  if (_has(text, const ['finance', 'invest', 'stock', 'market', 'money'])) {
    return JourneyMotif.finance;
  }
  if (_has(text, const ['photo', 'camera', 'photography', 'visual'])) {
    return JourneyMotif.photography;
  }
  return JourneyMotif.general;
}

List<Color> _colorsFor(ColorScheme cs, JourneyMotif motif) {
  final isDark = cs.brightness == Brightness.dark;
  final semantic = switch (motif) {
    JourneyMotif.software => isDark
        ? const [Color(0xFF203A55), Color(0xFF3D668A)]
        : const [Color(0xFFD8EAF7), Color(0xFFBFD7EA)],
    JourneyMotif.nature => isDark
        ? const [Color(0xFF274D37), Color(0xFF6F8F62)]
        : const [Color(0xFFDDE8D4), Color(0xFFC4D8B8)],
    JourneyMotif.travel => isDark
        ? const [Color(0xFF6D4D35), Color(0xFFC08A56)]
        : const [Color(0xFFF2DEC8), Color(0xFFDAB98E)],
    JourneyMotif.food => isDark
        ? const [Color(0xFF7A4A25), Color(0xFFD18B4B)]
        : const [Color(0xFFF3D6C3), Color(0xFFE5B48A)],
    JourneyMotif.philosophy => isDark
        ? const [Color(0xFF27231F), Color(0xFF866E49)]
        : const [Color(0xFFE2DED6), Color(0xFFC5B79D)],
    JourneyMotif.business => isDark
        ? const [Color(0xFF27313D), Color(0xFF657384)]
        : const [Color(0xFFE0E5EA), Color(0xFFC3CBD3)],
    JourneyMotif.science => isDark
        ? const [Color(0xFF234B5E), Color(0xFF76AFC2)]
        : const [Color(0xFFD7EEF3), Color(0xFFB7DDE6)],
    JourneyMotif.history => isDark
        ? const [Color(0xFF7A6241), Color(0xFFC7A675)]
        : const [Color(0xFFF0E1C8), Color(0xFFD8C29D)],
    JourneyMotif.books => isDark
        ? const [Color(0xFF443B5A), Color(0xFF8D7DAD)]
        : const [Color(0xFFE4DFF1), Color(0xFFC9BFDD)],
    JourneyMotif.finance => isDark
        ? const [Color(0xFF27463E), Color(0xFF7D946D)]
        : const [Color(0xFFDDE7D8), Color(0xFFC6D4BA)],
    JourneyMotif.photography => isDark
        ? const [Color(0xFF343944), Color(0xFF7F8796)]
        : const [Color(0xFFE1E3E8), Color(0xFFC7CCD5)],
    JourneyMotif.general => isDark
        ? const [Color(0xFF3C4858), Color(0xFF6D7B8C)]
        : const [Color(0xFFE0E5EA), Color(0xFFC8D0D9)],
  };
  final material = switch (motif) {
    JourneyMotif.software => [cs.primaryContainer, cs.primary],
    JourneyMotif.nature => [cs.secondaryContainer, cs.secondary],
    JourneyMotif.travel => [cs.tertiaryContainer, cs.tertiary],
    JourneyMotif.food => [cs.tertiaryContainer, cs.tertiary],
    JourneyMotif.philosophy => [cs.surfaceContainerHighest, cs.tertiary],
    JourneyMotif.business => [cs.surfaceContainerHigh, cs.primary],
    JourneyMotif.science => [cs.primaryContainer, cs.secondary],
    JourneyMotif.history => [cs.tertiaryContainer, cs.tertiary],
    JourneyMotif.books => [cs.secondaryContainer, cs.primary],
    JourneyMotif.finance => [cs.secondaryContainer, cs.secondary],
    JourneyMotif.photography => [cs.surfaceContainerHighest, cs.primary],
    JourneyMotif.general => [cs.surfaceContainerHigh, cs.primary],
  };

  final base = [
    Color.lerp(material[0], semantic[0], isDark ? 0.72 : 0.48)!,
    Color.lerp(material[1], semantic[1], isDark ? 0.58 : 0.34)!,
  ];
  if (isDark) return base;
  // Light mode: lift the gradient toward the theme surface so the cards read as
  // soft category tints that harmonize with the near-white list cards below,
  // instead of sitting on top as a heavier, darker block.
  // Lift hard toward the surface — the deeper bottom-right stop gets the most
  // so the gradient loses its darker, grayer corner and stays light and airy.
  return [
    Color.lerp(base[0], cs.surface, 0.64)!,
    Color.lerp(base[1], cs.surface, 0.62)!,
  ];
}

Color _foregroundFor(ColorScheme cs, List<Color> colors) {
  // Light mode: a refined neutral charcoal rather than a hard near-black, so
  // the title reads softer while staying high-contrast on the pastel card.
  return cs.brightness == Brightness.dark
      ? Colors.white
      : Color.lerp(colors.first, const Color(0xFF22202A), 0.82)!;
}

Color _mutedForegroundFor(ColorScheme cs, List<Color> colors) {
  // Pulled a touch darker in light mode so the eyebrow / metadata stay legible
  // instead of washing out against the lighter card.
  return cs.brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.72)
      : Color.lerp(colors.first, const Color(0xFF2A333D), 0.78)!;
}

Color _iconBackgroundFor(ColorScheme cs, List<Color> colors) {
  return cs.brightness == Brightness.dark
      ? Color.lerp(colors.first, colors.last, 0.34)!.withValues(alpha: 0.30)
      : Color.lerp(colors.first, Colors.white, 0.44)!.withValues(alpha: 0.42);
}

Color _iconForegroundFor(ColorScheme cs, List<Color> colors) {
  return cs.brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.82)
      : Color.lerp(colors.last, const Color(0xFF111827), 0.72)!;
}

Color _accentColorFor(ColorScheme cs, JourneyMotif motif) {
  // Maps each journey motif to a Material 3 tonal role for consistent,
  // scheme-aware tinting of the fused background icon.
  return switch (motif) {
    JourneyMotif.software => cs.primary,
    JourneyMotif.nature => cs.secondary,
    JourneyMotif.travel => cs.tertiary,
    JourneyMotif.food => cs.tertiary,
    JourneyMotif.philosophy => cs.secondary,
    JourneyMotif.business => cs.primary,
    JourneyMotif.science => cs.secondary,
    JourneyMotif.history => cs.tertiary,
    JourneyMotif.books => cs.secondary,
    JourneyMotif.finance => cs.secondary,
    JourneyMotif.photography => cs.primary,
    JourneyMotif.general => cs.primary,
  };
}

Color _motifColorFor(ColorScheme cs, List<Color> colors) {
  // Light mode: a category-tinted motif with enough tone to read as texture on
  // the now-brighter card, but soft (low opacity) so it never looks like hard
  // lines. The deeper gradient color carries the category hue.
  final lightMotif = Color.lerp(
    colors.last,
    const Color(0xFF111827),
    0.38,
  )!;
  return cs.brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.024)
      : lightMotif.withValues(alpha: 0.10);
}

List<Color> _overlayFor(ColorScheme cs) {
  return cs.brightness == Brightness.dark
      ? [
          Colors.black.withValues(alpha: 0.02),
          Colors.black.withValues(alpha: 0.14),
        ]
      : [
          Colors.white.withValues(alpha: 0.18),
          Colors.white.withValues(alpha: 0.04),
        ];
}

IconData _iconFor(JourneyMotif motif, RediscoverJourneyKind kind) {
  return switch (motif) {
    JourneyMotif.software => Icons.terminal_rounded,
    JourneyMotif.nature => Icons.eco_rounded,
    JourneyMotif.travel => Icons.explore_rounded,
    JourneyMotif.food => Icons.dinner_dining_rounded,
    JourneyMotif.philosophy => Icons.psychology_rounded,
    JourneyMotif.business => Icons.insights_rounded,
    JourneyMotif.science => Icons.science_rounded,
    JourneyMotif.history => Icons.account_balance_rounded,
    JourneyMotif.books => Icons.auto_stories_rounded,
    JourneyMotif.finance => Icons.savings_rounded,
    JourneyMotif.photography => Icons.camera_alt_rounded,
    JourneyMotif.general => switch (kind) {
      RediscoverJourneyKind.forgottenGems => Icons.diamond_rounded,
      RediscoverJourneyKind.neverOpened => Icons.mark_email_unread_rounded,
      RediscoverJourneyKind.onThisDay => Icons.history_edu_rounded,
      RediscoverJourneyKind.memoryGoal => Icons.route_rounded,
      _ => Icons.auto_awesome_rounded,
    },
  };
}

String _eyebrowFor(JourneyMotif motif, RediscoverJourneyKind kind) {
  return switch (motif) {
    JourneyMotif.software => 'Software',
    JourneyMotif.nature => 'Nature',
    JourneyMotif.travel => 'Travel',
    JourneyMotif.food => 'Food',
    JourneyMotif.philosophy => 'Philosophy',
    JourneyMotif.business => 'Business',
    JourneyMotif.science => 'Science',
    JourneyMotif.history => 'History',
    JourneyMotif.books => 'Reading',
    JourneyMotif.finance => 'Finance',
    JourneyMotif.photography => 'Photography',
    JourneyMotif.general => switch (kind) {
      RediscoverJourneyKind.forgottenGems => 'Worth a Look',
      RediscoverJourneyKind.neverOpened => 'Unopened',
      RediscoverJourneyKind.onThisDay => 'From Before',
      RediscoverJourneyKind.memoryGoal => 'Rediscover',
      _ => 'For You',
    },
  };
}

bool _has(String text, List<String> needles) {
  for (final needle in needles) {
    if (text.contains(needle)) return true;
  }
  return false;
}

class JourneyMotifPainter extends CustomPainter {
  const JourneyMotifPainter({
    required this.motif,
    required this.color,
    this.variant = 0,
  });

  final JourneyMotif motif;
  final Color color;
  final int variant;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75
      ..strokeCap = StrokeCap.round;

    switch (motif) {
      case JourneyMotif.software:
        _grid(canvas, size, paint);
        break;
      case JourneyMotif.nature:
        _leaves(canvas, size, paint);
        break;
      case JourneyMotif.travel:
        _mountains(canvas, size, paint);
        break;
      case JourneyMotif.food:
        _rings(canvas, size, paint);
        break;
      case JourneyMotif.philosophy:
        _geometry(canvas, size, paint);
        break;
      case JourneyMotif.business:
      case JourneyMotif.finance:
        _chart(canvas, size, paint);
        break;
      case JourneyMotif.science:
        _molecules(canvas, size, paint);
        break;
      case JourneyMotif.history:
        _arches(canvas, size, paint);
        break;
      case JourneyMotif.books:
        _pages(canvas, size, paint);
        break;
      case JourneyMotif.photography:
        _frames(canvas, size, paint);
        break;
      case JourneyMotif.general:
        _geometry(canvas, size, paint);
        break;
    }
  }

  void _grid(Canvas canvas, Size size, Paint paint) {
    final start = variant.isEven ? size.width * 0.54 : size.width * 0.48;
    for (var x = start; x < size.width; x += 26) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = variant.isEven ? 18.0 : 28.0; y < size.height; y += 26) {
      canvas.drawLine(Offset(start - 4, y), Offset(size.width, y), paint);
    }
  }

  void _leaves(Canvas canvas, Size size, Paint paint) {
    final shift = variant.isEven ? 0.0 : size.height * 0.08;
    for (var i = 0; i < 4; i++) {
      final dx = size.width * (0.58 + i * 0.09);
      final dy = size.height * (0.15 + i * 0.16) + shift;
      final rect = Rect.fromCenter(center: Offset(dx, dy), width: 36, height: 14);
      canvas.drawOval(rect, paint);
      canvas.drawLine(Offset(dx - 18, dy), Offset(dx + 18, dy), paint);
    }
  }

  void _mountains(Canvas canvas, Size size, Paint paint) {
    final lift = variant.isEven ? 0.0 : size.height * 0.05;
    final path = Path()
      ..moveTo(size.width * 0.50, size.height * 0.78)
      ..lineTo(size.width * 0.60, size.height * 0.48 + lift)
      ..lineTo(size.width * 0.72, size.height * 0.68)
      ..lineTo(size.width * 0.84, size.height * 0.42 + lift)
      ..lineTo(size.width, size.height * 0.74);
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(size.width * 0.48, size.height * 0.86),
      Offset(size.width, size.height * 0.86),
      paint,
    );
  }

  void _rings(Canvas canvas, Size size, Paint paint) {
    final center = Offset(
      size.width * (variant.isEven ? 0.82 : 0.72),
      size.height * (variant.isEven ? 0.34 : 0.42),
    );
    for (final radius in const [22.0, 42.0, 62.0]) {
      canvas.drawCircle(center, radius, paint);
    }
  }

  void _geometry(Canvas canvas, Size size, Paint paint) {
    final rect = Rect.fromLTWH(
      size.width * (variant.isEven ? 0.58 : 0.50),
      variant.isEven ? 24 : 42,
      88,
      88,
    );
    canvas.drawRect(rect, paint);
    canvas.drawCircle(Offset(size.width * 0.78, size.height * 0.62), 42, paint);
  }

  void _chart(Canvas canvas, Size size, Paint paint) {
    for (var i = 0; i < 4; i++) {
      final left = size.width * (0.56 + i * 0.08);
      final top = size.height * (variant.isEven ? 0.64 - i * 0.08 : 0.58 - i * 0.06);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, 14, size.height - top - 22),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  void _molecules(Canvas canvas, Size size, Paint paint) {
    final dx = variant.isEven ? 0.0 : -size.width * 0.08;
    final points = [
      Offset(size.width * 0.60 + dx, size.height * 0.34),
      Offset(size.width * 0.75 + dx, size.height * 0.22),
      Offset(size.width * 0.86 + dx, size.height * 0.44),
      Offset(size.width * 0.70 + dx, size.height * 0.60),
    ];
    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
    for (final point in points) {
      canvas.drawCircle(point, 6, paint);
    }
  }

  void _arches(Canvas canvas, Size size, Paint paint) {
    for (var i = 0; i < 3; i++) {
      final rect = Rect.fromLTWH(
        size.width * ((variant.isEven ? 0.54 : 0.48) + i * 0.12),
        variant.isEven ? 36 : 48,
        54,
        96,
      );
      canvas.drawArc(rect, 3.14, 3.14, false, paint);
      canvas.drawLine(rect.bottomLeft, rect.topLeft + const Offset(0, 27), paint);
      canvas.drawLine(rect.bottomRight, rect.topRight + const Offset(0, 27), paint);
    }
  }

  void _pages(Canvas canvas, Size size, Paint paint) {
    for (var i = 0; i < 4; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * ((variant.isEven ? 0.56 : 0.50) + i * 0.06),
            (variant.isEven ? 30 : 42) + i * 9,
            74,
            92,
          ),
          const Radius.circular(8),
        ),
        paint,
      );
    }
  }

  void _frames(Canvas canvas, Size size, Paint paint) {
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * ((variant.isEven ? 0.54 : 0.48) + i * 0.08),
            (variant.isEven ? 28 : 42) + i * 18,
            88,
            54,
          ),
          const Radius.circular(10),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant JourneyMotifPainter oldDelegate) {
    return oldDelegate.motif != motif ||
        oldDelegate.color != color ||
        oldDelegate.variant != variant;
  }
}
