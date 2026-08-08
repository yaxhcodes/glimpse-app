import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';
import 'package:glimpse/features/url_detail/notable_item_card.dart';

void main() {
  Widget buildCard(EnrichedNotableItem item) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            child: NotableItemCard(item: item, accent: Colors.purple),
          ),
        ),
      ),
    );
  }

  testWidgets('uses the full available width for descriptive items', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildCard(
        const EnrichedNotableItem(
          text: 'From the Sky',
          type: 'reference',
          label: 'Song',
          whyImportant: 'Prescribed track for depression.',
        ),
      ),
    );

    expect(tester.getSize(find.byType(NotableItemCard)).width, 320);
  });

  testWidgets('uses a music icon when a notable item is labelled as a song', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildCard(
        const EnrichedNotableItem(
          text: 'From the Sky',
          type: 'reference',
          label: 'Song',
        ),
      ),
    );

    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
  });
}
