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
    'tv-shows' ||
    'anime-comics' ||
    'film' => const TopicVisual(PhosphorIconsBold.filmSlate, AppShape.square),
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
    'philosophy' ||
    'psychology' => const TopicVisual(PhosphorIconsBold.brain, AppShape.clover),
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
