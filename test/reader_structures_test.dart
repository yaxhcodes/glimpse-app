import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/place_itinerary.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';
import 'package:glimpse/features/library/library_entity.dart';
import 'package:glimpse/features/library/place_itinerary_provider.dart';
import 'package:glimpse/features/url_detail/reader_itinerary_section.dart';
import 'package:glimpse/features/url_detail/reader_visual_blocks.dart';
import 'package:glimpse/l10n/l10n.dart';

const _enrichment = {
  'meaningful_title': 'Three days around Issyk-Kul',
  'summary': 'A route around the lake.',
  'category': 'Travel',
  'tags': ['kyrgyzstan'],
  'places': [
    {'name': 'Karakol', 'city': 'Karakol', 'country': 'Kyrgyzstan'},
    {'name': 'Skazka Canyon', 'country': 'Kyrgyzstan'},
    {'name': 'Jeti-Oguz', 'country': 'Kyrgyzstan'},
  ],
  'itinerary': {
    'title': 'Issyk-Kul loop',
    'days': [
      {
        'day': 2,
        'title': 'South shore',
        'stops': [
          {'name': 'Skazka', 'time': '9:00', 'travel': '2 h by marshrutka'},
        ],
      },
      {
        'day': 1,
        'stops': [
          {'name': 'Karakol', 'note': 'Base for the treks'},
          {'name': 'Jeti-Oguz', 'duration': 'Half a day'},
        ],
      },
    ],
    'tips': ['Carry cash'],
  },
  'visuals': [
    {
      'kind': 'table',
      'title': 'Transport',
      'columns': ['Route', 'Price', 'Time'],
      'rows': [
        ['Bishkek → Karakol', '600 som', '6 h'],
        ['Karakol → Skazka', '400 som'],
      ],
    },
    {
      'kind': 'chart',
      'chart_type': 'line',
      'unit': '°C',
      'points': [
        {'label': 'May', 'value': 14},
        {'label': 'Jun', 'value': 19},
        {'label': 'Jul', 'value': 23},
      ],
    },
    {
      'kind': 'chart',
      'chart_type': 'share',
      'unit': 'som',
      'points': [
        {'label': 'Stay', 'value': 3000},
        {'label': 'Food', 'value': 1500},
        {'label': 'Transport', 'value': 1000},
      ],
    },
    {
      'kind': 'formula',
      'latex': r'P = \frac{m}{V}',
      'variables': [
        {'symbol': 'm', 'meaning': 'mass'},
      ],
    },
    {
      'kind': 'timeline',
      'events': [
        {'when': '1869', 'what': 'Karakol founded'},
        {'when': '1888', 'what': 'Przhevalsky dies here'},
      ],
    },
    {'kind': 'poem'},
  ],
};

