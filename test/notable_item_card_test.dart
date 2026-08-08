import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';
import 'package:glimpse/features/url_detail/notable_item_card.dart';

void main() {
  Widget buildCard(EnrichedNotableItem item, {VoidCallback? onTap}) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            child: NotableItemCard(
              item: item,
              accent: Colors.purple,
              onTap: onTap,
            ),
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

  testWidgets('makes an actionable song card visibly tappable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      buildCard(
        const EnrichedNotableItem(
          text: 'From the Sky',
          type: 'reference',
          label: 'Song',
          attribution: 'Gojira',
        ),
        onTap: () => taps++,
      ),
    );

    expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
    await tester.tap(find.byType(NotableItemCard));

    expect(taps, 1);
  });

  test('recognizes music from the notable item label', () {
    const song = EnrichedNotableItem(
      text: 'Bleed',
      type: 'reference',
      label: 'Song',
      attribution: 'Meshuggah',
    );
    const quote = EnrichedNotableItem(text: 'A memorable quote', type: 'quote');

    expect(song.isMusicItem, isTrue);
    expect(quote.isMusicItem, isFalse);
  });
}
