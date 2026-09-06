import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shared/theme/app_shapes.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/theme/topic_visual.dart';
import '../../shared/widgets/expressive_tap_scale.dart';
import '../../shared/widgets/surface_grain.dart';
import '../../shared/widgets/hyphenated_title.dart';
import 'rediscover_journey_provider.dart';

enum RediscoverArtworkTheme {
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
  fitness,
  music,
  film,
  design,
  home,
  fashion,
  general;

  String get assetPath => 'assets/rediscover/illustrations/$name.webp';
}

RediscoverArtworkTheme artworkThemeForJourney(
  RediscoverJourney journey, {
  String? displayTitle,
}) {
  // Prefer the topic the reader sees before broad or stale category metadata.
  for (final text in [
    displayTitle,
    journey.topicAnchor,
    journey.title,
    journey.categoryLabel,
  ].whereType<String>()) {
    final match = _artworkThemeForText(text.toLowerCase());
    if (match != null) return match;
  }
  final supporting = [
    for (final item in journey.items.take(5)) ...[
      item.url.title,
      item.url.category,
      ...item.url.effectiveCategories,
      ...item.url.tags,
    ],
  ].join(' ').toLowerCase();
  return _artworkThemeForText(supporting) ?? RediscoverArtworkTheme.general;
}

class RediscoverArtworkCard extends StatelessWidget {
  const RediscoverArtworkCard({
    super.key,
    required this.journey,
    required this.title,
    required this.supportingText,
    required this.metadata,
    required this.height,
    this.onTap,
    this.hero = false,
    this.borderRadius = 24,
    this.hasMenu = false,
    this.fixedHeight,
  });

  final RediscoverJourney journey;
  final String title;
  final String supportingText;
  final String metadata;
  final double height;
  final VoidCallback? onTap;
  final bool hero;
  final double borderRadius;
  final bool hasMenu;

  /// Optional shared height for a stack of cards that should align visually.
  final double? fixedHeight;

  static double resolvedHeight(
    BuildContext context,
    double minimum, {
    bool hero = false,
  }) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return math.max(minimum, hero ? 252 : 224) +
        math.max(0, scale - 1) * (hero ? 210 : 190);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final artwork = artworkThemeForJourney(journey, displayTitle: title);
    final visual = TopicVisual.forCategory(artwork.name);
    final surface = visual.cardSurface(cs, opacity: .58);
    final titleSize = hero ? 28.0 : 23.0;
    final imageSize = hero ? 132.0 : 112.0;
    final label = [
      title,
      supportingText,
      metadata,
    ].where((s) => s.trim().isNotEmpty).join('. ');

