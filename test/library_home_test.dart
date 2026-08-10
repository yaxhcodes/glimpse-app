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
import 'package:glimpse/features/library/library_places_screen.dart';
import 'package:glimpse/features/library/library_provider.dart';
import 'package:glimpse/features/library/library_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the compact-phone empty state', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const LibrarySnapshot(entities: [])));
    await tester.pump();

    expect(find.text('Your Library will build itself'), findsOneWidget);
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

    expect(find.text('Books'), findsOneWidget);
    expect(find.text('12 books'), findsOneWidget);
    expect(find.text('4 places'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
            (ref) => Stream.value(LibrarySnapshot(entities: [place])),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const LibraryPlacesScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.dragFrom(
      const Offset(400, 500),
      const Offset(0, -360),
    );
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
            (ref) => Stream.value(LibrarySnapshot(entities: [entity])),
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
          (ref) => Stream.value(LibrarySnapshot(entities: [entity])),
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

Widget _app(LibrarySnapshot snapshot, {ThemeData? theme}) {
  return ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(_FakeAnalytics()),
      librarySnapshotProvider.overrideWith((ref) => Stream.value(snapshot)),
    ],
    child: MaterialApp(
      theme: theme ?? ThemeData(useMaterial3: true),
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

  @override
  Future<void> setStatus(LibraryEntity entity, LibraryItemStatus status) async {
    lastStatus = status;
  }
}
