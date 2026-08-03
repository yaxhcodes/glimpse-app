import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/user_collection.dart';
import 'package:glimpse/features/collections/collections_preferences_provider.dart';
import 'package:glimpse/features/collections/collections_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('loads layout, sort, and manual order preferences', () async {
    SharedPreferences.setMockInitialValues({
      collectionsLayoutPrefsKey: 'list',
      collectionsSortPrefsKey: 'manual',
      collectionsManualOrderPrefsKey: ['3', '1'],
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = await _waitUntilLoaded(container);

    expect(state.layout, CollectionsLayout.list);
    expect(state.sort, CollectionsSort.manual);
    expect(state.manualOrder, [3, 1]);
  });

  test(
    'reconcile removes stale ids and places new collections first',
    () async {
      SharedPreferences.setMockInitialValues({
        collectionsManualOrderPrefsKey: ['3', '99', '1'],
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await _waitUntilLoaded(container);

      await container.read(collectionsPreferencesProvider.notifier).reconcile([
        4,
        3,
        2,
        1,
      ]);

      expect(container.read(collectionsPreferencesProvider).manualOrder, [
        4,
        2,
        3,
        1,
      ]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(collectionsManualOrderPrefsKey), [
        '4',
        '2',
        '3',
        '1',
      ]);
    },
  );

  test('sorts collections by newest, name, and manual order', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _waitUntilLoaded(container);
    final notifier = container.read(collectionsPreferencesProvider.notifier);
    final summaries = [
      _summary(1, 'Zebra', DateTime(2026, 1, 1)),
      _summary(2, 'alpha', DateTime(2026, 3, 1)),
      _summary(3, 'Middle', DateTime(2026, 2, 1)),
    ];

    expect(_ids(container, summaries), [2, 3, 1]);

    await notifier.setSort(CollectionsSort.name);
    expect(_ids(container, summaries), [2, 3, 1]);

    await notifier.setManualOrder([1, 3, 2]);
    expect(_ids(container, summaries), [1, 3, 2]);
  });

  test(
    'saving manual order switches sort and removing ids prunes it',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await _waitUntilLoaded(container);
      final notifier = container.read(collectionsPreferencesProvider.notifier);

      await notifier.setManualOrder([3, 2, 1]);
      await notifier.removeCollections([2]);

      final state = container.read(collectionsPreferencesProvider);
      expect(state.sort, CollectionsSort.manual);
      expect(state.manualOrder, [3, 1]);
    },
  );
}

Future<CollectionsPreferencesState> _waitUntilLoaded(
  ProviderContainer container,
) async {
  final current = container.read(collectionsPreferencesProvider);
  if (current.isLoaded) return current;
  return container
      .read(collectionsPreferencesProvider.notifier)
      .stream
      .firstWhere((state) => state.isLoaded);
}

List<int> _ids(ProviderContainer container, List<CollectionSummary> summaries) {
  return container
      .read(collectionsPreferencesProvider)
      .sortSummaries(summaries)
      .map((summary) => summary.collection.id)
      .toList();
}

CollectionSummary _summary(int id, String name, DateTime createdAt) {
  final collection = UserCollection()
    ..id = id
    ..name = name
    ..emoji = 'books'
    ..createdAt = createdAt
    ..urlIds = const [];
  return CollectionSummary(collection: collection, linkCount: 0);
}
