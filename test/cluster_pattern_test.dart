import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/mindmap/cluster_pattern.dart';
import 'package:glimpse/features/mindmap/cluster_pattern_library.dart';

void main() {
  test('routes broad interests into the data-driven pattern library', () {
    const cases = {
      'Movie Recommendations': 'movies',
      'TV Series': 'tv-shows',
      'Anime': 'anime-comics',
      'Nutrition & Wellness': 'food-nutrition',
      'Trekking & Nature': 'nature-outdoors',
      'AI Agents': 'artificial-intelligence',
      'Dev Tools & OSS': 'programming',
      'Gizmos & Gadgets': 'technology-gadgets',
      'Website Growth': 'business',
      'Books & Essays': 'books-reading',
      'Writing & Journaling': 'writing',
      'Music': 'music',
      'Podcasts': 'podcasts',
      'Travel Plans': 'travel',
      'Design Systems': 'design',
      'Gaming': 'gaming',
      'Photography': 'photography',
      'Wildlife': 'wildlife',
      'Gardening': 'gardening',
      'Investing': 'finance',
      'Education': 'education',
      'Science & Research': 'science',
      'Astronomy': 'astronomy-space',
      'Cricket': 'cricket',
      'Football': 'football',
      'Formula 1': 'motorsport',
      'Cycling': 'cycling',
      'Fashion': 'fashion',
      'Beauty': 'beauty',
      'Pets': 'pets',
      'Home Decor': 'home-interiors',
      'DIY Projects': 'diy-tools',
      'Automotive': 'automotive',
      'Motorcycles': 'motorcycles',
      'Productivity': 'productivity',
      'Minimalism': 'minimalism',
      'Philosophy': 'philosophy',
      'Psychology': 'psychology',
      'History': 'history',
      'Language Learning': 'languages',
      'News': 'news',
      'Sustainability': 'sustainability',
    };

    for (final entry in cases.entries) {
      final selection = resolveClusterPattern(
        label: entry.key,
        subtopics: const [],
      );
      expect(selection.categoryIds, contains(entry.value), reason: entry.key);
      expect(selection.icons.length, inInclusiveRange(8, 20));
      expect(selection.isFallback, isFalse);
    }
  });

  test('combines multiple relevant categories', () {
    final selection = resolveClusterPattern(
      label: 'Healthy Recipes',
      subtopics: const ['Nutrition', 'Cooking'],
    );

    expect(selection.categoryIds, contains('food-nutrition'));
    expect(selection.categoryIds, contains('cooking-recipes'));
    expect(selection.icons.length, 20);
  });

  test('weights the primary label above a noisy subtopic', () {
    final selection = resolveClusterPattern(
      label: 'Dev Tools & OSS',
      subtopics: const ['Food & Cooking'],
    );

    expect(selection.categoryIds.first, 'programming');
    expect(selection.categoryIds, isNot(contains('cooking-recipes')));
  });

  test('uses local semantic similarity before abstract fallback', () {
    final selection = resolveClusterPattern(
      label: 'Computing Internals',
      subtopics: const [],
    );

    expect(selection.categoryIds, contains('technology-gadgets'));
    expect(selection.isFallback, isFalse);
  });

  test('unknown interests receive a complete abstract pattern', () {
    final selection = resolveClusterPattern(
      label: 'Qzxv Plmnr',
      subtopics: const [],
    );

    expect(selection.categoryIds, const ['abstract']);
    expect(selection.icons.length, greaterThanOrEqualTo(8));
    expect(selection.isFallback, isTrue);
  });

  test('selection is stable for the same interest and unique by interest', () {
    final first = resolveClusterPattern(
      label: 'Movie Recommendations',
      subtopics: const ['Cinema'],
    );
    final repeated = resolveClusterPattern(
      label: 'Movie Recommendations',
      subtopics: const ['Cinema'],
    );
    final different = resolveClusterPattern(
      label: 'Classic Movie Recommendations',
      subtopics: const ['Cinema'],
    );

    expect(repeated.signature, first.signature);
    expect(repeated.icons, first.icons);
    expect(different.seed, isNot(first.seed));
  });

  test('every library entry has aliases and 8-20 unique symbols', () {
    final ids = <String>{};
    for (final category in clusterPatternLibrary) {
      expect(ids.add(category.id), isTrue, reason: category.id);
      expect(category.aliases, isNotEmpty, reason: category.id);
      expect(
        category.icons.length,
        inInclusiveRange(8, 20),
        reason: category.id,
      );
      expect(
        category.icons.map((icon) => icon.codePoint).toSet().length,
        category.icons.length,
        reason: category.id,
      );
    }
  });

  test('layout keeps the 70/25/5 size hierarchy and rotation bounds', () {
    final selection = resolveClusterPattern(
      label: 'Nature Photography',
      subtopics: const ['Wildlife'],
    );
    final placements = generateClusterPatternPlacements(
      selection: selection,
      canvasSize: const Size(1200, 1200),
      baseOpacity: 0.095,
    );
    final small = placements
        .where((placement) => placement.sizeTier == PatternMotifSize.small)
        .length;
    final medium = placements
        .where((placement) => placement.sizeTier == PatternMotifSize.medium)
        .length;
    final large = placements
        .where((placement) => placement.sizeTier == PatternMotifSize.large)
        .length;

    expect(small / placements.length, inInclusiveRange(0.65, 0.75));
    expect(medium / placements.length, inInclusiveRange(0.20, 0.30));
    expect(large / placements.length, inInclusiveRange(0.03, 0.08));
    expect(
      placements.every((placement) => placement.angle.abs() <= 0.14),
      isTrue,
    );
    expect(
      placements.every(
        (placement) => placement.opacity >= 0.068 && placement.opacity <= 0.14,
      ),
      isTrue,
    );
  });

  test('content-safe regions reduce local placement density by about 40%', () {
    final selection = resolveClusterPattern(
      label: 'Movie Recommendations',
      subtopics: const ['Cinema'],
    );
    const canvasSize = Size(1000, 1000);
    final unmasked = generateClusterPatternPlacements(
      selection: selection,
      canvasSize: canvasSize,
      baseOpacity: 0.095,
    );
    final masked = generateClusterPatternPlacements(
      selection: selection,
      canvasSize: canvasSize,
      baseOpacity: 0.095,
      contentSafeRegion: const PatternSafeRegion(
        left: 0,
        top: 0,
        right: 1,
        bottom: 1,
      ),
    );
    final canvasRect = Offset.zero & canvasSize;
    final unmaskedInside = unmasked
        .where((placement) => canvasRect.contains(placement.center))
        .length;
    final maskedInside = masked
        .where((placement) => canvasRect.contains(placement.center))
        .length;

    expect(maskedInside / unmaskedInside, inInclusiveRange(0.50, 0.70));
  });

  test('controlled randomness is deterministic for a stable interest seed', () {
    final selection = resolveClusterPattern(
      label: 'Dev Tools & OSS',
      subtopics: const ['GitHub'],
    );
    final first = generateClusterPatternPlacements(
      selection: selection,
      canvasSize: const Size(360, 190),
      baseOpacity: 0.105,
    );
    final repeated = generateClusterPatternPlacements(
      selection: selection,
      canvasSize: const Size(360, 190),
      baseOpacity: 0.105,
    );

    expect(repeated.length, first.length);
    expect(
      repeated
          .map(
            (placement) => (
              placement.icon.codePoint,
              placement.center,
              placement.size,
              placement.angle,
              placement.opacity,
            ),
          )
          .toList(),
      first
          .map(
            (placement) => (
              placement.icon.codePoint,
              placement.center,
              placement.size,
              placement.angle,
              placement.opacity,
            ),
          )
          .toList(),
    );
  });
}
