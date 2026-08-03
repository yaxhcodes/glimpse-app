import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/user_collection.dart';
import 'package:glimpse/core/providers/service_providers.dart';
import 'package:glimpse/features/collections/collection_detail_screen.dart';
import 'package:glimpse/features/collections/collections_provider.dart';

void main() {
  testWidgets('collection description appears beneath its detail title', (
    tester,
  ) async {
    final collection = UserCollection()
      ..id = 7
      ..name = 'Design references'
      ..emoji = 'palette'
      ..description = '  Interfaces worth revisiting  '
      ..createdAt = DateTime(2026, 8, 3)
      ..urlIds = const [];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionMetaProvider(
            collection.id,
          ).overrideWith((ref) async => collection),
          collectionUrlsProvider(
            collection.id,
          ).overrideWith((ref) async => const <SavedUrl>[]),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: CollectionDetailScreen(collectionId: collection.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Design references'), findsOneWidget);
    expect(find.text('Interfaces worth revisiting'), findsOneWidget);
    expect(find.text('No links in this collection yet.'), findsOneWidget);
  });

  testWidgets('selected saves can move to another collection', (tester) async {
    final source = _collection(1, 'Source', [101, 102]);
    final target = _collection(2, 'Target', [201]);
    final urls = [_savedUrl(101), _savedUrl(102)];
    final isar = _FakeIsarService()..movedCount = 2;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionMetaProvider(source.id).overrideWith((ref) async => source),
          collectionUrlsProvider(source.id).overrideWith((ref) async => urls),
          collectionsSummaryProvider.overrideWith(
            (ref) async => [
              CollectionSummary(collection: source, linkCount: 2),
              CollectionSummary(collection: target, linkCount: 1),
            ],
          ),
          isarServiceProvider.overrideWithValue(isar),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: CollectionDetailScreen(collectionId: source.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Save 101'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save 102'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More selection actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to collection'));
    await tester.pumpAndSettle();

    expect(
      find.text('Move 2 selected links from “Source” to another collection.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ListTile, 'Source'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, 'Target'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Move'));
    await tester.pumpAndSettle();

    expect(isar.sourceCollectionId, source.id);
    expect(isar.targetCollectionId, target.id);
    expect(isar.movedUrlIds, {101, 102});
    expect(find.text('Moved 2 links to Target'), findsOneWidget);
    expect(find.byTooltip('Exit selection'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });
}

UserCollection _collection(int id, String name, List<int> urlIds) {
  return UserCollection()
    ..id = id
    ..name = name
    ..emoji = 'books'
    ..createdAt = DateTime(2026, 8, id)
    ..urlIds = urlIds;
}

SavedUrl _savedUrl(int id) {
  return SavedUrl()
    ..id = id
    ..rawUrl = 'https://example.com/$id'
    ..domain = 'example.com'
    ..title = 'Save $id'
    ..description = ''
    ..category = 'Other'
    ..categoryEmoji = '•'
    ..categories = const ['Other']
    ..tags = const []
    ..savedAt = DateTime(2026, 8, 3);
}

class _FakeIsarService implements IsarService {
  int? sourceCollectionId;
  int? targetCollectionId;
  final Set<int> movedUrlIds = {};
  int movedCount = 0;

  @override
  Future<int> moveUrlsBetweenCollections({
    required int sourceCollectionId,
    required int targetCollectionId,
    required Iterable<int> urlIds,
  }) async {
    this.sourceCollectionId = sourceCollectionId;
    this.targetCollectionId = targetCollectionId;
    movedUrlIds.addAll(urlIds);
    return movedCount;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected Isar call: ${invocation.memberName}');
  }
}
