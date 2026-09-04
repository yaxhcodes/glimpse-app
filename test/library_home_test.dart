import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:glimpse/core/providers/analytics_provider.dart';
import 'package:glimpse/core/services/analytics_service.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';
import 'package:glimpse/features/library/library_entity.dart';
import 'package:glimpse/features/library/library_entity_detail_screen.dart';
import 'package:glimpse/features/library/library_home.dart';
import 'package:glimpse/features/library/library_music_screen.dart';
import 'package:glimpse/features/library/library_places_screen.dart';
import 'package:glimpse/features/library/library_provider.dart';
import 'package:glimpse/features/library/library_widgets.dart';
import 'package:glimpse/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('opens Music from the Library before any discoveries', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const LibraryScreen()),
        GoRoute(
          path: '/library/music',
          builder: (_, _) => const LibraryMusicScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analyticsServiceProvider.overrideWithValue(_FakeAnalytics()),
          librarySnapshotProvider.overrideWith(
            (ref) => const AsyncValue.data(LibrarySnapshot(entities: [])),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Music'));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryMusicScreen), findsOneWidget);
    expect(find.text('Where do you listen?'), findsOneWidget);
    expect(find.text('Music app'), findsNothing);
    expect(find.byTooltip('Music options'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the compact-phone empty state', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const LibrarySnapshot(entities: [])));
    await tester.pump();

    expect(find.text('It builds as you save'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a large Library in dark tablet layout', (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final entities = [
      for (var index = 0; index < 12; index++)
        _entity(
          key: 'book-$index',
          kind: LibraryEntityKind.book,
          mention: EnrichedMention(
            title: 'Book $index',
            type: 'book',
            creator: 'Author $index',
            posterUrl: 'https://invalid.example/$index.jpg',
            genres: const ['Fiction'],
            catalogId: 'OL$index',
            catalogSource: 'openlibrary',
          ),
        ),
      for (var index = 0; index < 4; index++)
        _entity(
          key: 'place-$index',
          kind: LibraryEntityKind.place,
          mention: EnrichedMention(
            title: 'Place $index',
            type: 'place',
            city: 'City',
            country: 'Country',
            latitude: 20 + index.toDouble(),
            longitude: 70 + index.toDouble(),
            catalogId: 'place-$index',
            catalogSource: 'geoapify',
          ),
        ),
    ];

    await tester.pumpWidget(
      _app(
        LibrarySnapshot(entities: entities),
        theme: ThemeData.dark(useMaterial3: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Found in your saves'), findsOneWidget);
    expect(find.text('Your Library'), findsNothing);
    expect(find.text('Books'), findsOneWidget);
    expect(find.text('12 books'), findsOneWidget);
    expect(find.text('4 places'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets(
      'keeps Library destinations readable at $width with large text',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final snapshot = LibrarySnapshot(
          entities: [
            for (final kind in LibraryEntityKind.values)
              _entity(
                key: kind.name,
                kind: kind,
                mention: EnrichedMention(
                  title: 'A saved ${kind.name}',
                  type: kind.name,
                  catalogId: kind.name,
                  catalogSource: 'test',
                ),
              ),
          ],
        );

        for (final locale in AppLocalizations.supportedLocales) {
          final strings = await AppLocalizations.delegate.load(locale);
          await tester.pumpWidget(
            _app(
              snapshot,
              locale: locale,
              textScaler: const TextScaler.linear(2),
            ),
          );
          await tester.pump();

          for (final label in [
            strings.libraryBooks,
            strings.libraryMoviesShows,
            strings.libraryPlaces,
            strings.libraryMusic,
          ]) {
            final destination = find.text(label);
            expect(destination, findsOneWidget);
            await tester.ensureVisible(destination);
            await tester.pump();
            expect(tester.takeException(), isNull, reason: '$locale: $label');
            expect(
              find.ancestor(of: destination, matching: find.byType(InkWell)),
              findsOneWidget,
            );
          }
          expect(find.text(strings.libraryMovieCount(1)), findsOneWidget);
        }
      },
    );
  }

  testWidgets('uses a typographic placeholder when artwork is missing', (
    tester,
  ) async {
    final entity = _entity(
      key: 'missing-cover',
      kind: LibraryEntityKind.book,
      mention: const EnrichedMention(
        title: 'Piranesi',
        type: 'book',
        creator: 'Susanna Clarke',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: LibraryArtwork(entity: entity)),
      ),
    );

    expect(find.text('BOOK'), findsOneWidget);
    expect(find.text('Piranesi'), findsOneWidget);
    expect(find.text('Susanna Clarke'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps uncertain places in an unmapped list', (tester) async {
    final place = _entity(
      key: 'unmapped-place',
      kind: LibraryEntityKind.place,
      mention: const EnrichedMention(
        title: 'A tiny ramen shop',
        type: 'place',
        city: 'Tokyo',
        country: 'Japan',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          librarySnapshotProvider.overrideWith(
            (ref) => AsyncValue.data(LibrarySnapshot(entities: [place])),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const LibraryPlacesScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.dragFrom(const Offset(400, 500), const Offset(0, -360));
    await tester.pumpAndSettle();

    expect(find.text('A tiny ramen shop'), findsOneWidget);
    expect(find.textContaining('Location unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manages reading status without provenance dividers', (
    tester,
  ) async {
    final entity = _entity(
      key: 'reading-status',
      kind: LibraryEntityKind.book,
      mention: const EnrichedMention(
        title: 'Piranesi',
        type: 'book',
        creator: 'Susanna Clarke',
        year: '2020',
        genres: ['Fiction'],
      ),
    );
    final actions = _FakeLibraryEntityActions();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          librarySnapshotProvider.overrideWith(
            (ref) => AsyncValue.data(LibrarySnapshot(entities: [entity])),
          ),
          libraryEntityActionsProvider.overrideWithValue(actions),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: LibraryEntityDetailScreen(entityKey: entity.key),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Add to your reading list'), findsOneWidget);
    final metadataTop = tester
        .getTopLeft(find.text('Susanna Clarke · 2020').last)
        .dy;
    final genreTop = tester.getTopLeft(find.text('Fiction')).dy;
    final statusTop = tester
        .getTopLeft(find.text('Add to your reading list'))
        .dy;
    expect(genreTop, greaterThan(metadataTop));
    expect(genreTop, lessThan(statusTop));
    final expansion = tester.widget<ExpansionTile>(find.byType(ExpansionTile));
    expect(
      (expansion.shape! as RoundedRectangleBorder).side.style,
      BorderStyle.none,
    );

    await tester.tap(find.text('Add to your reading list'));
    await tester.pumpAndSettle();
    expect(find.text('Reading status'), findsOneWidget);
    await tester.tap(find.text('Reading'));
    await tester.pumpAndSettle();

    expect(actions.lastStatus, LibraryItemStatus.active);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows authoritative movie details and keeps why it mattered', (
    tester,
  ) async {
    final entity = _entity(
      key: 'blade-runner',
      kind: LibraryEntityKind.movie,
      mention: const EnrichedMention(
        title: 'Blade Runner',
        type: 'movie',
        year: '1982',
        genres: ['Action', 'Drama', 'Science Fiction'],
        catalogId: 'tt0083658',
        catalogSource: 'omdb',
        plot: 'A blade runner pursues four escaped replicants.',
        imdbRating: 8.1,
        whyMentioned: 'It defined the visual language of cyberpunk cinema.',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          librarySnapshotProvider.overrideWith(
            (ref) => AsyncValue.data(LibrarySnapshot(entities: [entity])),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: LibraryEntityDetailScreen(entityKey: entity.key),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Action'), findsOneWidget);
    expect(find.text('Drama'), findsOneWidget);
    expect(find.text('Science Fiction'), findsOneWidget);
    expect(find.text('8.1 IMDb'), findsOneWidget);
    expect(find.text('Plot'), findsOneWidget);
    expect(
      find.text('A blade runner pursues four escaped replicants.'),
      findsOneWidget,
    );
    expect(find.text('Why it mattered'), findsOneWidget);
    expect(
      find.text('It defined the visual language of cyberpunk cinema.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('updates the bookmark for a book being read', (tester) async {
    final entity = _entity(
      key: 'reading-progress',
      kind: LibraryEntityKind.book,
      mention: const EnrichedMention(
        title: 'Piranesi',
        type: 'book',
        creator: 'Susanna Clarke',
        year: '2020',
        genres: ['Fiction'],
        libraryStatus: 'active',
        pageCount: 272,
        currentPage: 84,
      ),
    );
    final actions = _FakeLibraryEntityActions();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          librarySnapshotProvider.overrideWith(
            (ref) => AsyncValue.data(LibrarySnapshot(entities: [entity])),
          ),
          libraryEntityActionsProvider.overrideWithValue(actions),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: LibraryEntityDetailScreen(entityKey: entity.key),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('library-reading-progress-card')),
      findsOneWidget,
    );
    expect(find.text('Page 84 · about 272 pages'), findsOneWidget);

    await tester.tap(find.text('Update page'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('library-current-page-field')),
      '101',
    );
    await tester.tap(find.text('Save bookmark'));
    await tester.pumpAndSettle();

    expect(actions.lastPage, 101);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides a Library item and restores it with Snackbar Undo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final entity = _entity(
      key: 'hide-undo',
      kind: LibraryEntityKind.movie,
      mention: const EnrichedMention(
        title: 'Perfect Days',
        type: 'movie',
        year: '2023',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        librarySnapshotProvider.overrideWith(
          (ref) => AsyncValue.data(LibrarySnapshot(entities: [entity])),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => context.push('/detail'),
                child: const Text('Open detail'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/detail',
          builder: (context, state) =>
              LibraryEntityDetailScreen(entityKey: entity.key),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(useMaterial3: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Library item options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide from Library'));
    await tester.pumpAndSettle();

    expect(
      container
          .read(libraryPreferencesProvider)
          .hiddenEntityKeys
          .contains(entity.key),
      isTrue,
    );
    expect(find.text('Perfect Days hidden from Library'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(libraryPreferencesProvider)
          .hiddenEntityKeys
          .contains(entity.key),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _app(
  LibrarySnapshot snapshot, {
  ThemeData? theme,
  Locale? locale,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(_FakeAnalytics()),
      librarySnapshotProvider.overrideWith((ref) => AsyncValue.data(snapshot)),
    ],
    child: MaterialApp(
      theme: theme ?? ThemeData(useMaterial3: true),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: const Scaffold(body: LibraryHome()),
    ),
  );
}

LibraryEntity _entity({
  required String key,
  required LibraryEntityKind kind,
  required EnrichedMention mention,
}) {
  return LibraryEntity(
    key: key,
    provisionalKey: key,
    kind: kind,
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

class _FakeAnalytics implements AnalyticsService {
  @override
  String get sessionId => 'test';

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

class _FakeLibraryEntityActions implements LibraryEntityActions {
  LibraryItemStatus? lastStatus;
  int? lastPage;

  @override
  Future<void> setStatus(LibraryEntity entity, LibraryItemStatus status) async {
    lastStatus = status;
  }

  @override
  Future<void> setReadingPage(LibraryEntity entity, int page) async {
    lastPage = page;
  }
}
