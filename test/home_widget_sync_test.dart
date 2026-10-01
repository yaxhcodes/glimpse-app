import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/home_widget_sync.dart';
import 'package:glimpse/core/models/url_processing_status.dart';

final _now = DateTime(2026, 10, 1, 12);

SavedUrl save(int id, {int daysAgo = 30}) => SavedUrl()
  ..id = id
  ..rawUrl = 'https://www.instagram.com/reel/$id/'
  ..domain = 'instagram.com'
  ..title = 'Save $id'
  ..description = ''
  ..summary = 'A summary'
  ..category = 'Food'
  ..categoryEmoji = ''
  ..categories = ['Food']
  ..tags = []
  ..processingStatus = UrlProcessingStatus.completed
  ..savedAt = _now.subtract(Duration(days: daysAgo));

List<int> ids(List<SavedUrl> saves) => saves.map((u) => u.id).toList();

void main() {
  group('selectWidgetSaves', () {
    test('keeps Rediscover ranking first, then tops up oldest unopened', () {
      final opened = save(4, daysAgo: 90)..openedAt = _now;
      final library = [
        save(1),
        save(2, daysAgo: 60),
        save(3, daysAgo: 10),
        opened,
      ];
      final picked = HomeWidgetSync.selectWidgetSaves(
        ranked: [library[2]],
        library: library,
        now: _now,
      );
      // Ranked 3, unopened oldest-first 2 then 1, opened 4 last.
      expect(ids(picked), [3, 2, 1, 4]);
    });

    test('never shows a fresh, done, dismissed, binned or unready save', () {
      final library = [
        save(1, daysAgo: 0),
        save(2)..intentStatus = 'done',
        save(3)..rediscoverDismissedAt = _now,
        save(4)..deletedAt = _now,
        save(5)
          ..summary = ''
          ..processingStatus = UrlProcessingStatus.failed,
        save(6),
      ];
      final picked = HomeWidgetSync.selectWidgetSaves(
        ranked: library,
        library: library,
        now: _now,
      );
      expect(ids(picked), [6]);
    });

    test('caps the list and never repeats a save', () {
      final library = [for (var i = 1; i <= 20; i++) save(i, daysAgo: i + 1)];
      final picked = HomeWidgetSync.selectWidgetSaves(
        ranked: [library[0], library[0], library[5]],
        library: library,
        now: _now,
      );
      expect(picked, hasLength(HomeWidgetSync.maxSaves));
      expect(ids(picked).toSet(), hasLength(HomeWidgetSync.maxSaves));
      expect(ids(picked).take(2), [1, 6]);
    });
  });

  test('a widget entry carries the display title and source, not tags', () {
    final entry = HomeWidgetSync.widgetEntryFor(
      save(7)
        ..title = 'instagram.com'
        ..enrichmentJson = '{"meaningful_title": "Best ramen in Osaka"}',
      picturePath: '/data/pic',
    );
    expect(entry['id'], 7);
    expect(entry['title'], 'Best ramen in Osaka');
    expect(entry['source'], 'Instagram');
    expect(
      entry['savedAt'],
      _now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
    );
    expect(entry['image'], '/data/pic');
  });
}
