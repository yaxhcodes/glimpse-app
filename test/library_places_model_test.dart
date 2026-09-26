import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';
import 'package:glimpse/features/library/library_entity.dart';
import 'package:glimpse/features/library/library_places_model.dart';
import 'package:glimpse/features/library/place_geography.dart';
import 'package:glimpse/features/library/place_locality_provider.dart';
import 'package:glimpse/features/library/places_world_preview.dart';

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

  group('regions within a country', () {
    final localities = <String, PlaceLocality>{
      'kiyomizu': const PlaceLocality(
        region: 'Kyoto Prefecture',
        city: 'Kyoto',
      ),
      'fushimi': const PlaceLocality(region: 'Kyoto Prefecture', city: 'Kyoto'),
      'amanohashidate': const PlaceLocality(
        region: 'Kyoto Prefecture',
        city: 'Miyazu',
      ),
      'shibuya': const PlaceLocality(region: 'Tokyo', city: 'Shibuya'),
      'mystery': const PlaceLocality(),
    };
    List<PlaceRegionGroup> groupAll() => PlaceSubdivisions.group([
      _place('kiyomizu', city: 'Kyoto', country: 'Japan'),
      _place('shibuya', city: 'Tokyo', country: 'Japan'),
      _place('fushimi', city: 'Kyoto', country: 'Japan'),
      _place('amanohashidate', country: 'Japan'),
      _place('mystery', country: 'Japan'),
    ], localityOf: (entity) => localities[entity.key]);

    test('groups by region, largest first, unknown region last', () {
      final regions = groupAll();
      expect(regions.map((region) => region.title), ['Kyoto', 'Tokyo', null]);
      expect(regions.first.length, 3);
    });

    test('names cities with several places and pools the rest', () {
      final kyoto = groupAll().first;
      expect(kyoto.cities.map((city) => city.title), ['Kyoto', null]);
      expect(kyoto.cities.first.entities.map((entity) => entity.key), [
        'kiyomizu',
        'fushimi',
      ]);
      expect(kyoto.cities.last.entities.single.key, 'amanohashidate');
    });

    test('a city that only repeats the region is not a city', () {
      final tokyo = groupAll()[1];
      // The saved city repeats the region, so the geocoded town is used.
      expect(
        PlaceSubdivisions.cityOf(tokyo.entities.single, localities['shibuya']),
        'Shibuya',
      );
    });

    test('city-states have no region', () {
      expect(
        PlaceSubdivisions.regionOf(
          _place('marina', country: 'Singapore'),
          const PlaceLocality(region: 'Singapore'),
        ),
        isNull,
      );
    });
  });

  test('recognizes country and continent names', () {
    expect(isCountryOrContinentName('Kyrgyzstan'), isTrue);
    expect(isCountryOrContinentName(' the Netherlands '), isTrue);
    expect(isCountryOrContinentName('U.S.A.'), isTrue);
    expect(isCountryOrContinentName('Southeast Asia'), isTrue);
    expect(isCountryOrContinentName('Kyoto'), isFalse);
    expect(isCountryOrContinentName('Song-Kul Lake'), isFalse);
  });

  test('names divisions the way each country does', () {
    expect(englishRegionCount('Japan', 4), '4 prefectures');
    expect(englishRegionCount('India', 1), '1 state');
    expect(englishRegionCount('Ireland', 2), '2 counties');
    expect(englishRegionCount('Atlantis', 2), isNull);
    expect(shortRegionName('Kyoto Prefecture'), 'Kyoto');
    expect(shortRegionName('Issyk-Kul Region'), 'Issyk-Kul');
    expect(shortRegionName('Maharashtra'), 'Maharashtra');
  });

  test('world preview places pins in their grid cells', () {
    expect(worldCellOf(35.68, 139.7), (42, 6)); // Tokyo
    expect(worldCellOf(48.85, 2.35), (24, 4)); // Paris
    expect(worldCellOf(-33.87, 151.21), (44, 18)); // Sydney
    expect(worldCellOf(-75, 0), isNull); // Antarctica is not drawn
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