    return Semantics(
      button: onTap != null,
      onTap: onTap,
      container: true,
      excludeSemantics: true,
      label: label,
      child: ExpressiveTapScale(
        enabled: onTap != null,
        child: Material(
          color: surface,
          borderRadius: BorderRadius.circular(borderRadius),
          clipBehavior: Clip.antiAlias,
          child: SurfaceGrain(
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                height:
                    fixedHeight ??
                    resolvedHeight(context, height, hero: hero) +
                        (hasMenu ? 24 : 0),
                child: Padding(
                  padding: EdgeInsets.all(hero ? 22 : 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional.bottomStart,
                                child: HyphenatedTitle(
                                  text: title,
                                  maxLines: 4,
                                  style: AppTypography.editorial(
                                    theme.textTheme.headlineSmall,
                                    fontSize: titleSize,
                                    height: 1.08,
                                    color: cs.onSurface,
                                    letterSpacing: -.2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            RediscoverIllustration(
                              artwork: artwork,
                              size: imageSize,
                            ),
                          ],
                        ),
                      ),
                      if (supportingText.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          supportingText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                      if (metadata.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Padding(
                          padding: EdgeInsetsDirectional.only(
                            end: hasMenu ? 40 : 0,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: hasMenu ? 40 : 0,
                            ),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                metadata,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RediscoverIllustration extends StatelessWidget {
  const RediscoverIllustration({
    super.key,
    required this.artwork,
    required this.size,
  });
  final RediscoverArtworkTheme artwork;
  final double size;

  @override
  Widget build(BuildContext context) {
    final visual = TopicVisual.forCategory(artwork.name);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shape = AppShapes.border(visual.shape);
    final backdropColor = isDark
        ? Color.lerp(visual.container(cs), cs.onSurface, .12)!
        : visual.container(cs);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Transform.rotate(
              angle: -.12,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: backdropColor,
                  shape: shape,
                  shadows: [
                    if (isDark)
                      BoxShadow(
                        color: cs.shadow.withValues(alpha: .38),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(1, 3),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: ClipPath(
                clipper: ShapeBorderClipper(shape: shape),
                child: Image.asset(
                  artwork.assetPath,
                  fit: BoxFit.cover,
                  cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                      .ceil()
                      .clamp(1, 768),
                  excludeFromSemantics: true,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

RediscoverArtworkTheme? _artworkThemeForText(String text) {
  bool has(List<String> words) => words.any((word) {
    if (word.length <= 3) {
      return RegExp(
        r'(?:^|\W)' + RegExp.escape(word) + r'(?:$|\W)',
      ).hasMatch(text);
    }
    return text.contains(word);
  });

  if (has(const [
    'ai',
    'llm',
    'agent',
    'openai',
    'claude',
    'flutter',
    'code',
    'coding',
    'software',
    'developer',
    'programming',
    'github',
    'technology',
    'computer',
  ])) {
    return RediscoverArtworkTheme.software;
  }
  if (has(const [
    'travel',
    'trip',
    'journey',
    'hike',
    'trek',
    'trail',
    'camp',
    'destination',
    'hotel',
    'flight',
  ])) {
    return RediscoverArtworkTheme.travel;
  }
  if (has(const [
    'nature',
    'wildlife',
    'forest',
    'plant',
    'garden',
    'ecology',
    'farming',
    'agriculture',
    'animal',
    'bird',
  ])) {
    return RediscoverArtworkTheme.nature;
  }
  if (has(const [
    'food',
    'recipe',
    'cook',
    'cooking',
    'meal',
    'kitchen',
    'restaurant',
    'nutrition',
    'breakfast',
    'dinner',
  ])) {
    return RediscoverArtworkTheme.food;
  }
  if (has(const [
    'philosophy',
    'psychology',
    'stoic',
    'meaning',
    'ethics',
    'mindset',
    'spiritual',
    'meditation',
    'wisdom',
    'self improvement',
    'personal growth',
  ])) {
    return RediscoverArtworkTheme.philosophy;
  }
  if (has(const [
    'science',
    'biology',
    'physics',
    'chemistry',
    'space',
    'medical',
    'medicine',
    'research',
    'astronomy',
  ])) {
    return RediscoverArtworkTheme.science;
  }
  if (has(const [
    'finance',
    'invest',
    'stock',
    'stock market',
    'financial market',
    'money',
    'wealth',
    'budget',
    'economy',
    'crypto',
  ])) {
    return RediscoverArtworkTheme.finance;
  }
  if (has(const [
    'business',
    'startup',
    'founder',
    'career',
    'marketing',
    'leadership',
    'management',
    'entrepreneur',
    'productivity',
  ])) {
    return RediscoverArtworkTheme.business;
  }
  if (has(const [
    'history',
    'ancient',
    'heritage',
    'museum',
    'architecture',
    'archaeology',
    'historical',
  ])) {
    return RediscoverArtworkTheme.history;
  }
  if (has(const [
    'book',
    'reading',
    'literature',
    'essay',
    'writing',
    'author',
    'poetry',
    'novel',
  ])) {
    return RediscoverArtworkTheme.books;
  }
  if (has(const [
    'photo',
    'photography',
    'camera',
    'portrait',
    'image making',
    'cinematography',
  ])) {
    return RediscoverArtworkTheme.photography;
  }
  if (has(const [
    'fitness',
    'workout',
    'exercise',
    'running',
    'health',
    'wellness',
    'training',
    'yoga',
    'sport',
  ])) {
    return RediscoverArtworkTheme.fitness;
  }
  if (has(const [
    'music',
    'song',
    'audio',
    'album',
    'artist',
    'sound',
    'playlist',
    'concert',
  ])) {
    return RediscoverArtworkTheme.music;
  }
  if (has(const [
    'film',
    'movie',
    'cinema',
    'anime',
    'series',
    'television',
    'watchlist',
    'video',
  ])) {
    return RediscoverArtworkTheme.film;
  }
  if (has(const [
    'design',
    'creative',
    'creativity',
    'art',
    'illustration',
    'typography',
    'graphic',
    'ux',
    'ui',
  ])) {
    return RediscoverArtworkTheme.design;
  }
  if (has(const [
    'home',
    'interior',
    'decor',
    'living',
    'house',
    'furniture',
    'organization',
  ])) {
    return RediscoverArtworkTheme.home;
  }
  if (has(const [
    'fashion',
    'style',
    'outfit',
    'clothing',
    'beauty',
    'skincare',
    'grooming',
  ])) {
    return RediscoverArtworkTheme.fashion;
  }
  return null;
}