void main() {
  group('enrichment model', () {
    final result = TranscriptEnrichmentResult.fromJson(_enrichment)!;

    test('reads the plan in day order and every visual kind', () {
      final itinerary = result.itinerary!;
      expect(itinerary.days.map((day) => day.day), [1, 2]);
      expect(itinerary.stopCount, 3);
      expect(itinerary.days[1].stops.single.travel, '2 h by marshrutka');
      expect(result.visuals.map((visual) => visual.kind), [
        'table',
        'chart',
        'chart',
        'formula',
        'timeline',
      ]);
      final table = result.visuals.first as EnrichedTable;
      expect(table.rows[1], ['Karakol → Skazka', '400 som', '']);
      expect((result.visuals[3] as EnrichedFormula).latex, r'P = \frac{m}{V}');
    });

    test('survives the round trip through stored JSON', () {
      final stored = TranscriptEnrichmentResult.fromJson(
        jsonDecode(jsonEncode(result.toJson())) as Map<String, dynamic>,
      )!;
      expect(
        jsonEncode(stored.itinerary!.toJson()),
        jsonEncode(result.itinerary!.toJson()),
      );
      expect(
        jsonEncode(stored.visuals.map((visual) => visual.toJson()).toList()),
        jsonEncode(result.visuals.map((visual) => visual.toJson()).toList()),
      );
    });
  });

  group('plan from a save', () {
    final result = TranscriptEnrichmentResult.fromJson(_enrichment)!;
    final savePlaces = result.mentions
        .where((mention) => mention.type == 'place')
        .toList();
    final karakol = _libraryPlace(
      'karakol-key',
      savePlaces.firstWhere((place) => place.title == 'Karakol'),
      urlId: 7,
      lat: 42.49,
      lon: 78.39,
    );

    test('keeps the days, times and notes and links the Library place', () {
      final plan = itineraryFromSave(
        urlId: 7,
        name: 'Issyk-Kul loop',
        plan: result.itinerary,
        savePlaces: savePlaces,
        libraryPlaces: [karakol],
        now: DateTime(2026, 9, 26),
      );
      expect(plan.sourceUrlId, 7);
      expect(plan.areaTitle, 'Kyrgyzstan');
      expect(plan.stops.map((stop) => (stop.title, stop.dayNumber)), [
        ('Karakol', 1),
        ('Jeti-Oguz', 1),
        ('Skazka Canyon', 2),
      ]);
      final first = plan.stops.first;
      expect(first.entityKey, 'karakol-key');
      expect(first.hasCoordinates, isTrue);
      expect(first.note, 'Base for the treks');
      // An unresolved stop keeps its name and never borrows another pin.
      expect(plan.stops[1].entityKey, isEmpty);
      expect(plan.stops[1].sourceUrlIds, isEmpty);
      expect(plan.stops[2].travel, '2 h by marshrutka');
    });

    test('without a laid-out plan, uses the save order on one day', () {
      final plan = itineraryFromSave(
        urlId: 7,
        name: 'Places',
        plan: null,
        savePlaces: savePlaces,
        libraryPlaces: [karakol],
      );
      expect(plan.stops.map((stop) => stop.title), [
        'Karakol',
        'Skazka Canyon',
        'Jeti-Oguz',
      ]);
      expect(plan.stops.every((stop) => stop.dayNumber == 1), isTrue);
    });

    test('finds a plan by the save it came from', () {
      final plan = PlaceItinerary()..sourceUrlId = 7;
      expect(itineraryFromSaveId([PlaceItinerary(), plan], 7), same(plan));
      expect(itineraryFromSaveId([plan], 8), isNull);
    });
  });

  group('time in a plan', () {
    PlaceItineraryStop stop(String title, double lat, double lon) =>
        PlaceItineraryStop()
          ..title = title
          ..latitude = lat
          ..longitude = lon;

    // Bishkek to Karakol is ~390 km by road: a day's drive on its own.
    final kyrgyzstan = [
      stop('Bishkek', 42.87, 74.59),
      stop('Ala Archa', 42.56, 74.49),
      stop('Burana Tower', 42.75, 75.25),
      stop('Karakol', 42.49, 78.39),
      stop('Jeti-Oguz', 42.33, 78.24),
      stop('Skazka Canyon', 42.16, 77.35),
    ];

    test('a country of stops is more than a day', () {
      final estimate = estimateStops(kyrgyzstan);
      expect(estimate.exceedsADay, isTrue);
      expect(estimate.days, greaterThan(1));
      expect(
        describeEstimate(estimate),
        matches(r'^about \d+(\.5)? h · \d+ km$'),
      );
    });

    test('splitting keeps the order and fits each day', () {
      final stops = [
        for (final s in kyrgyzstan) stop(s.title, s.latitude!, s.longitude!),
      ];
      assignDays(stops);
      expect(stops.map((s) => s.title), kyrgyzstan.map((s) => s.title));
      expect(stops.first.dayNumber, 1);
      expect(stops.last.dayNumber, greaterThan(1));
      for (final day in {for (final s in stops) s.dayNumber}) {
        final dayStops = stops.where((s) => s.dayNumber == day).toList();
        // A single long drive may overflow, but never with company.
        if (dayStops.length > 1) {
          expect(
            estimateStops(dayStops).hours,
            lessThanOrEqualTo(itineraryDayHours),
          );
        }
      }
    });

    test('a day counts the drive in from the day before', () {
      final stops = [
        for (final s in kyrgyzstan) stop(s.title, s.latitude!, s.longitude!),
      ];
      assignDays(stops);
      final lastDay = stops.last.dayNumber;
      final alone = estimateStops(stops.where((s) => s.dayNumber == lastDay));
      expect(estimateDay(stops, lastDay).hours, greaterThan(alone.hours));
      expect(
        estimateDay(stops, 1).hours,
        estimateStops(stops.where((s) => s.dayNumber == 1)).hours,
      );
    });

    test('a few nearby stops stay one day', () {
      final kyoto = [
        stop('Kiyomizu-dera', 34.995, 135.785),
        stop('Gion', 35.004, 135.775),
        stop('Fushimi Inari', 34.967, 135.773),
      ];
      expect(estimateStops(kyoto).exceedsADay, isFalse);
      assignDays(kyoto);
      expect(kyoto.every((s) => s.dayNumber == 1), isTrue);
    });

    test('route order starts west and walks to the nearest stop', () {
      final shuffled = [
        kyrgyzstan[3],
        kyrgyzstan[0],
        kyrgyzstan[5],
        kyrgyzstan[1],
        PlaceItineraryStop()..title = 'Unmapped',
        kyrgyzstan[2],
        kyrgyzstan[4],
      ];
      final routed = routeOrder(shuffled).map((s) => s.title).toList();
      expect(routed.first, 'Ala Archa');
      expect(routed.last, 'Unmapped');
      expect(
        routed.indexOf('Karakol'),
        greaterThan(routed.indexOf('Burana Tower')),
      );
    });
  });

  group('reader widgets', () {
    final result = TranscriptEnrichmentResult.fromJson(_enrichment)!;

    testWidgets('itinerary switches days and offers the plan', (tester) async {
      var planned = 0;
      await tester.pumpWidget(
        _app(
          ReaderItinerarySection(
            itinerary: result.itinerary!,
            accent: Colors.teal,
            hasPlan: false,
            onPlan: () => planned++,
          ),
        ),
      );
      expect(find.text('Karakol'), findsOneWidget);
      expect(find.text('Half a day'), findsOneWidget);
      expect(find.text('Carry cash'), findsOneWidget);

      await tester.tap(find.text('Day 2'));
      await tester.pumpAndSettle();
      expect(find.text('Skazka'), findsOneWidget);
      expect(find.textContaining('South shore'), findsOneWidget);

      await tester.tap(find.text('Plan this trip'));
      expect(planned, 1);
      expect(tester.takeException(), isNull);
    });

    for (final brightness in Brightness.values) {
      testWidgets('every visual block renders ($brightness)', (tester) async {
        await tester.pumpWidget(
          _app(
            Column(
              children: [
                for (final visual in result.visuals)
                  ReaderVisualBlock(visual: visual),
              ],
            ),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Bishkek → Karakol'), findsOneWidget);
        expect(find.text('Karakol → Skazka'), findsOneWidget);
        expect(find.text('Stay'), findsOneWidget);
        expect(find.text('3,000 som'), findsOneWidget);
        expect(find.text('Karakol founded'), findsOneWidget);
        expect(find.text('mass'), findsOneWidget);
      });
    }

    testWidgets('bar charts label every value with its unit', (tester) async {
      await tester.pumpWidget(
        _app(
          ReaderVisualBlock(
            visual: EnrichedVisual.fromJsonOrNull({
              'kind': 'chart',
              'unit': r'$',
              'points': [
                {'label': 'Pixel', 'value': 499},
                {'label': 'Galaxy', 'value': 449.5},
              ],
            })!,
          ),
        ),
      );
      expect(find.text(r'$499'), findsOneWidget);
      expect(find.text(r'$449.5'), findsOneWidget);
    });
  });
}

Widget _app(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: brightness),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

LibraryEntity _libraryPlace(
  String key,
  EnrichedMention mention, {
  required int urlId,
  required double lat,
  required double lon,
}) {
  final resolved = EnrichedMention(
    title: mention.title,
    type: 'place',
    city: mention.city,
    country: mention.country,
    latitude: lat,
    longitude: lon,
  );
  return LibraryEntity(
    key: key,
    provisionalKey: key,
    kind: LibraryEntityKind.place,
    mention: resolved,
    sources: [
      LibrarySourceReference(
        urlId: urlId,
        title: 'Saved reel',
        domain: 'instagram.com',
        savedAt: DateTime(2026, 9, 1),
        provisionalKey: key,
        mention: mention,
      ),
    ],
    discoveredAt: DateTime(2026, 9, 1),
  );
}
