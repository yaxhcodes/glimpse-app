import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/user_collection.dart';
import 'package:glimpse/core/providers/analytics_provider.dart';
import 'package:glimpse/core/providers/service_providers.dart';
import 'package:glimpse/core/services/analytics_service.dart';
import 'package:glimpse/features/collections/collections_provider.dart';
import 'package:glimpse/features/collections/collections_preferences_provider.dart';
import 'package:glimpse/features/collections/collections_screen.dart';
import 'package:glimpse/features/library/library_entity.dart';
import 'package:glimpse/features/library/library_home.dart';
import 'package:glimpse/features/library/library_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('embedded collections stay above the shell navigation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final summaries = List.generate(20, (index) {
      final collection = UserCollection()
        ..id = index + 1
        ..name = 'Collection ${index + 1}'
        ..emoji = '📚'
        ..createdAt = DateTime(2026)
        ..urlIds = const [];
      return CollectionSummary(collection: collection, linkCount: 0);
    });

    await _pumpCollections(tester, summaries, withNavigationBar: true);

    final fabRect = tester.getRect(find.byType(FloatingActionButton));
    final navigationRect = tester.getRect(find.byType(NavigationBar));
    expect(fabRect.bottom, lessThanOrEqualTo(navigationRect.top));

    await tester.drag(
      find.byKey(const ValueKey('collections-grid')),
      const Offset(0, -10000),
    );
    await tester.pumpAndSettle();
    final lastCollectionRect = tester.getRect(find.text('Collection 1'));
    expect(lastCollectionRect.bottom, lessThanOrEqualTo(navigationRect.top));

    await tester.tap(find.byTooltip('Collection options'));
    await tester.pumpAndSettle();
    await _tapPopupItem(tester, 'List');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('collections-list')), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('collections-list')),
      const Offset(0, -10000),
    );
    await tester.pumpAndSettle();
    final lastListCollectionRect = tester.getRect(find.text('Collection 1'));
    expect(
      lastListCollectionRect.bottom,
      lessThanOrEqualTo(navigationRect.top),
    );
  });

  testWidgets('overflow menu uses compact icon-led actions', (tester) async {
    await _pumpCollections(tester, [
      _summary(1, 'First'),
      _summary(2, 'Second'),
    ]);

    await tester.tap(find.byTooltip('Collection options'));
    await tester.pumpAndSettle();

    expect(find.text('VIEW'), findsNothing);
    expect(find.text('SORT'), findsNothing);
    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
    expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);
    expect(find.byIcon(Icons.swap_vert_rounded), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    expect(find.byIcon(Icons.sort_by_alpha_rounded), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
  });

  testWidgets('Library gateway opens a dedicated screen without repetition', (
    tester,
  ) async {
    await _pumpCollections(tester, [_summary(1, 'Reading')]);

    expect(find.byKey(const ValueKey('library-gateway-card')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('collections-library-switch')),
      findsNothing,
    );
    expect(find.byType(TabBar), findsNothing);
    expect(find.byKey(const ValueKey('collections-grid')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('collections-surface-title')))
          .data,
      'Collections',
    );
    expect(find.byTooltip('Collection options'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('library-gateway-card')));
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('It builds as you save'), findsOneWidget);
    expect(find.text('Your Library'), findsNothing);
    expect(find.byKey(const ValueKey('library-gateway-card')), findsNothing);
    expect(find.byTooltip('Collection options'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('collections-grid')), findsOneWidget);
    expect(find.byTooltip('Collection options'), findsOneWidget);
  });

  testWidgets('Library gateway handles narrow dark layouts and large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpCollections(
      tester,
      const [],
      brightness: Brightness.dark,
      textScaler: const TextScaler.linear(2),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('library-gateway-card'))).width,
      288,
    );
    expect(
      find.byKey(const ValueKey('collections-library-switch')),
      findsNothing,
    );
  });

  testWidgets(
    'empty collection actions stay centered beside the Library card',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await _pumpCollections(tester, const []);

      final emptyRect = tester.getRect(
        find.byKey(const ValueKey('collections-empty')),
      );
      final contentRect = tester.getRect(
        find.byKey(const ValueKey('collections-empty-content')),
      );
      final libraryRect = tester.getRect(
        find.byKey(const ValueKey('library-gateway-card')),
      );

      expect(contentRect.center.dy, closeTo(emptyRect.center.dy, 1));
      expect(libraryRect.bottom, lessThan(contentRect.top));
      expect(
        find.widgetWithText(FilledButton, 'New collection'),
        findsOneWidget,
      );
    },
  );

  testWidgets('long press selects collections and back exits selection', (
    tester,
  ) async {
    final summaries = List.generate(
      3,
      (index) => _summary(index + 1, 'Collection ${index + 1}'),
    );
    await _pumpCollections(tester, summaries);

    await tester.longPress(find.text('Collection 1'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Exit selection'), findsOneWidget);
    expect(find.byTooltip('Edit collection'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byKey(const ValueKey('selection-selected')), findsOneWidget);

    await tester.tap(find.text('Collection 2'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit collection'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Exit selection'), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('select all and delete remove only the selected collections', (
    tester,
  ) async {
    final isar = _FakeIsarService();
    final summaries = List.generate(
      3,
      (index) => _summary(index + 1, 'Collection ${index + 1}'),
    );
    await _pumpCollections(tester, summaries, isar: isar);

    await tester.longPress(find.text('Collection 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Select all'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete selected collections'));
    await tester.pumpAndSettle();

    expect(find.text('Delete 3 collections?'), findsOneWidget);
    expect(
      find.text(
        'Their saved links will stay in your library. Only the collections '
        'will be removed.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(isar.deletedCollectionIds, {1, 2, 3});
    expect(find.text('3 collections deleted'), findsOneWidget);
    expect(find.byTooltip('Exit selection'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('selection moves all source links to an unselected collection', (
    tester,
  ) async {
    final isar = _FakeIsarService()..movedCount = 2;
    final summaries = [
      _summary(1, 'Source', urlIds: [10, 11]),
      _summary(2, 'Target', urlIds: [20]),
    ];
    await _pumpCollections(tester, summaries, isar: isar);

    await tester.longPress(find.text('Source'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Move contents'));
    await tester.pumpAndSettle();

    expect(find.text('Move links'), findsOneWidget);
    expect(
      find.text(
        'Move all 2 links from “Source”. The source collection will be deleted '
        'after the move.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(ListTile, 'Source'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Target'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Target'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Move and delete'));
    await tester.pumpAndSettle();

    expect(isar.movedSourceIds, {1});
    expect(isar.moveTargetId, 2);
    expect(
      find.text('Moved 2 links to Target and deleted the source collection'),
      findsOneWidget,
    );
    expect(find.byTooltip('Exit selection'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('overflow menu opens reorder and cancel preserves the view', (
    tester,
  ) async {
    final summaries = [
      _summary(1, 'First'),
      _summary(2, 'Second'),
      _summary(3, 'Third'),
    ];
    await _pumpCollections(tester, summaries);

    await tester.tap(find.byTooltip('Collection options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reorder'));
    await tester.pumpAndSettle();

    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.text('Drag to set your manual order'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('collections-grid')), findsOneWidget);
  });

  testWidgets('finishing reorder persists the displayed order as manual', (
    tester,
  ) async {
    final summaries = [
      _summary(1, 'First'),
      _summary(2, 'Second'),
      _summary(3, 'Third'),
    ];
    await _pumpCollections(tester, summaries);

    await tester.tap(find.byTooltip('Collection options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reorder'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(collectionsSortPrefsKey), 'manual');
    expect(prefs.getStringList(collectionsManualOrderPrefsKey), [
      '3',
      '2',
      '1',
    ]);
  });
}

Future<void> _tapPopupItem(WidgetTester tester, String label) async {
  final item = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate(
      (widget) => widget is PopupMenuItem<dynamic>,
    ),
  );
  await tester.tap(item);
}

CollectionSummary _summary(int id, String name, {List<int> urlIds = const []}) {
  final collection = UserCollection()
    ..id = id
    ..name = name
    ..emoji = 'books'
    ..createdAt = DateTime(2026, 8, id)
    ..urlIds = urlIds;
  return CollectionSummary(collection: collection, linkCount: urlIds.length);
}

Future<void> _pumpCollections(
  WidgetTester tester,
  List<CollectionSummary> summaries, {
  IsarService? isar,
  bool withNavigationBar = false,
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final home = withNavigationBar
      ? Scaffold(
          extendBody: true,
          body: const CollectionsScreen(embedded: true),
          bottomNavigationBar: NavigationBar(
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.collections_outlined),
                label: 'Collections',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                label: 'Search',
              ),
            ],
          ),
        )
      : const CollectionsScreen();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => home),
      GoRoute(
        path: '/library',
        builder: (context, state) => const LibraryScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(_FakeAnalytics()),
        collectionsSummaryProvider.overrideWith((ref) async => summaries),
        librarySnapshotProvider.overrideWith(
          (ref) => const AsyncValue.data(LibrarySnapshot(entities: [])),
        ),
        if (isar != null) isarServiceProvider.overrideWithValue(isar),
      ],
      child: MaterialApp.router(
        theme: ThemeData(useMaterial3: true, brightness: brightness),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
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

class _FakeIsarService implements IsarService {
  final Set<int> deletedCollectionIds = {};
  final Set<int> movedSourceIds = {};
  int? moveTargetId;
  int movedCount = 0;

  @override
  Future<void> deleteCollections(Iterable<int> ids) async {
    deletedCollectionIds.addAll(ids);
  }

  @override
  Future<int> moveCollectionsInto({
    required Iterable<int> sourceCollectionIds,
    required int targetCollectionId,
  }) async {
    movedSourceIds.addAll(sourceCollectionIds);
    moveTargetId = targetCollectionId;
    return movedCount;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected Isar call: ${invocation.memberName}');
  }
}
