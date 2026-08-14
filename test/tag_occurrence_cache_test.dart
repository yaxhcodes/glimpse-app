import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/features/home/home_provider.dart';

void main() {
  test('reuses counts for processing-only URL updates', () {
    final cache = TagOccurrenceCache();
    final url = SavedUrl()
      ..id = 1
      ..tags = ['flutter', 'performance'];

    final first = cache.build([url]);
    url.processingStatus = 'PROCESSING';
    final second = cache.build([url]);

    expect(identical(first, second), isTrue);
    expect(second, {'flutter': 1, 'performance': 1});
  });

  test('rebuilds counts when tags or membership change', () {
    final cache = TagOccurrenceCache();
    final firstUrl = SavedUrl()
      ..id = 1
      ..tags = ['flutter'];
    final secondUrl = SavedUrl()
      ..id = 2
      ..tags = ['flutter', 'isar'];

    final first = cache.build([firstUrl, secondUrl]);
    secondUrl.tags = ['riverpod'];
    final updated = cache.build([firstUrl, secondUrl]);
    final removed = cache.build([secondUrl]);

    expect(first, {'flutter': 2, 'isar': 1});
    expect(updated, {'flutter': 1, 'riverpod': 1});
    expect(removed, {'riverpod': 1});
    expect(identical(first, updated), isFalse);
  });
}
