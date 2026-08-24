import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/user_collection.dart';
import 'package:glimpse/core/providers/service_providers.dart';
import 'package:glimpse/features/collections/collection_visual.dart';
import 'package:glimpse/features/collections/create_collection_sheet.dart';

void main() {
  testWidgets('collection icons are borderless outside selected states', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            CollectionVisual(
              key: ValueKey('standard-visual'),
              style: CollectionVisualStyle.food,
            ),
            CollectionVisual(
              key: ValueKey('selected-visual'),
              style: CollectionVisualStyle.food,
              selected: true,
            ),
          ],
        ),
      ),
    );

    BoxDecoration decorationFor(String key) {
      final container = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return container.decoration! as BoxDecoration;
    }

    expect(decorationFor('standard-visual').border, isNull);
    expect(decorationFor('selected-visual').border, isNotNull);
  });

  testWidgets('edit preserves membership and updates collection metadata', (
    tester,
  ) async {
    final original = _collection(1, 'Old name', description: 'Old note')
      ..urlIds = const [4, 7];
    final isar = _FakeIsarService([original]);
    await _pumpEditSheet(tester, original, isar);

    await tester.enterText(find.byType(TextField).at(0), 'Travel plans');
    await tester.enterText(find.byType(TextField).at(1), '  ');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final updated = isar.updated!;
    expect(updated.id, original.id);
    expect(updated.name, 'Travel plans');
    expect(updated.description, isNull);
    expect(updated.createdAt, original.createdAt);
    expect(updated.urlIds, [4, 7]);
    expect(
      updated.emoji,
      resolveCollectionVisualStyle(
        null,
        name: 'Travel plans',
        description: '',
      ).key,
    );
  });

  testWidgets('edit duplicate validation excludes the current collection', (
    tester,
  ) async {
    final original = _collection(1, 'Weekend ideas');
    final another = _collection(2, 'Recipes');
    final isar = _FakeIsarService([original, another]);
    await _pumpEditSheet(tester, original, isar);

    await tester.enterText(find.byType(TextField).at(0), 'Weekend ideas');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(isar.updated?.name, 'Weekend ideas');
  });

  testWidgets('edit duplicate validation rejects another collection', (
    tester,
  ) async {
    final original = _collection(1, 'Weekend ideas');
    final another = _collection(2, 'Recipes');
    final isar = _FakeIsarService([original, another]);
    await _pumpEditSheet(tester, original, isar);
    await tester.enterText(find.byType(TextField).at(0), 'recipes');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('A collection with this name already exists'),
      findsOneWidget,
    );
    expect(isar.updated, isNull);
  });

  testWidgets('collection description is limited to the shared maximum', (
    tester,
  ) async {
    final original = _collection(1, 'Reading list');
    final isar = _FakeIsarService([original]);
    await _pumpEditSheet(tester, original, isar);

    final overlong = List.filled(
      maxCollectionDescriptionLength + 20,
      'a',
    ).join();
    final descriptionField = find.byType(TextField).at(1);
    await tester.enterText(descriptionField, overlong);
    await tester.pump();

    final field = tester.widget<TextField>(descriptionField);
    expect(field.controller!.text.length, maxCollectionDescriptionLength);
    expect(
      find.text(
        '$maxCollectionDescriptionLength/$maxCollectionDescriptionLength',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(isar.updated!.description!.length, maxCollectionDescriptionLength);
  });
}

Future<void> _pumpEditSheet(
  WidgetTester tester,
  UserCollection collection,
  IsarService isar,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [isarServiceProvider.overrideWithValue(isar)],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: CreateCollectionSheet(collection: collection)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

UserCollection _collection(int id, String name, {String? description}) {
  return UserCollection()
    ..id = id
    ..name = name
    ..emoji = 'books'
    ..description = description
    ..createdAt = DateTime(2026, 8, id)
    ..urlIds = const [];
}

class _FakeIsarService implements IsarService {
  _FakeIsarService(this.collections);

  final List<UserCollection> collections;
  UserCollection? updated;

  @override
  Future<List<UserCollection>> getAllCollections() async => collections;

  @override
  Future<void> updateCollection(UserCollection collection) async {
    updated = collection;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected Isar call: ${invocation.memberName}');
  }
}
