import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/user_collection.dart';
import 'package:glimpse/features/collections/collection_card.dart';
import 'package:glimpse/features/collections/collections_provider.dart';

void main() {
  testWidgets('shows the description and falls back to the link count', (
    tester,
  ) async {
    final collection = _collection(
      id: 1,
      description: '  Places worth returning to  ',
      urlIds: const [1, 2, 3, 4],
    );

    await _pumpCard(
      tester,
      CollectionSummary(collection: collection, linkCount: 4),
    );

    expect(find.text('Places worth returning to'), findsOneWidget);
    expect(find.text('4 links'), findsNothing);

    collection.description = '  ';
    await _pumpCard(
      tester,
      CollectionSummary(collection: collection, linkCount: 4),
    );

    expect(find.text('4 links'), findsOneWidget);
  });

  testWidgets(
    'shows previews for one to three saves without an overflow tile',
    (tester) async {
      for (var count = 1; count <= 3; count++) {
        final urls = List.generate(count, (index) => _savedUrl(index + 1));
        await _pumpCard(
          tester,
          CollectionSummary(
            collection: _collection(
              id: count,
              urlIds: urls.map((url) => url.id).toList(),
            ),
            linkCount: count,
            previewUrls: urls,
          ),
        );

        for (final url in urls) {
          expect(
            find.byKey(ValueKey('collection-preview-thumbnail-${url.id}')),
            findsOneWidget,
          );
        }
        expect(
          find.byKey(const ValueKey('collection-preview-overflow')),
          findsNothing,
        );
      }
    },
  );

  testWidgets(
    'shows two thumbnails and the remaining count above three saves',
    (tester) async {
      final urls = List.generate(3, (index) => _savedUrl(index + 1));

      await _pumpCard(
        tester,
        CollectionSummary(
          collection: _collection(id: 1, urlIds: const [1, 2, 3, 4]),
          linkCount: 4,
          previewUrls: urls,
        ),
      );

      expect(
        find.byKey(const ValueKey('collection-preview-thumbnail-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('collection-preview-thumbnail-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('collection-preview-thumbnail-3')),
        findsNothing,
      );
      expect(find.text('+2'), findsOneWidget);
    },
  );

  testWidgets('omits the preview for an empty collection', (tester) async {
    await _pumpCard(
      tester,
      CollectionSummary(
        collection: _collection(id: 8, urlIds: const []),
        linkCount: 0,
      ),
    );

    expect(
      find.byKey(const ValueKey('collection-thumbnail-preview-8')),
      findsNothing,
    );
    expect(find.text('No links'), findsOneWidget);
  });

  testWidgets('missing thumbnails use the existing letter fallback', (
    tester,
  ) async {
    final url = _savedUrl(1);

    await _pumpCard(
      tester,
      CollectionSummary(
        collection: _collection(id: 1, urlIds: const [1]),
        linkCount: 1,
        previewUrls: [url],
      ),
    );

    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('long content and previews do not overflow a narrow display', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final urls = List.generate(3, (index) => _savedUrl(index + 1));

    await _pumpCard(
      tester,
      CollectionSummary(
        collection: _collection(
          id: 1,
          name: 'A deliberately long collection name for a narrow phone',
          description:
              'A deliberately long description that must remain on one line',
          urlIds: const [1, 2, 3, 4, 5],
        ),
        linkCount: 5,
        lastAddedAt: DateTime(2026, 8, 3),
        previewUrls: urls,
      ),
      textScaler: const TextScaler.linear(2),
      themeMode: ThemeMode.dark,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('long press starts selection and selected taps toggle it', (
    tester,
  ) async {
    var selectionStarts = 0;
    var selectionToggles = 0;
    final summary = CollectionSummary(
      collection: _collection(id: 1, urlIds: const []),
      linkCount: 0,
    );

    await _pumpCard(tester, summary, onSelectionStart: () => selectionStarts++);
    await tester.longPress(find.text('Weekend ideas'));
    expect(selectionStarts, 1);

    await _pumpCard(
      tester,
      summary,
      selectionMode: true,
      isSelected: true,
      onSelectionToggle: () => selectionToggles++,
    );
    expect(find.byKey(const ValueKey('selection-selected')), findsOneWidget);
    await tester.tap(find.text('Weekend ideas'));
    expect(selectionToggles, 1);
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  CollectionSummary summary, {
  TextScaler textScaler = TextScaler.noScaling,
  ThemeMode themeMode = ThemeMode.light,
  bool selectionMode = false,
  bool isSelected = false,
  VoidCallback? onSelectionStart,
  VoidCallback? onSelectionToggle,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: themeMode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: CollectionListCard(
          summary: summary,
          selectionMode: selectionMode,
          isSelected: isSelected,
          onSelectionStart: onSelectionStart,
          onSelectionToggle: onSelectionToggle,
        ),
      ),
    ),
  );
}

UserCollection _collection({
  required int id,
  String name = 'Weekend ideas',
  String? description,
  required List<int> urlIds,
}) {
  return UserCollection()
    ..id = id
    ..name = name
    ..emoji = 'travel'
    ..description = description
    ..createdAt = DateTime(2026, 8, 1)
    ..urlIds = urlIds;
}

SavedUrl _savedUrl(int id) {
  return SavedUrl()
    ..id = id
    ..rawUrl = ''
    ..domain = ''
    ..title = 'Save $id'
    ..description = ''
    ..thumbnailUrl = null
    ..category = 'Other'
    ..categoryEmoji = '•'
    ..categories = const ['Other']
    ..tags = const ['Alpha']
    ..savedAt = DateTime(2026, 8, id);
}
