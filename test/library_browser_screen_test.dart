import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';
import 'package:glimpse/features/library/library_browser_screen.dart';
import 'package:glimpse/features/library/library_entity.dart';
import 'package:glimpse/features/library/library_provider.dart';
import 'package:glimpse/features/library/library_widgets.dart';

void main() {
  testWidgets('searches, filters, clears, and applies every sort order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final entities = [
      _book(
        key: 'gamma',
        title: 'Gamma',
        year: '2020',
        genre: 'History',
        status: LibraryItemStatus.completed,
        discoveredAt: DateTime(2026, 8, 3),
      ),
      _book(
        key: 'alpha',
        title: 'Alpha',
        year: '2025',
        genre: 'Fiction',
        status: LibraryItemStatus.planning,
        discoveredAt: DateTime(2026, 8, 1),
      ),
      _book(
        key: 'beta',
        title: 'Beta',
        year: '2023',
        genre: 'Fiction',
        status: LibraryItemStatus.active,
        discoveredAt: DateTime(2026, 8, 2),
      ),
    ];
    await tester.pumpWidget(_browserApp(entities));
    await tester.pump();

    expect(_visibleTitles(tester), ['Gamma', 'Beta', 'Alpha']);

    await _chooseSort(tester, 'Title A–Z');
    expect(_visibleTitles(tester), ['Alpha', 'Beta', 'Gamma']);
    await _chooseSort(tester, 'Year newest');
    expect(_visibleTitles(tester), ['Alpha', 'Beta', 'Gamma']);
    await _chooseSort(tester, 'Status');
    expect(_visibleTitles(tester), ['Alpha', 'Beta', 'Gamma']);
    await _chooseSort(tester, 'Recently discovered');
    expect(_visibleTitles(tester), ['Gamma', 'Beta', 'Alpha']);

    await tester.tap(find.byTooltip('Books options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Planning'),
      ),
    );
    await tester.tap(find.text('Fiction'));
    await tester.tap(find.text('Show items'));
    await tester.pumpAndSettle();

    expect(_visibleTitles(tester), ['Alpha']);
    expect(find.widgetWithText(InputChip, 'Planning'), findsOneWidget);
    expect(find.text('Fiction'), findsWidgets);

    await tester.tap(find.text('Clear all'));
    await tester.pump();
    expect(_visibleTitles(tester), ['Gamma', 'Beta', 'Alpha']);

    await tester.enterText(find.byType(SearchBar), 'missing title');
    await tester.pump();
    expect(find.text('Nothing matches these filters.'), findsOneWidget);
    await tester.tap(find.text('Clear search'));
    await tester.pump();
    expect(_visibleTitles(tester), ['Gamma', 'Beta', 'Alpha']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hold and drag changes status without opening detail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final actions = _FakeLibraryEntityActions();
    final entity = _book(
      key: 'quick-status',
      title: 'Piranesi',
      year: '2020',
      genre: 'Fiction',
      status: LibraryItemStatus.unlisted,
      discoveredAt: DateTime(2026, 8, 1),
    );
    await tester.pumpWidget(_browserApp([entity], actions: actions));
    await tester.pump();

    final tile = find.byType(LibraryEntityTile);
    final gesture = await tester.startGesture(tester.getCenter(tile));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('library-radial-status-overlay')),
      findsOneWidget,
    );
    await gesture.moveBy(const Offset(0, -90));
    await tester.pumpAndSettle();
    expect(find.text('Reading'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('library-radial-status-overlay')),
      findsNothing,
    );
    expect(actions.lastEntity?.key, entity.key);
    expect(actions.lastStatus, LibraryItemStatus.active);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the selected action as a badge on the card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var status = LibraryItemStatus.unlisted;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 174,
              height: 360,
              child: StatefulBuilder(
                builder: (context, setState) {
                  final entity = _book(
                    key: 'status-card',
                    title: 'Piranesi',
                    year: '2020',
                    genre: 'Fiction',
                    status: status,
                    discoveredAt: DateTime(2026, 8, 1),
                  );
                  return LibraryEntityTile(
                    entity: entity,
                    onTap: () {},
                    onStatusSelected: (selected) =>
                        setState(() => status = selected),
                    onStatusMenuRequested: () {},
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('library-status-badge-status-card')),
      findsNothing,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(LibraryEntityTile)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    final origin = tester.getCenter(
      find.byKey(const ValueKey('library-radial-origin')),
    );
    final droppedAction = tester.getCenter(
      find.byKey(const ValueKey('library-radial-dropped')),
    );
    await gesture.moveBy(droppedAction - origin);
    await tester.pumpAndSettle();
    expect(find.text('Dropped'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('library-status-badge-status-card')),
      findsOneWidget,
    );
    expect(find.text('Dropped'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('held cards lean toward their side of the grid', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final entities = [
      _book(
        key: 'left-card',
        title: 'Left Card',
        year: '2024',
        genre: 'Fiction',
        status: LibraryItemStatus.unlisted,
        discoveredAt: DateTime(2026, 8, 2),
      ),
      _book(
        key: 'right-card',
        title: 'Right Card',
        year: '2025',
        genre: 'History',
        status: LibraryItemStatus.unlisted,
        discoveredAt: DateTime(2026, 8, 1),
      ),
    ];
    await tester.pumpWidget(_browserApp(entities));
    await tester.pump();

    final tiles = find.byType(LibraryEntityTile);
    final leftGesture = await tester.startGesture(
      tester.getCenter(tiles.first),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('library-radial-preview-left')),
      findsOneWidget,
    );
    final leftTransform = tester.widget<Transform>(
      find.byKey(const ValueKey('library-radial-preview-left')),
    );
    expect(leftTransform.transform.entry(0, 1), greaterThan(0));
    final origin = tester.getCenter(
      find.byKey(const ValueKey('library-radial-origin')),
    );
    for (final status in LibraryItemStatus.values.skip(1)) {
      final option = tester.getCenter(
        find.byKey(ValueKey('library-radial-${status.name}')),
      );
      final offset = option - origin;
      expect(offset.distance, lessThanOrEqualTo(80));
      expect(offset.dy, lessThanOrEqualTo(8));
    }
    await leftGesture.cancel();
    await tester.pumpAndSettle();

    final rightGesture = await tester.startGesture(
      tester.getCenter(tiles.last),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('library-radial-preview-right')),
      findsOneWidget,
    );
    final rightTransform = tester.widget<Transform>(
      find.byKey(const ValueKey('library-radial-preview-right')),
    );
    expect(rightTransform.transform.entry(0, 1), lessThan(0));
    await rightGesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Widget _browserApp(
  List<LibraryEntity> entities, {
  LibraryEntityActions? actions,
}) {
  return ProviderScope(
    overrides: [
      librarySnapshotProvider.overrideWith(
        (ref) => AsyncValue.data(LibrarySnapshot(entities: entities)),
      ),
      if (actions != null)
        libraryEntityActionsProvider.overrideWithValue(actions),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: const LibraryBrowserScreen(kind: LibraryEntityKind.book),
    ),
  );
}

List<String> _visibleTitles(WidgetTester tester) => tester
    .widgetList<LibraryEntityTile>(find.byType(LibraryEntityTile))
    .map((tile) => tile.entity.title)
    .toList(growable: false);

Future<void> _chooseSort(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Books options'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

LibraryEntity _book({
  required String key,
  required String title,
  required String year,
  required String genre,
  required LibraryItemStatus status,
  required DateTime discoveredAt,
}) {
  final mention = EnrichedMention(
    title: title,
    type: 'book',
    creator: 'Author of $title',
    year: year,
    genres: [genre],
    libraryStatus: status.name,
  );
  return LibraryEntity(
    key: key,
    provisionalKey: key,
    kind: LibraryEntityKind.book,
    mention: mention,
    sources: [
      LibrarySourceReference(
        urlId: key.hashCode,
        title: 'A saved source',
        domain: 'example.com',
        savedAt: discoveredAt,
        provisionalKey: key,
        mention: mention,
      ),
    ],
    discoveredAt: discoveredAt,
  );
}

class _FakeLibraryEntityActions implements LibraryEntityActions {
  LibraryEntity? lastEntity;
  LibraryItemStatus? lastStatus;

  @override
  Future<void> setStatus(LibraryEntity entity, LibraryItemStatus status) async {
    lastEntity = entity;
    lastStatus = status;
  }
}
