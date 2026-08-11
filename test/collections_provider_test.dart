import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/user_collection.dart';
import 'package:glimpse/features/collections/collections_provider.dart';

void main() {
  test('loads collection summaries with bounded batch calls', () async {
    final first = _collection(id: 1, name: 'Research', urlIds: [1, 2, 999]);
    final second = _collection(id: 2, name: 'Shared', urlIds: [2]);
    final urls = {
      1: _saved(id: 1, savedAt: DateTime(2026, 8, 9), tags: const ['design']),
      2: _saved(id: 2, savedAt: DateTime(2026, 8, 10), tags: const ['flutter']),
    };
    var collectionLoads = 0;
    var urlBatchLoads = 0;
    var addedAtBatchLoads = 0;
    Set<int>? requestedIds;

    final summaries = await loadCollectionSummaries(
      loadCollections: () async {
        collectionLoads++;
        return [first, second];
      },
      loadUrlsByIds: (ids) async {
        urlBatchLoads++;
        requestedIds = ids;
        return urls;
      },
      loadLatestAddedAts: (collections) async {
        addedAtBatchLoads++;
        expect(collections.map((collection) => collection.id), [1, 2]);
        return {1: DateTime(2026, 8, 11), 2: DateTime(2026, 8, 10)};
      },
    );

    expect(collectionLoads, 1);
    expect(urlBatchLoads, 1);
    expect(addedAtBatchLoads, 1);
    expect(requestedIds, {1, 2, 999});
    expect(summaries, hasLength(2));
    expect(summaries.first.linkCount, 3);
    expect(summaries.first.previewUrls.map((url) => url.id), [2, 1]);
    expect(summaries.first.lastSavedAt, DateTime(2026, 8, 10));
    expect(summaries.first.lastAddedAt, DateTime(2026, 8, 11));
    expect(summaries.first.visualHint, contains('flutter'));
    expect(summaries.last.previewUrls.single.id, 2);
  });

  test('summary previews stay capped and sorted newest first', () {
    final collection = _collection(
      id: 1,
      name: 'Reading',
      urlIds: [1, 2, 3, 4],
    );
    final urls = {
      for (var id = 1; id <= 4; id++)
        id: _saved(id: id, savedAt: DateTime(2026, 8, id)),
    };

    final summary = buildCollectionSummaries(
      collections: [collection],
      urlsById: urls,
    ).single;

    expect(summary.previewUrls.map((url) => url.id), [4, 3, 2]);
    expect(summary.lastSavedAt, DateTime(2026, 8, 4));
  });

  test(
    'large collection fixtures retain constant storage query counts',
    () async {
      final urls = {
        for (var id = 1; id <= 1000; id++)
          id: _saved(
            id: id,
            savedAt: DateTime(2026, 1, 1).add(Duration(days: id)),
          ),
      };
      final collections = [
        for (var collectionId = 1; collectionId <= 100; collectionId++)
          _collection(
            id: collectionId,
            name: 'Collection $collectionId',
            urlIds: [
              for (var offset = 0; offset < 50; offset++)
                ((collectionId * 7 + offset) % 1000) + 1,
            ],
          ),
      ];
      var collectionLoads = 0;
      var urlBatchLoads = 0;
      var addedAtBatchLoads = 0;

      final summaries = await loadCollectionSummaries(
        loadCollections: () async {
          collectionLoads++;
          return collections;
        },
        loadUrlsByIds: (ids) async {
          urlBatchLoads++;
          return {for (final id in ids) id: urls[id]!};
        },
        loadLatestAddedAts: (loadedCollections) async {
          addedAtBatchLoads++;
          return {
            for (final collection in loadedCollections) collection.id: null,
          };
        },
      );

      expect(summaries, hasLength(100));
      expect(
        summaries.every((summary) => summary.previewUrls.length == 3),
        isTrue,
      );
      expect(collectionLoads, 1);
      expect(urlBatchLoads, 1);
      expect(addedAtBatchLoads, 1);
    },
  );
}

UserCollection _collection({
  required int id,
  required String name,
  required List<int> urlIds,
}) {
  return UserCollection()
    ..id = id
    ..name = name
    ..emoji = 'folder'
    ..createdAt = DateTime(2026, 8, id)
    ..urlIds = urlIds;
}

SavedUrl _saved({
  required int id,
  required DateTime savedAt,
  List<String> tags = const [],
}) {
  return SavedUrl()
    ..id = id
    ..rawUrl = 'https://example.com/$id'
    ..domain = 'example.com'
    ..title = 'Saved $id'
    ..description = ''
    ..category = 'Technology'
    ..categoryEmoji = ''
    ..categories = const ['Technology']
    ..tags = tags
    ..savedAt = savedAt;
}
