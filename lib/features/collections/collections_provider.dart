import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/saved_url.dart';
import '../../core/models/user_collection.dart';
import '../../core/providers/service_providers.dart';

class CollectionSummary {
  const CollectionSummary({
    required this.collection,
    required this.linkCount,
    this.lastSavedAt,
    this.lastAddedAt,
    this.visualHint,
  });

  final UserCollection collection;
  final int linkCount;
  final DateTime? lastSavedAt;
  final DateTime? lastAddedAt;
  final String? visualHint;
}

final collectionsListProvider =
    FutureProvider<List<UserCollection>>((ref) async {
  final isar = ref.watch(isarServiceProvider);
  return isar.getAllCollections();
});

final collectionsSummaryProvider =
    FutureProvider<List<CollectionSummary>>((ref) async {
  final isar = ref.watch(isarServiceProvider);
  final collections = await isar.getAllCollections();
  final summaries = <CollectionSummary>[];

  for (final collection in collections) {
    DateTime? lastSavedAt;
    DateTime? lastAddedAt;
    String? visualHint;
    if (collection.urlIds.isNotEmpty) {
      final urls = await isar.getUrlsInCollection(collection.id);
      if (urls.isNotEmpty) {
        lastSavedAt = urls.first.savedAt;
        visualHint = urls.take(8).expand((url) {
          return [
            url.category,
            url.domain,
            ...url.categories,
            ...url.tags.take(4),
          ];
        }).join(' ');
      }
      lastAddedAt = await isar.getLatestCollectionAddedAt(collection);
    }
    summaries.add(
      CollectionSummary(
        collection: collection,
        linkCount: collection.urlIds.length,
        lastSavedAt: lastSavedAt,
        lastAddedAt: lastAddedAt,
        visualHint: visualHint,
      ),
    );
  }

  return summaries;
});

final collectionMetaProvider =
    FutureProvider.family<UserCollection?, int>((ref, id) async {
  final isar = ref.watch(isarServiceProvider);
  return isar.getCollectionById(id);
});

final collectionUrlsProvider =
    FutureProvider.family<List<SavedUrl>, int>((ref, id) async {
  final isar = ref.watch(isarServiceProvider);
  ref.watch(collectionMetaProvider(id));
  return isar.getUrlsInCollection(id);
});
