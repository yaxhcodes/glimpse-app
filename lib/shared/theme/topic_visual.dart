import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'app_shapes.dart';
import 'readable_surface.dart';

class TopicVisual {
  const TopicVisual(this.icon, this.shape, {this.tertiary = false});

  final IconData icon;
  final AppShape shape;
  final bool tertiary;

  Color container(ColorScheme cs) => Color.alphaBlend(
    (tertiary ? cs.tertiaryContainer : cs.primaryContainer).withValues(
      alpha: .25,
    ),
    cs.surfaceContainerHighest,
  );
  Color foreground(ColorScheme cs) => cs.onSurface;

  Color cardSurface(ColorScheme cs, {required double opacity}) =>
      readableTintedSurface(
        base: cs.surfaceContainerLow,
        tint: container(cs),
        foregrounds: [cs.onSurface, cs.onSurfaceVariant],
        opacity: opacity,
      );

  /// The topic glyph for a save's category names ("Food & Cooking",
  /// "Music", "Technology"), skipping platform names; sparkle when none
  /// match.
  static TopicVisual forTopicNames(Iterable<String> names) {
    for (final raw in names) {
      final words = raw
          .toLowerCase()
          .split(RegExp(r'[^a-z]+'))
          .where((word) => word.isNotEmpty)
          .toList();
      String? slug;
      // Short keys ("ai", "tv", "art") must be the whole word; longer ones
      // may start it ("cook" → cooking).
      bool has(List<String> keys) => keys.any(
        (key) => words.any(
          (word) => key.length <= 3 ? word == key : word.startsWith(key),
        ),
      );
      if (has(['music', 'song', 'podcast'])) {
        slug = 'music';
      } else if (has(['food', 'cook', 'recipe', 'nutrition'])) {
        slug = 'food';
      } else if (has(['travel', 'place', 'destination'])) {
        slug = 'travel';
      } else if (has(['book', 'reading', 'writing', 'literature'])) {
        slug = 'books';
      } else if (has([
        'movie',
        'film',
        'tv',
        'anime',
        'entertainment',
        'show',
      ])) {
        slug = 'film';
      } else if (has(['ai', 'artificial'])) {
        slug = 'artificial-intelligence';
      } else if (has([
        'tech',
        'software',
        'programming',
        'developer',
        'code',
        'app',
      ])) {
        slug = 'software';
      } else if (has(['design', 'art', 'illustration'])) {
        slug = 'design';
      } else if (has([
        'business',
        'finance',
        'money',
        'invest',
        'marketing',
        'startup',
      ])) {
        slug = 'business';
      } else if (has(['health', 'fitness', 'wellness'])) {
        slug = 'wellness';
      } else if (has(['science', 'space', 'astronomy'])) {
        slug = 'science';
      } else if (has(['history'])) {
        slug = 'history';
      } else if (has(['spiritual', 'religio', 'devotion', 'meditation'])) {
        slug = 'spirituality';
      } else if (has(['philosophy'])) {
        slug = 'philosophy';
      } else if (has(['psychology', 'mindset', 'growth'])) {
        slug = 'psychology';
      } else if (has(['nature', 'wildlife', 'garden', 'animal'])) {
        slug = 'nature';
      } else if (has(['education', 'learning', 'study'])) {
        slug = 'education';
      } else if (has(['fashion', 'beauty', 'style'])) {
        slug = 'fashion';
      } else if (has(['photo'])) {
        slug = 'photography';
      } else if (has(['productivity'])) {
        slug = 'productivity';
      }
      if (slug != null) return forCategory(slug);
    }
    return forCategory('');
  }

  static TopicVisual forCategory(String category) => switch (category) {
    'programming' || 'software' || 'technology-gadgets' => const TopicVisual(
      PhosphorIconsBold.code,
      AppShape.square,
    ),
    'artificial-intelligence' => const TopicVisual(
      PhosphorIconsBold.cpu,
      AppShape.cookie,
    ),
    'design' => const TopicVisual(PhosphorIconsBold.shapes, AppShape.clover),
    'food-nutrition' || 'cooking-recipes' || 'food' => const TopicVisual(
      PhosphorIconsBold.bowlFood,
      AppShape.cookie,
      tertiary: true,
    ),
    'nature-outdoors' ||
    'travel' => const TopicVisual(PhosphorIconsBold.mountains, AppShape.gem),
    'wildlife' || 'gardening' || 'nature' => const TopicVisual(
      PhosphorIconsBold.leaf,
      AppShape.clover,
      tertiary: true,
    ),
    'wellness' || 'fitness' => const TopicVisual(
      PhosphorIconsBold.heart,
      AppShape.cookie,
      tertiary: true,
    ),
    'movies' ||
    'film' => const TopicVisual(PhosphorIconsBold.filmSlate, AppShape.square),
    'tv-shows' => const TopicVisual(
      PhosphorIconsBold.television,
      AppShape.square,
    ),
    'anime-comics' => const TopicVisual(
      PhosphorIconsBold.shootingStar,
      AppShape.gem,
      tertiary: true,
    ),
    'books-reading' || 'writing' || 'books' => const TopicVisual(
      PhosphorIconsBold.bookOpen,
      AppShape.arch,
      tertiary: true,
    ),
    'music' || 'podcasts' => const TopicVisual(
      PhosphorIconsBold.musicNotes,
      AppShape.cookie,
    ),
    'science' || 'astronomy-space' => const TopicVisual(
      PhosphorIconsBold.planet,
      AppShape.cookie,
    ),
    'business' ||
    'finance' => const TopicVisual(PhosphorIconsBold.trendUp, AppShape.gem),
    'education' => const TopicVisual(
      PhosphorIconsBold.graduationCap,
      AppShape.arch,
    ),
    'philosophy' => const TopicVisual(
      PhosphorIconsBold.lightbulb,
      AppShape.clover,
    ),
    'psychology' => const TopicVisual(PhosphorIconsBold.brain, AppShape.clover),
    'spirituality' => const TopicVisual(
      PhosphorIconsBold.flowerLotus,
      AppShape.cookie,
      tertiary: true,
    ),
    'history' => const TopicVisual(
      PhosphorIconsBold.columns,
      AppShape.arch,
      tertiary: true,
    ),
    'photography' => const TopicVisual(
      PhosphorIconsBold.camera,
      AppShape.circle,
    ),
    'fashion' || 'beauty' => const TopicVisual(
      PhosphorIconsBold.tShirt,
      AppShape.clover,
      tertiary: true,
    ),
    'home-interiors' || 'home' => const TopicVisual(
      PhosphorIconsBold.houseSimple,
      AppShape.arch,
      tertiary: true,
    ),
    'pets' => const TopicVisual(PhosphorIconsBold.pawPrint, AppShape.cookie),
    'cycling' => const TopicVisual(PhosphorIconsBold.bicycle, AppShape.gem),
    'automotive' || 'motorsport' || 'motorcycles' => const TopicVisual(
      PhosphorIconsBold.steeringWheel,
      AppShape.circle,
    ),
    'diy-tools' => const TopicVisual(PhosphorIconsBold.wrench, AppShape.square),
    'productivity' => const TopicVisual(
      PhosphorIconsBold.checkSquare,
      AppShape.square,
    ),
    _ => const TopicVisual(PhosphorIconsBold.sparkle, AppShape.cookie),
  };
}
