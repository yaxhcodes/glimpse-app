import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';
import 'package:glimpse/features/ask/ask_itinerary_builder.dart';
import 'package:glimpse/features/ask/ask_provider.dart';
import 'package:glimpse/features/library/library_entity.dart';

void main() {
  test('builds an editable itinerary in the order Ask proposed', () {
    final firstSource = _saved(1, 'Delhi history');
    final secondSource = _saved(2, 'Delhi observatories');
    final parliament = _place(
      'parliament',
      title: 'Parliament House',
      source: firstSource,
    );
    final redFort = _place('red-fort', title: 'Red Fort', source: firstSource);
    final jantar = _place(
      'jantar',
      title: 'Jantar Mantar Astronomical Observatory',
      source: secondSource,
    );

    final draft = AskItineraryBuilder.fromMessage(
      ChatMessage(
        text: 'Start with the observatory, then continue to Parliament.',
        isUser: false,
        sources: [firstSource, secondSource],
        sections: [
          ChatMessageSection(
            heading: 'Jantar Mantar',
            summary: 'Begin at the astronomical observatory.',
            source: secondSource,
          ),
          ChatMessageSection(
            heading: 'Parliament House',
            summary: 'Continue to Parliament House.',
            source: firstSource,
          ),
        ],
      ),
      LibrarySnapshot(entities: [parliament, redFort, jantar]),
    );

    expect(draft, isNotNull);
    expect(draft!.name, 'A day in New Delhi');
    expect(draft.areaKey, 'new delhi|india');
    expect(draft.entities.map((entity) => entity.key), [
      'jantar',
      'parliament',
    ]);
  });

  test('returns no plan when the answer cites no saved place entities', () {
    final source = _saved(1, 'A generic article');

    final draft = AskItineraryBuilder.fromMessage(
      ChatMessage(text: 'A possible plan', isUser: false, sources: [source]),
      const LibrarySnapshot(entities: []),
    );

    expect(draft, isNull);
  });
}

SavedUrl _saved(int id, String title) => SavedUrl()
  ..id = id
  ..rawUrl = 'https://example.com/$id'
  ..domain = 'example.com'
  ..title = title
  ..description = ''
  ..category = 'Travel'
  ..categoryEmoji = ''
  ..categories = const ['Travel']
  ..tags = const []
  ..savedAt = DateTime(2026, 8, id);

LibraryEntity _place(
  String key, {
  required String title,
  required SavedUrl source,
}) {
  final mention = EnrichedMention(
    title: title,
    type: 'place',
    city: 'New Delhi',
    country: 'India',
    latitude: 28.6,
    longitude: 77.2,
  );
  return LibraryEntity(
    key: key,
    provisionalKey: key,
    kind: LibraryEntityKind.place,
    mention: mention,
    sources: [
      LibrarySourceReference(
        urlId: source.id,
        title: source.title,
        domain: source.domain,
        savedAt: source.savedAt,
        provisionalKey: key,
        mention: mention,
      ),
    ],
    discoveredAt: source.savedAt,
  );
}
