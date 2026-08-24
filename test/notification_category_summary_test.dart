import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/notification_category_summary.dart';

SavedUrl _savedUrl({
  String category = 'Other',
  List<String> categories = const [],
}) {
  return SavedUrl()
    ..rawUrl = 'https://example.com/item'
    ..domain = 'example.com'
    ..title = 'Item'
    ..description = ''
    ..category = category
    ..categoryEmoji = ''
    ..categories = categories
    ..tags = const []
    ..savedAt = DateTime(2026);
}

void main() {
  group('notification category summary', () {
    test('omits generic Other labels when no real category is available', () {
      final ranked = NotificationCategorySummary.ranked([
        _savedUrl(categories: const ['Other', 'other']),
      ]);

      expect(ranked, isEmpty);
    });

    test('keeps a meaningful category and removes Other', () {
      final ranked = NotificationCategorySummary.ranked([
        _savedUrl(categories: const ['Other', 'other', 'health']),
      ]);

      expect(ranked.map((category) => category.label), ['Health']);
      expect(ranked.single.count, 1);
    });

    test('counts a case variant only once per save', () {
      final ranked = NotificationCategorySummary.ranked([
        _savedUrl(categories: const ['health', 'Health', 'Other']),
        _savedUrl(category: 'Philosophy', categories: const ['Health']),
      ]);

      expect(ranked.map((category) => category.label), [
        'Health',
        'Philosophy',
      ]);
      expect(ranked.first.count, 2);
    });

    test('continues to exclude source platforms', () {
      final ranked = NotificationCategorySummary.ranked([
        _savedUrl(categories: const ['Instagram', 'Health']),
      ]);

      expect(ranked.map((category) => category.label), ['Health']);
    });
  });
}
