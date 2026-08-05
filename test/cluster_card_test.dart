import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/mindmap/cluster_card.dart';

void main() {
  const heroCluster = InterestCluster(
    id: '1',
    label: 'Nutrition & Wellness',
    saveCount: 7,
    subtopics: ['Nutrition', 'Recipe', 'Healthy Eating'],
    dominance: 0.7,
    coverImageUrl: null,
    accentColor: null,
  );

  const growingCluster = InterestCluster(
    id: '2',
    label: 'Movie recommendation',
    saveCount: 3,
    subtopics: ['Movies', 'Thriller'],
    dominance: 0.3,
    coverImageUrl: null,
    accentColor: null,
  );

  const strongGrowingCluster = InterestCluster(
    id: '3',
    label: 'Dev Tools & OSS',
    saveCount: 15,
    subtopics: ['GitHub', 'OSS'],
    dominance: 0.32,
    coverImageUrl: null,
    accentColor: null,
  );

  testWidgets('hero card does not repeat its top-signal status', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClusterCard(
            cluster: heroCluster,
            tier: ClusterCardTier.hero,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Nutrition & Wellness'), findsOneWidget);
    expect(find.text('7 saves'), findsOneWidget);
    expect(find.text('Dominant interest'), findsNothing);
    expect(find.textContaining('strongest pattern'), findsNothing);
    final title = tester.widget<Text>(find.text('Nutrition & Wellness'));
    expect(title.maxLines, 2);
    expect(title.style?.fontSize, 22);
    expect(title.style?.fontWeight, FontWeight.w700);
    expect(tester.getSize(find.byType(ClusterCard)).height, 176);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'growing-interest titles use one type scale across card heights',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 170,
                  child: ClusterCard(
                    cluster: growingCluster,
                    tier: ClusterCardTier.medium,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 170,
                  child: ClusterCard(
                    cluster: strongGrowingCluster,
                    tier: ClusterCardTier.medium,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final compactTitle = tester.widget<Text>(
        find.text('Movie recommendation'),
      );
      final strongTitle = tester.widget<Text>(find.text('Dev Tools & OSS'));
      for (final title in [compactTitle, strongTitle]) {
        expect(title.maxLines, 2);
        expect(title.style?.fontSize, 16);
        expect(title.style?.fontWeight, FontWeight.w600);
        expect(title.style?.height, 1.2);
      }
      expect(mediumClusterTileHeight(growingCluster), 168);
      expect(mediumClusterTileHeight(strongGrowingCluster), 200);
      final chip = tester.widget<Text>(find.text('GitHub'));
      expect(chip.style?.fontSize, 10.5);
      expect(chip.style?.fontWeight, FontWeight.w500);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact growing card remains stable with enlarged text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 170,
                child: ClusterCard(
                  cluster: growingCluster,
                  tier: ClusterCardTier.medium,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('Movie recommendation'));
    expect(title.maxLines, 2);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(title.data, 'Movie recommendation');
    expect(tester.takeException(), isNull);
  });

  test('medium card heights use restrained save-strength buckets', () {
    InterestCluster clusterWith(int saves) => InterestCluster(
      id: '$saves',
      label: 'Interest',
      saveCount: saves,
      subtopics: const ['One', 'Two'],
      dominance: 0,
      coverImageUrl: null,
      accentColor: null,
    );

    expect(mediumClusterTileHeight(clusterWith(3)), 168);
    expect(mediumClusterTileHeight(clusterWith(6)), 168);
    expect(mediumClusterTileHeight(clusterWith(7)), 184);
    expect(mediumClusterTileHeight(clusterWith(12)), 184);
    expect(mediumClusterTileHeight(clusterWith(13)), 200);
    expect(mediumClusterTileHeight(clusterWith(40)), 200);
  });
}
