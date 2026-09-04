import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/providers/analytics_provider.dart';
import 'package:glimpse/core/services/analytics_service.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';
import 'package:glimpse/features/library/library_browser_screen.dart';
import 'package:glimpse/features/library/library_entity.dart';
import 'package:glimpse/features/library/library_entity_detail_screen.dart';
import 'package:glimpse/features/library/library_home.dart';
import 'package:glimpse/features/library/library_music_screen.dart';
import 'package:glimpse/features/library/library_places_screen.dart';
import 'package:glimpse/features/library/library_provider.dart';
import 'package:glimpse/features/library/library_widgets.dart';
import 'package:glimpse/features/library/place_itinerary_editor_screen.dart';
import 'package:glimpse/features/library/place_itinerary_provider.dart';
import 'package:glimpse/shared/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _goldenBoundaryKey = ValueKey('library-golden-boundary');
const _seed = Color(0xFF6750A4);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'glimpse_default_music_provider': 'spotify',
    }),
  );

  setUpAll(() async {
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await materialIcons.load();
  });

  final fixtures = _fixtures();
  testWidgets('Library home compactAmoled', (tester) async {
    await _pumpGolden(
      tester,
      layout: _GoldenLayout.compactDark,
      snapshot: LibrarySnapshot(entities: [...fixtures, ..._musicFixtures()]),
      darkTheme: AppTheme.amoledTheme(
        AppAccentColor.monochrome.seedColor!,
        schemeVariant: AppAccentColor.monochrome.schemeVariant,
      ),
      child: const LibraryScreen(),
    );
    await _expectGolden(tester, 'goldens/library_home_compactAmoled.png');
  });
  for (final layout in _GoldenLayout.values) {
    testWidgets('Library home ${layout.name}', (tester) async {
      await _pumpGolden(
        tester,
        layout: layout,
        snapshot: LibrarySnapshot(entities: [...fixtures, ..._musicFixtures()]),
        child: const LibraryScreen(),
      );
      await _expectGolden(tester, 'goldens/library_home_${layout.name}.png');
    });

    testWidgets('Library music ${layout.name}', (tester) async {
      await _pumpGolden(
        tester,
        layout: layout,
        snapshot: LibrarySnapshot(entities: _musicFixtures()),
        child: const LibraryMusicScreen(),
      );
      await _expectGolden(tester, 'goldens/library_music_${layout.name}.png');
    });

    testWidgets('Library music detail ${layout.name}', (tester) async {
      final music = _musicFixtures();
      await _pumpGolden(
        tester,
        layout: layout,
        snapshot: LibrarySnapshot(entities: music),
        child: LibraryEntityDetailScreen(entityKey: music.first.key),
      );
      await _expectGolden(
        tester,
        'goldens/library_music_detail_${layout.name}.png',
      );
    });

    testWidgets('Library browser ${layout.name}', (tester) async {
      await _pumpGolden(
        tester,
        layout: layout,
        snapshot: LibrarySnapshot(entities: fixtures),
        child: const LibraryBrowserScreen(kind: LibraryEntityKind.book),
      );
      await _expectGolden(tester, 'goldens/library_browser_${layout.name}.png');
    });

    testWidgets('Library detail ${layout.name}', (tester) async {
      await _pumpGolden(
        tester,
        layout: layout,
        snapshot: LibrarySnapshot(entities: fixtures),
        child: LibraryEntityDetailScreen(entityKey: fixtures.first.key),
      );
      await _expectGolden(tester, 'goldens/library_detail_${layout.name}.png');
    });

    testWidgets('Library places ${layout.name}', (tester) async {
      await _pumpGolden(
        tester,
        layout: layout,
        snapshot: LibrarySnapshot(entities: _unmappedPlaceFixtures()),
        child: const LibraryPlacesScreen(),
      );
      await _expectGolden(tester, 'goldens/library_places_${layout.name}.png');
    });
  }

  testWidgets('Library music provider menu compactDark', (tester) async {
    await _pumpGolden(
      tester,
      layout: _GoldenLayout.compactDark,
      snapshot: LibrarySnapshot(entities: _musicFixtures()),
      child: const LibraryMusicScreen(),
    );
    await tester.tap(find.byTooltip('Music options'));
    await tester.pumpAndSettle();
    await _expectGolden(
      tester,
      'goldens/library_music_provider_menu_compactDark.png',
    );
  });

  testWidgets('Library places expanded compactDark', (tester) async {
    await _pumpGolden(
      tester,
      layout: _GoldenLayout.compactDark,
      snapshot: LibrarySnapshot(entities: _unmappedPlaceFixtures()),
      child: const LibraryPlacesScreen(),
    );
    await tester.dragFrom(const Offset(195, 770), const Offset(0, -440));
    await tester.pumpAndSettle();
    await _expectGolden(
      tester,
      'goldens/library_places_expanded_compactDark.png',
    );
  });

  testWidgets('Place itinerary editor compactDark', (tester) async {
    final places = _itineraryPlaceFixtures();
    await _pumpGolden(
      tester,
      layout: _GoldenLayout.compactDark,
      snapshot: LibrarySnapshot(entities: places),
      child: const PlaceItineraryEditorScreen(
        draft: PlaceItineraryDraft(
          areaKey: 'new delhi|india',
          areaTitle: 'New Delhi',
          country: 'India',
          focusedEntityKey: 'place-parliament',
        ),
      ),
    );
    await _expectGolden(
      tester,
      'goldens/place_itinerary_editor_compactDark.png',
    );
  });

  testWidgets('Library radial status compactDark', (tester) async {
    await _pumpGolden(
      tester,
      layout: _GoldenLayout.compactDark,
      snapshot: LibrarySnapshot(entities: fixtures),
      child: const LibraryBrowserScreen(kind: LibraryEntityKind.book),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(LibraryEntityTile).first),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await gesture.moveBy(const Offset(0, -90));
    await tester.pumpAndSettle();

    await _expectGolden(
      tester,
      'goldens/library_radial_status_compactDark.png',
    );
    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('Library options menu compactDark', (tester) async {
    await _pumpGolden(
      tester,
      layout: _GoldenLayout.compactDark,
      snapshot: LibrarySnapshot(entities: fixtures),
      child: const LibraryBrowserScreen(kind: LibraryEntityKind.book),
    );

    await tester.tap(find.byTooltip('Books options'));
    await tester.pumpAndSettle();
    await _expectGolden(tester, 'goldens/library_options_menu_compactDark.png');
  });
}

enum _GoldenLayout {
  compactLight(Size(390, 844), false),
  compactDark(Size(390, 844), true),
  tabletLight(Size(1024, 900), false);

  const _GoldenLayout(this.size, this.dark);

  final Size size;
  final bool dark;
}

Future<void> _pumpGolden(
  WidgetTester tester, {
  required _GoldenLayout layout,
  required LibrarySnapshot snapshot,
  required Widget child,
  ThemeData? darkTheme,
}) async {
  tester.view.physicalSize = layout.size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(_FakeAnalytics()),
        librarySnapshotProvider.overrideWith(
          (ref) => AsyncValue.data(snapshot),
        ),
        placeItinerariesProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: RepaintBoundary(
        key: _goldenBoundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(_seed),
          darkTheme: darkTheme ?? AppTheme.darkTheme(_seed),
          themeMode: layout.dark ? ThemeMode.dark : ThemeMode.light,
          home: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expectGolden(WidgetTester tester, String path) async {
  for (final element in tester.allElements) {
    element.renderObject?.markNeedsPaint();
  }
  await tester.pump();
  await expectLater(find.byKey(_goldenBoundaryKey), matchesGoldenFile(path));
}

List<LibraryEntity> _fixtures() => [
  _entity(
    key: 'book-piranesi',
    kind: LibraryEntityKind.book,
    title: 'Piranesi',
    creator: 'Susanna Clarke',
    year: '2020',
    genres: const ['Fiction', 'Fantasy'],
    status: LibraryItemStatus.active,
    pageCount: 272,
    currentPage: 84,
    discoveredAt: DateTime(2026, 8, 6),
    why: 'A quiet recommendation about memory, wonder, and solitude.',
  ),
  _entity(
    key: 'book-sea',
    kind: LibraryEntityKind.book,
    title: 'The Sea Around Us',
    creator: 'Rachel Carson',
    year: '1951',
    genres: const ['Science'],
    status: LibraryItemStatus.planning,
    discoveredAt: DateTime(2026, 8, 4),
  ),
  _entity(
    key: 'book-design',
    kind: LibraryEntityKind.book,
    title: 'The Design of Everyday Things',
    creator: 'Don Norman',
    year: '2013',
    genres: const ['Technology'],
    discoveredAt: DateTime(2026, 8, 2),
  ),
  _entity(
    key: 'movie-days',
    kind: LibraryEntityKind.movie,
    title: 'Perfect Days',
    year: '2023',
    genres: const ['Drama'],
    status: LibraryItemStatus.completed,
    discoveredAt: DateTime(2026, 8, 5),
  ),
  _entity(
    key: 'movie-lighthouse',
    kind: LibraryEntityKind.movie,
    title: 'The Lighthouse',
    year: '2019',
    genres: const ['Horror'],
    discoveredAt: DateTime(2026, 8, 3),
  ),
  _entity(
    key: 'place-jantar',
    kind: LibraryEntityKind.place,
    title: 'Jantar Mantar',
    city: 'New Delhi',
    country: 'India',
    latitude: 28.6271,
    longitude: 77.2166,
    discoveredAt: DateTime(2026, 8, 1),
  ),
];

List<LibraryEntity> _musicFixtures() => [
  _entity(
    key: 'music-teardrop',
    kind: LibraryEntityKind.music,
    title: 'Teardrop',
    creator: 'Massive Attack',
    discoveredAt: DateTime(2026, 8, 6),
    why: 'A trip-hop recommendation for a quiet evening.',
  ),
  _entity(
    key: 'music-radiohead',
    kind: LibraryEntityKind.music,
    title: 'Everything In Its Right Place',
    creator: 'Radiohead',
    discoveredAt: DateTime(2026, 8, 5),
  ),
  _entity(
    key: 'music-sade',
    kind: LibraryEntityKind.music,
    title: 'No Ordinary Love',
    creator: 'Sade',
    discoveredAt: DateTime(2026, 8, 4),
  ),
];

List<LibraryEntity> _unmappedPlaceFixtures() => [
  _entity(
    key: 'place-kinkakuji',
    kind: LibraryEntityKind.place,
    title: 'Kinkaku-ji',
    city: 'Kyoto',
    country: 'Japan',
    status: LibraryItemStatus.planning,
    discoveredAt: DateTime(2026, 8, 8),
  ),
  _entity(
    key: 'place-philosophers-path',
    kind: LibraryEntityKind.place,
    title: "Philosopher's Path",
    city: 'Kyoto',
    country: 'Japan',
    discoveredAt: DateTime(2026, 8, 7),
  ),
  _entity(
    key: 'place-skógafoss',
    kind: LibraryEntityKind.place,
    title: 'Skógafoss',
    country: 'Iceland',
    status: LibraryItemStatus.completed,
    discoveredAt: DateTime(2026, 8, 5),
  ),
];

List<LibraryEntity> _itineraryPlaceFixtures() => [
  _entity(
    key: 'place-parliament',
    kind: LibraryEntityKind.place,
    title: 'Parliament House',
    city: 'New Delhi',
    country: 'India',
    latitude: 28.6172,
    longitude: 77.2081,
    status: LibraryItemStatus.planning,
    discoveredAt: DateTime(2026, 8, 8),
  ),
  _entity(
    key: 'place-jantar-mantar',
    kind: LibraryEntityKind.place,
    title: 'Jantar Mantar Astronomical Observatory',
    city: 'New Delhi',
    country: 'India',
    latitude: 28.6271,
    longitude: 77.2166,
    status: LibraryItemStatus.planning,
    discoveredAt: DateTime(2026, 8, 7),
  ),
];

LibraryEntity _entity({
  required String key,
  required LibraryEntityKind kind,
  required String title,
  required DateTime discoveredAt,
  String? creator,
  String? year,
  List<String> genres = const [],
  LibraryItemStatus status = LibraryItemStatus.unlisted,
  int? pageCount,
  int? currentPage,
  String? city,
  String? country,
  double? latitude,
  double? longitude,
  String? why,
}) {
  final mention = EnrichedMention(
    title: title,
    type: kind.name,
    creator: creator,
    year: year,
    whyMentioned: why,
    posterUrl: kind == LibraryEntityKind.place ? null : ' ',
    genres: genres,
    catalogId: key,
    catalogSource: 'golden-fixture',
    city: city,
    country: country,
    latitude: latitude,
    longitude: longitude,
    libraryStatus: status.name,
    pageCount: pageCount ?? (kind == LibraryEntityKind.book ? 300 : null),
    currentPage: currentPage,
  );
  return LibraryEntity(
    key: key,
    provisionalKey: key,
    kind: kind,
    mention: mention,
    sources: [
      LibrarySourceReference(
        urlId: key.hashCode,
        title: 'A saved recommendation',
        domain: 'example.com',
        savedAt: discoveredAt,
        provisionalKey: key,
        mention: mention,
      ),
    ],
    discoveredAt: discoveredAt,
  );
}

class _FakeAnalytics implements AnalyticsService {
  @override
  String get sessionId => 'golden-test';

  @override
  Future<void> dispose() async {}

  @override
  Future<void> flush() async {}

  @override
  Future<void> handleLifecycleState(AppLifecycleState state) async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> trackEvent(
    AnalyticsEvent event, {
    AnalyticsScreen? screen,
  }) async {}

  @override
  Future<void> trackScreen(AnalyticsScreen screen) async {}
}
