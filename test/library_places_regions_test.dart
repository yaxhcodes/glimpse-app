import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';
import 'package:glimpse/features/library/library_entity.dart';
import 'package:glimpse/features/library/library_places_screen.dart';
import 'package:glimpse/features/library/library_provider.dart';
import 'package:glimpse/features/library/place_locality_provider.dart';
import 'package:glimpse/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final expandFirst in [false, true]) {
    testWidgets(
      'regions trickle in after a country is chosen, expanded=$expandFirst',
      (tester) async {
        const states = [
          'California',
          'Illinois',
          'New York',
          'Georgia',
          'Texas',
        ];
        final answers = <(double, double), PlaceLocality>{
          for (var i = 0; i < 30; i++)
            (30.0 + i, -100.0 + i): PlaceLocality(
              // The first (selected) place lands in the smallest region, so
              // regrouping moves it to the end of the carousel.
              region: i == 0 ? 'Wyoming' : states[i % states.length],
              city: 'City ${i % 7}',
            ),
        };
        final geocoder = _FakeGeocoder(answers);
        final places = [
          for (final (index, (lat, lon)) in answers.keys.indexed)
            _place('p$index', lat, lon),
        ];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              librarySnapshotProvider.overrideWith(
                (ref) => AsyncValue.data(LibrarySnapshot(entities: places)),
              ),
              placeReverseGeocoderProvider.overrideWithValue(geocoder),
            ],
            child: MaterialApp(
              theme: ThemeData(useMaterial3: true),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const LibraryPlacesScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.textContaining('United States').first);
        await tester.pump();
        if (expandFirst) {
          await tester.dragFrom(const Offset(400, 500), const Offset(0, -360));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.dragFrom(const Offset(400, 500), const Offset(0, -200));
        }
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull, reason: 'frame $i');
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('regions arriving while the sheet is open keep the list sound', (
    tester,
  ) async {
    final geocoder = _FakeGeocoder({
      (34.05, -118.24): const PlaceLocality(
        region: 'California',
        city: 'Los Angeles',
      ),
      (34.1, -118.3): const PlaceLocality(
        region: 'California',
        city: 'Los Angeles',
      ),
      (37.77, -122.42): const PlaceLocality(
        region: 'California',
        city: 'San Francisco',
      ),
      (41.88, -87.63): const PlaceLocality(region: 'Illinois', city: 'Chicago'),
      (40.71, -74.0): const PlaceLocality(region: 'New York', city: 'New York'),
      (31.0, -81.4): const PlaceLocality(region: 'Georgia', city: 'Abby'),
    });
    final places = [
      for (final (index, (lat, lon)) in geocoder.answers.keys.indexed)
        _place('place-$index', lat, lon),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          librarySnapshotProvider.overrideWith(
            (ref) => AsyncValue.data(LibrarySnapshot(entities: places)),
          ),
          placeReverseGeocoderProvider.overrideWithValue(geocoder),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LibraryPlacesScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);

    await tester.tap(find.textContaining('United States').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('California'), findsWidgets);

    await tester.dragFrom(const Offset(400, 500), const Offset(0, -360));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.textContaining('California').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.dragFrom(const Offset(400, 300), const Offset(0, 360));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _FakeGeocoder implements PlaceReverseGeocoder {
  _FakeGeocoder(this.answers);

  final Map<(double, double), PlaceLocality> answers;

  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<PlaceLocality?> lookup(double latitude, double longitude) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return answers[(latitude, longitude)];
  }
}

LibraryEntity _place(String key, double lat, double lon) {
  final mention = EnrichedMention(
    title: 'Place $key',
    type: 'place',
    city: 'Somewhere',
    country: 'United States',
    latitude: lat,
    longitude: lon,
  );
  return LibraryEntity(
    key: key,
    provisionalKey: key,
    kind: LibraryEntityKind.place,
    mention: mention,
    sources: [
      LibrarySourceReference(
        urlId: key.hashCode,
        title: 'A saved source',
        domain: 'example.com',
        savedAt: DateTime(2026, 8, 1),
        provisionalKey: key,
        mention: mention,
      ),
    ],
    discoveredAt: DateTime(2026, 8, 1),
  );
}
