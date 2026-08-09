import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/features/library/library_entity.dart';
import 'package:glimpse/features/library/library_provider.dart';

void main() {
  group('LibraryIndex', () {
    test('uses a catalog identity and groups multiple-source provenance', () {
      final provisional = _saved(
        id: 1,
        mention: {
          'title': 'Dune',
          'type': 'book',
          'creator': 'Frank Herbert',
          'why_mentioned': 'A foundational science-fiction recommendation.',
        },
      );
      final resolved = _saved(
        id: 2,
        mention: {
          'title': 'Dune',
          'type': 'book',
          'creator': 'Frank Herbert',
          'catalog_id': 'OL893415W',
          'catalog_source': 'open_library',
          'genres': ['Science Fiction'],
          'user_library_status': 'active',
        },
      );

      final snapshot = LibraryIndex.build([provisional, resolved]);

      expect(snapshot.entities, hasLength(1));
      expect(snapshot.entities.single.key, contains('open_library'));
      expect(snapshot.entities.single.sources.map((source) => source.urlId), {
        1,
        2,
      });
      expect(snapshot.entities.single.genres, ['Science Fiction']);
      expect(snapshot.entities.single.status, LibraryItemStatus.active);
    });

    test('does not merge ambiguous titles with different disambiguators', () {
      final first = _saved(
        id: 1,
        mention: {
          'title': 'Home',
          'type': 'movie',
          'year': '2015',
          'subtype': 'movie',
        },
      );
      final second = _saved(
        id: 2,
        mention: {
          'title': 'Home',
          'type': 'movie',
          'year': '2020',
          'subtype': 'show',
        },
      );

      expect(LibraryIndex.build([first, second]).entities, hasLength(2));
    });

    test('removing sources only removes the entity after final provenance', () {
      final first = _saved(
        id: 1,
        mention: {
          'title': 'Piranesi',
          'type': 'book',
          'creator': 'Susanna Clarke',
        },
      );
      final second = _saved(
        id: 2,
        mention: {
          'title': 'Piranesi',
          'type': 'book',
          'creator': 'Susanna Clarke',
        },
      );

      expect(
        LibraryIndex.build([first, second]).entities.single.sources,
        hasLength(2),
      );
      expect(
        LibraryIndex.build([second]).entities.single.sources,
        hasLength(1),
      );
      expect(LibraryIndex.build(const []).entities, isEmpty);
    });

    test('hidden canonical or provisional keys stay out of the Library', () {
      final save = _saved(
        id: 1,
        mention: {
          'title': 'Arrival',
          'type': 'movie',
          'year': '2016',
          'subtype': 'movie',
        },
      );
      final entity = LibraryIndex.build([save]).entities.single;

      expect(
        LibraryIndex.build([save], hiddenKeys: {entity.key}).entities,
        isEmpty,
      );
    });

    test('derives useful genres from existing local save metadata', () {
      final book = _saved(
        id: 1,
        sourceTitle: 'Quant reading list',
        tags: const ['machine learning', 'finance', 'algorithmic trading'],
        mention: {
          'title': 'Machine Learning for Algorithmic Trading',
          'type': 'book',
          'creator': 'Stefan Jansen',
        },
      );
      final movie = _saved(
        id: 2,
        sourceTitle: 'Indonesian horror films worth watching',
        categories: const ['Movies', 'Horror'],
        mention: {
          'title': 'Satan’s Slaves',
          'type': 'movie',
          'year': '2017',
          'subtype': 'movie',
        },
      );

      final snapshot = LibraryIndex.build([book, movie]);
      final indexedBook = snapshot.ofKind(LibraryEntityKind.book).single;
      final indexedMovie = snapshot.ofKind(LibraryEntityKind.movie).single;

      expect(
        indexedBook.genres,
        containsAll(['Finance & Investing', 'Technology']),
      );
      expect(indexedMovie.genres, contains('Horror'));
      expect(indexedBook.mention.rawGenres, isEmpty);
    });

    test('sends bounded place provenance as resolver-only context hints', () {
      final place = _saved(
        id: 1,
        sourceTitle: 'Delhi Police · Protest Site Decoration',
        mention: {
          'title': 'Jantar Mantar',
          'type': 'place',
          'why_mentioned':
              'A prominent protest site in Delhi mentioned in the post.',
        },
      );

      final request = LibraryIndex.build([
        place,
      ]).entities.single.toResolverJson();

      expect(request['city'], isNull);
      expect(request['country'], isNull);
      expect(
        request['context_hints'],
        containsAll([
          'Delhi Police · Protest Site Decoration',
          'A prominent protest site in Delhi mentioned in the post.',
        ]),
      );
    });
  });

  test('normalizes provider genres into a deterministic taxonomy', () {
    expect(
      LibraryGenreNormalizer.normalize(LibraryEntityKind.book, [
        'Science Fiction & Fantasy',
        'Computer programming',
      ]),
      ['Fantasy', 'Science Fiction', 'Technology'],
    );
    expect(
      LibraryGenreNormalizer.normalize(LibraryEntityKind.movie, ['Unknown']),
      ['Other'],
    );
  });

  test('uses kind-specific reading and watch labels', () {
    expect(
      LibraryItemStatus.active.labelFor(LibraryEntityKind.book),
      'Reading',
    );
    expect(
      LibraryItemStatus.completed.labelFor(LibraryEntityKind.book),
      'Read',
    );
    expect(
      LibraryItemStatus.active.labelFor(LibraryEntityKind.movie),
      'Watching',
    );
    expect(
      LibraryItemStatus.completed.labelFor(LibraryEntityKind.movie),
      'Watched',
    );
  });

  test('only offers manual backfill retry for transient failures', () {
    expect(
      const LibraryBackfillState(
        failed: 2,
        issue: LibraryBackfillIssue.connection,
      ).canRetry,
      isTrue,
    );
    expect(
      const LibraryBackfillState(
        failed: 2,
        issue: LibraryBackfillIssue.partial,
      ).canRetry,
      isTrue,
    );
    expect(
      const LibraryBackfillState(
        failed: 2,
        issue: LibraryBackfillIssue.serviceUnavailable,
      ).canRetry,
      isFalse,
    );
  });
}

SavedUrl _saved({
  required int id,
  required Map<String, dynamic> mention,
  String? sourceTitle,
  List<String> tags = const [],
  List<String> categories = const ['Other'],
}) {
  return SavedUrl()
    ..id = id
    ..rawUrl = 'https://example.com/$id'
    ..domain = 'example.com'
    ..title = sourceTitle ?? 'Source $id'
    ..description = ''
    ..category = 'Other'
    ..categoryEmoji = ''
    ..categories = categories
    ..tags = tags
    ..savedAt = DateTime(2026, 8, id)
    ..enrichmentJson = jsonEncode({
      'schema_version': 3,
      'meaningful_title': 'Source $id',
      'summary': 'Summary',
      'category': 'Other',
      'tags': <String>[],
      'mentions': [mention],
    });
}
