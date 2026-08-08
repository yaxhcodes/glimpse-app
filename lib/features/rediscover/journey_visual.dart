import 'package:flutter/material.dart';

import '../../shared/theme/app_typography.dart';
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
  general,
}

extension RediscoverArtworkThemeAsset on RediscoverArtworkTheme {
  String get assetPath => 'assets/rediscover/$name.webp';
}

class RediscoverArtworkVisual {
  const RediscoverArtworkVisual({
    required this.theme,
    required this.eyebrow,
    this.alignment = Alignment.center,
  });

  final RediscoverArtworkTheme theme;
  final String eyebrow;
  final Alignment alignment;

  String get assetPath => theme.assetPath;
}

RediscoverArtworkTheme artworkThemeForJourney(RediscoverJourney journey) {
  final primaryText = [
    journey.topicAnchor,
    journey.categoryLabel,
    journey.title,
  ].whereType<String>().join(' ').toLowerCase();
  final primaryTheme = _artworkThemeForText(primaryText);
  if (primaryTheme != null) return primaryTheme;

  final supportingText = [
    primaryText,
    for (final item in journey.items.take(5)) ...[
      item.url.title,
      item.url.category,
      ...item.url.effectiveCategories,
      ...item.url.tags,
    ],
  ].join(' ').toLowerCase();

  return _artworkThemeForText(supportingText) ?? RediscoverArtworkTheme.general;
}

RediscoverArtworkVisual visualForJourney(RediscoverJourney journey) {
  return RediscoverArtworkVisual(
    theme: artworkThemeForJourney(journey),
    eyebrow: _eyebrowFor(journey.kind),
  );
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
  });

  final RediscoverJourney journey;
  final String title;
  final String supportingText;
  final String metadata;
  final double height;
  final VoidCallback? onTap;
  final bool hero;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final visual = visualForJourney(journey);
    final radius = BorderRadius.circular(borderRadius);
    final semanticsLabel = [
      title,
      supportingText,
      metadata,
    ].where((value) => value.trim().isNotEmpty).join('. ');

    return Semantics(
      button: onTap != null,
      container: true,
      excludeSemantics: true,
      label: semanticsLabel,
      child: SizedBox(
        height: height,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                visual.assetPath,
                fit: BoxFit.cover,
                alignment: visual.alignment,
                cacheWidth: 1200,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
              ),
              const _ArtworkScrim(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  splashColor: Colors.white.withValues(alpha: 0.12),
                  highlightColor: Colors.white.withValues(alpha: 0.06),
                  child: Padding(
                    padding: hero
                        ? const EdgeInsets.fromLTRB(22, 20, 22, 22)
                        : const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: _ArtworkTypography(
                      title: title,
                      supportingText: supportingText,
                      metadata: metadata,
                      hero: hero,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtworkScrim extends StatelessWidget {
  const _ArtworkScrim();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? const [
                      Color(0x18000000),
                      Color(0x10000000),
                      Color(0x52000000),
                      Color(0xE0000000),
                    ]
                  : [
                      surface.withValues(alpha: 0.08),
                      surface.withValues(alpha: 0.16),
                      surface.withValues(alpha: 0.74),
                      surface.withValues(alpha: 0.97),
                    ],
              stops: [0, 0.34, 0.68, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: isDark
                  ? const [Color(0x52000000), Color(0x00000000)]
                  : [
                      surface.withValues(alpha: 0.38),
                      surface.withValues(alpha: 0),
                    ],
              stops: [0, 0.78],
            ),
          ),
        ),
      ],
    );
  }
}

class _ArtworkTypography extends StatelessWidget {
  const _ArtworkTypography({
    required this.title,
    required this.supportingText,
    required this.metadata,
    required this.hero,
  });

  final String title;
  final String supportingText;
  final String metadata;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : theme.colorScheme.onSurface;
    final secondaryText = primaryText.withValues(alpha: 0.82);
    final tertiaryText = primaryText.withValues(alpha: 0.64);
    final shadows = isDark ? _darkTextShadows : const <Shadow>[];
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final showSupporting =
        supportingText.trim().isNotEmpty && textScale <= (hero ? 1.65 : 1.5);
    final showMetadata =
        metadata.trim().isNotEmpty && textScale <= (hero ? 1.4 : 1.3);

    return Align(
      alignment: Alignment.bottomLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: hero && textScale <= 1.3 ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.editorial(
              hero ? textTheme.headlineMedium : textTheme.headlineSmall,
              color: primaryText,
              fontSize: hero ? 30 : 24,
              fontWeight: FontWeight.w600,
              height: 1.02,
              letterSpacing: -0.2,
            ).copyWith(shadows: shadows),
          ),
          if (showSupporting) ...[
            const SizedBox(height: 8),
            Text(
              supportingText,
              maxLines: hero ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: (hero ? textTheme.bodyMedium : textTheme.bodySmall)
                  ?.copyWith(
                    color: secondaryText,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                    letterSpacing: 0,
                    shadows: shadows,
                  ),
            ),
          ],
          if (showMetadata) ...[
            const SizedBox(height: 6),
            Text(
              metadata,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: tertiaryText,
                fontSize: hero ? 11 : 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
                shadows: shadows,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const _darkTextShadows = [
  Shadow(color: Color(0x70000000), blurRadius: 14, offset: Offset(0, 2)),
];

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

String _eyebrowFor(RediscoverJourneyKind kind) {
  return switch (kind) {
    RediscoverJourneyKind.continueLearning => 'Continue learning',
    RediscoverJourneyKind.forgottenGems => 'Worth another look',
    RediscoverJourneyKind.neverOpened => 'Still waiting',
    RediscoverJourneyKind.onThisDay => 'From before',
    RediscoverJourneyKind.memoryGoal => 'Keep moving',
    RediscoverJourneyKind.becauseYouSaved => 'A pattern in your saves',
  };
}
