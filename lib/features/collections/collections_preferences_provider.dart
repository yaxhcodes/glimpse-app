import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'collections_provider.dart';

enum CollectionsLayout { grid, list }

enum CollectionsSort { manual, newest, name }

const collectionsLayoutPrefsKey = 'glimpse_collections_layout';
const collectionsSortPrefsKey = 'glimpse_collections_sort';
const collectionsManualOrderPrefsKey = 'glimpse_collections_manual_order';

class CollectionsPreferencesState {
  const CollectionsPreferencesState({
    this.layout = CollectionsLayout.grid,
    this.sort = CollectionsSort.newest,
    this.manualOrder = const [],
    this.isLoaded = false,
  });

  final CollectionsLayout layout;
  final CollectionsSort sort;
  final List<int> manualOrder;
  final bool isLoaded;

  CollectionsPreferencesState copyWith({
    CollectionsLayout? layout,
    CollectionsSort? sort,
    List<int>? manualOrder,
    bool? isLoaded,
  }) {
    return CollectionsPreferencesState(
      layout: layout ?? this.layout,
      sort: sort ?? this.sort,
      manualOrder: manualOrder ?? this.manualOrder,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  List<CollectionSummary> sortSummaries(Iterable<CollectionSummary> summaries) {
    final values = summaries.toList(growable: false);
    switch (sort) {
      case CollectionsSort.newest:
        return values.toList()..sort((a, b) {
          final byDate = b.collection.createdAt.compareTo(
            a.collection.createdAt,
          );
          if (byDate != 0) return byDate;
          return b.collection.id.compareTo(a.collection.id);
        });
      case CollectionsSort.name:
        return values.toList()..sort((a, b) {
          final byName = a.collection.name.trim().toLowerCase().compareTo(
            b.collection.name.trim().toLowerCase(),
          );
          if (byName != 0) return byName;
          return a.collection.id.compareTo(b.collection.id);
        });
      case CollectionsSort.manual:
        final byId = {
          for (final summary in values) summary.collection.id: summary,
        };
        final known = manualOrder
            .map((id) => byId.remove(id))
            .whereType<CollectionSummary>()
            .toList(growable: false);
        return [...byId.values, ...known];
    }
  }
}

class CollectionsPreferencesNotifier
    extends StateNotifier<CollectionsPreferencesState> {
  CollectionsPreferencesNotifier()
    : super(const CollectionsPreferencesState()) {
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedLayout = prefs.getString(collectionsLayoutPrefsKey);
    final storedSort = prefs.getString(collectionsSortPrefsKey);
    final storedOrder = prefs.getStringList(collectionsManualOrderPrefsKey);
    state = CollectionsPreferencesState(
      layout: CollectionsLayout.values.firstWhere(
        (value) => value.name == storedLayout,
        orElse: () => CollectionsLayout.grid,
      ),
      sort: CollectionsSort.values.firstWhere(
        (value) => value.name == storedSort,
        orElse: () => CollectionsSort.newest,
      ),
      manualOrder:
          storedOrder
              ?.map(int.tryParse)
              .whereType<int>()
              .toList(growable: false) ??
          const [],
      isLoaded: true,
    );
  }

  Future<void> setLayout(CollectionsLayout layout) async {
    if (layout == state.layout) return;
    state = state.copyWith(layout: layout);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(collectionsLayoutPrefsKey, layout.name);
  }

  Future<void> setSort(CollectionsSort sort) async {
    if (sort == state.sort) return;
    state = state.copyWith(sort: sort);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(collectionsSortPrefsKey, sort.name);
  }

  Future<void> setManualOrder(Iterable<int> ids) async {
    final order = ids.toList(growable: false);
    state = state.copyWith(sort: CollectionsSort.manual, manualOrder: order);
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(collectionsSortPrefsKey, CollectionsSort.manual.name),
      prefs.setStringList(
        collectionsManualOrderPrefsKey,
        order.map((id) => '$id').toList(growable: false),
      ),
    ]);
  }

  Future<void> reconcile(Iterable<int> currentIds) async {
    if (!state.isLoaded) return;
    final current = currentIds.toList(growable: false);
    final currentSet = current.toSet();
    final known = state.manualOrder
        .where(currentSet.contains)
        .toList(growable: false);
    final knownSet = known.toSet();
    final newIds = current.where((id) => !knownSet.contains(id));
    final updated = [...newIds, ...known];
    if (_sameOrder(updated, state.manualOrder)) return;
    state = state.copyWith(manualOrder: updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      collectionsManualOrderPrefsKey,
      updated.map((id) => '$id').toList(growable: false),
    );
  }

  Future<void> removeCollections(Iterable<int> ids) async {
    final removed = ids.toSet();
    if (removed.isEmpty) return;
    final updated = state.manualOrder
        .where((id) => !removed.contains(id))
        .toList(growable: false);
    if (_sameOrder(updated, state.manualOrder)) return;
    state = state.copyWith(manualOrder: updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      collectionsManualOrderPrefsKey,
      updated.map((id) => '$id').toList(growable: false),
    );
  }

  bool _sameOrder(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}

final collectionsPreferencesProvider =
    StateNotifierProvider<
      CollectionsPreferencesNotifier,
      CollectionsPreferencesState
    >((ref) => CollectionsPreferencesNotifier());
