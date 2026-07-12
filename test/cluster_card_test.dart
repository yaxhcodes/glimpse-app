import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact growing-interest titles render without truncation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
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
    );

    final title = tester.widget<Text>(find.text('Movie recommendation'));
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('Movie recommendation'),
    );
    expect(title.maxLines, 3);
    expect(title.data, 'Movie recommendation');
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });
}
