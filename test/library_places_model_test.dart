import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';
import 'package:glimpse/features/library/library_entity.dart';
import 'package:glimpse/features/library/library_places_model.dart';

void main() {
  test('groups places by normalized city, then country, then unsorted', () {
    final areas = PlaceAreaIndex.build([
      _place('one', city: ' Kyoto ', country: 'Japan'),
      _place('two', city: 'kyoto', country: 'Japan'),
      _place('three', country: 'Iceland'),
      _place('four'),
    ]);

    expect(areas, hasLength(3));
    expect(
      areas.singleWhere((area) => area.title.toLowerCase() == 'kyoto').entities,
      hasLength(2),
    );
    expect(
      areas.singleWhere((area) => area.title == 'Iceland').subtitle,
      isNull,
    );
    expect(areas.last.key, unsortedPlacesAreaKey);
    expect(areas.last.title, 'Unsorted places');
  });

  test(
    'place imagery prefers exact mention artwork then a saved thumbnail',
    () {
      final withArtwork = _place(
        'artwork',
        posterUrl: 'https://images.example/place.jpg',
        thumbnailUrl: 'https://images.example/source.jpg',
      );
      final withSourceOnly = _place(
        'source',
        thumbnailUrl: 'https://images.example/source.jpg',
      );

      expect(withArtwork.placeImageUrl, 'https://images.example/place.jpg');
      expect(withSourceOnly.placeImageUrl, 'https://images.example/source.jpg');
    },
  );

  test('suppresses a repeated source thumbnail across visible places', () {
    final first = _place(
      'first',
      thumbnailUrl: 'https://images.example/shared.jpg',
    );
    final second = _place(
      'second',
      thumbnailUrl: 'https://images.example/shared.jpg',
    );

    final images = uniquePlaceImageUrls([first, second]);

    expect(images[first.key], 'https://images.example/shared.jpg');
    expect(images[second.key], isNull);
  });
}

LibraryEntity _place(
  String key, {
  String? city,
  String? country,
  String? posterUrl,
  String? thumbnailUrl,
}) {
  final mention = EnrichedMention(
    title: key,
    type: 'place',
    city: city,
    country: country,
    posterUrl: posterUrl,
  );
  return LibraryEntity(
    key: key,
    provisionalKey: 'provisional-$key',
    kind: LibraryEntityKind.place,
    mention: mention,
    sources: [
      LibrarySourceReference(
        urlId: key.hashCode,
        title: 'Source',
        domain: 'example.com',
        savedAt: DateTime(2026, 8, 1),
        provisionalKey: 'provisional-$key',
        mention: mention,
        thumbnailUrl: thumbnailUrl,
      ),
    ],
    discoveredAt: DateTime(2026, 8, 1),
  );
}
