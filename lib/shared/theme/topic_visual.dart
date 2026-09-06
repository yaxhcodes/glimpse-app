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
      PhosphorIconsRegular.code,
      AppShape.square,
    ),
    'artificial-intelligence' => const TopicVisual(
      PhosphorIconsRegular.cpu,
      AppShape.cookie,
    ),
    'design' => const TopicVisual(PhosphorIconsRegular.shapes, AppShape.clover),
    'food-nutrition' || 'cooking-recipes' || 'food' => const TopicVisual(
      PhosphorIconsRegular.bowlFood,
      AppShape.cookie,
      tertiary: true,
    ),
    'nature-outdoors' ||
    'travel' => const TopicVisual(PhosphorIconsRegular.mountains, AppShape.gem),
    'wildlife' || 'gardening' || 'nature' => const TopicVisual(
      PhosphorIconsRegular.leaf,
      AppShape.clover,
      tertiary: true,
    ),
    'wellness' || 'fitness' => const TopicVisual(
      PhosphorIconsRegular.heart,
      AppShape.cookie,
      tertiary: true,
    ),
    'movies' || 'tv-shows' || 'anime-comics' || 'film' => const TopicVisual(
      PhosphorIconsRegular.filmSlate,
      AppShape.square,
    ),
    'books-reading' || 'writing' || 'books' => const TopicVisual(
      PhosphorIconsRegular.bookOpen,
      AppShape.arch,
      tertiary: true,
    ),
    'music' || 'podcasts' => const TopicVisual(
      PhosphorIconsRegular.musicNotes,
      AppShape.cookie,
    ),
    'science' || 'astronomy-space' => const TopicVisual(
      PhosphorIconsRegular.planet,
      AppShape.cookie,
    ),
    'business' ||
    'finance' => const TopicVisual(PhosphorIconsRegular.trendUp, AppShape.gem),
    'education' => const TopicVisual(
      PhosphorIconsRegular.graduationCap,
      AppShape.arch,
    ),
    'philosophy' || 'psychology' => const TopicVisual(
      PhosphorIconsRegular.brain,
      AppShape.clover,
    ),
    'history' => const TopicVisual(
      PhosphorIconsRegular.columns,
      AppShape.arch,
      tertiary: true,
    ),
    'photography' => const TopicVisual(
      PhosphorIconsRegular.camera,
      AppShape.circle,
    ),
    'fashion' || 'beauty' => const TopicVisual(
      PhosphorIconsRegular.tShirt,
      AppShape.clover,
      tertiary: true,
    ),
    'home-interiors' || 'home' => const TopicVisual(
      PhosphorIconsRegular.houseSimple,
      AppShape.arch,
      tertiary: true,
    ),
    'pets' => const TopicVisual(PhosphorIconsRegular.pawPrint, AppShape.cookie),
    'cycling' => const TopicVisual(PhosphorIconsRegular.bicycle, AppShape.gem),
    'automotive' || 'motorsport' || 'motorcycles' => const TopicVisual(
      PhosphorIconsRegular.steeringWheel,
      AppShape.circle,
    ),
    'diy-tools' => const TopicVisual(
      PhosphorIconsRegular.wrench,
      AppShape.square,
    ),
    'productivity' => const TopicVisual(
      PhosphorIconsRegular.checkSquare,
      AppShape.square,
    ),
    _ => const TopicVisual(PhosphorIconsRegular.sparkle, AppShape.cookie),
  };
}
