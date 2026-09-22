import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/features/home/home_provider.dart';
import 'package:glimpse/features/library/library_entity.dart';
import 'package:glimpse/features/library/library_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'initial index loads asynchronously and tracks later saved changes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final urls = StreamController<List<SavedUrl>>();
      final container = ProviderContainer(
        overrides: [urlStreamProvider.overrideWith((ref) => urls.stream)],
      );
      addTearDown(container.dispose);
      addTearDown(urls.close);
      var ready = Completer<LibrarySnapshot>();
      final subscription = container.listen(libraryCandidatesProvider, (
        _,
        next,
      ) {
        if (!ready.isCompleted) {
          if (next.hasError) {
            ready.completeError(next.error!, next.stackTrace!);
          } else if (!next.isLoading && next.hasValue) {
            ready.complete(next.requireValue);
          }
        }
      }, fireImmediately: true);
      addTearDown(subscription.close);
      expect(container.read(libraryCandidatesProvider).isLoading, isTrue);
      final saved = SavedUrl()
        ..id = 1
        ..rawUrl = 'https://example.com/book'
        ..domain = 'example.com'
        ..title = 'A book'
        ..description = ''
        ..category = 'Books'
        ..categoryEmoji = ''
        ..categories = ['Books']
        ..tags = []
        ..savedAt = DateTime(2026)
        ..enrichmentJson = jsonEncode({
          'mentions': [
            {'type': 'book', 'title': 'Dune', 'author': 'Frank Herbert'},
          ],
        });
      urls.add([saved]);
      final first = await ready.future;
      expect(
        first.entities.map((e) => e.key),
        LibraryIndex.build([saved]).entities.map((e) => e.key),
      );
      expect(first.entities, isNotEmpty);
      ready = Completer<LibrarySnapshot>();
      urls.add([]);
      expect((await ready.future).entities, isEmpty);
    },
  );
}
