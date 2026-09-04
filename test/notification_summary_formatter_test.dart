import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/notification_summary_formatter.dart';
import 'package:glimpse/core/services/url_save_notifications.dart';

void main() {
  test('uses a complete first sentence without arbitrary word chopping', () {
    expect(
      NotificationSummaryFormatter.format(
        'A focused guide to building a calm personal knowledge library. More follows.',
      ),
      'A focused guide to building a calm personal knowledge library.',
    );
  });

  test('long sentence is bounded and ends cleanly', () {
    final result = NotificationSummaryFormatter.format(
      List.filled(40, 'useful').join(' '),
      maxLength: 80,
    );
    expect(result.length, lessThanOrEqualTo(80));
    expect(result, endsWith('.'));
    expect(result, isNot(contains('…')));
  });

  test('save-ready copy prefers the stored notification blurb', () {
    final url = SavedUrl()
      ..summary = 'A generic fallback summary.'
      ..description = 'A generic fallback description.'
      ..enrichmentJson = jsonEncode({
        'schema_version': 5,
        'meaningful_title': 'Knowledge library',
        'summary': 'A longer reader summary.',
        'category': 'Productivity',
        'tags': ['knowledge'],
        'notification_blurb':
            'A practical guide to building a calm knowledge library from everything you save.',
      });

    expect(
      UrlSaveNotifications.notificationBody(url),
      'A practical guide to building a calm knowledge library from everything you save.',
    );
  });
}
