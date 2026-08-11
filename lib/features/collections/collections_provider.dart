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
    this.previewUrls = const [],
  });

  final UserCollection collection;
  final int linkCount;
  final DateTime? lastSavedAt;
  final DateTime? lastAddedAt;
  final String? visualHint;
  final List<SavedUrl> previewUrls;
}

final collectionsListProvider = FutureProvider<List<UserCollection>>((
  ref,
) async {
  final isar = ref.watch(isarServiceProvider);
  return isar.getAllCollections();
});

final collectionsSummaryProvider = FutureProvider<List<CollectionSummary>>((
  ref,
) async {
  final isar = ref.watch(isarServiceProvider);
  return loadCollectionSummaries(
    loadCollections: isar.getAllCollections,
    loadUrlsByIds: isar.getUrlsByIds,
    loadLatestAddedAts: isar.getLatestCollectionAddedAts,
  );
});

Future<List<CollectionSummary>> loadCollectionSummaries({
  required Future<List<UserCollection>> Function() loadCollections,
  required Future<Map<int, SavedUrl>> Function(Set<int>) loadUrlsByIds,
  required Future<Map<int, DateTime?>> Function(
    Iterable<UserCollection> collections,
  )
  loadLatestAddedAts,
}) async {
  final collections = await loadCollections();
  final urlIds = collections.expand((collection) => collection.urlIds).toSet();
  final urlsFuture = loadUrlsByIds(urlIds);
  final addedAtFuture = loadLatestAddedAts(collections);
  return buildCollectionSummaries(
    collections: collections,
    urlsById: await urlsFuture,
    latestAddedAtByCollection: await addedAtFuture,
  );
}

List<CollectionSummary> buildCollectionSummaries({
  required Iterable<UserCollection> collections,
  required Map<int, SavedUrl> urlsById,
  Map<int, DateTime?> latestAddedAtByCollection = const {},
}) {
  final summaries = <CollectionSummary>[];
  for (final collection in collections) {
    final urls =
        collection.urlIds
            .map((id) => urlsById[id])
            .whereType<SavedUrl>()
            .toList(growable: false)
          ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final visualHint = urls.isEmpty
        ? null
        : urls
              .take(8)
              .expand((url) {
                return [
                  url.category,
                  url.domain,
                  ...url.categories,
                  ...url.tags.take(4),
                ];
              })
              .join(' ');
    summaries.add(
      CollectionSummary(
        collection: collection,
        linkCount: collection.urlIds.length,
        lastSavedAt: urls.firstOrNull?.savedAt,
        lastAddedAt: latestAddedAtByCollection[collection.id],
        visualHint: visualHint,
        previewUrls: List.unmodifiable(urls.take(3)),
      ),
    );
  }
  return List.unmodifiable(summaries);
}

final collectionMetaProvider = FutureProvider.family<UserCollection?, int>((
  ref,
  id,
) async {
  final isar = ref.watch(isarServiceProvider);
  return isar.getCollectionById(id);
});

final collectionUrlsProvider = FutureProvider.family<List<SavedUrl>, int>((
  ref,
  id,
) async {
  final isar = ref.watch(isarServiceProvider);
  ref.watch(collectionMetaProvider(id));
  return isar.getUrlsInCollection(id);
});
