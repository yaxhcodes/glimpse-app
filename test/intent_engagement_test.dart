import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/digest_prefs.dart';
import 'package:glimpse/core/services/intent_classifier.dart';
import 'package:glimpse/core/services/notification_action_handler.dart';
import 'package:glimpse/core/services/revisit_scorer.dart';
import 'package:glimpse/core/services/tag_analyzer.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedUrl _url({
  int id = 1,
  String title = 'A save',
  List<String> tags = const [],
  List<String> categories = const ['Other'],
  DateTime? savedAt,
  DateTime? openedAt,
  DateTime? resurfacedAt,
  DateTime? rediscoverDismissedAt,
  String? intentStatus,
  String? intentAction,
  DateTime? revisitAfter,
}) {
  return SavedUrl()
    ..id = id
    ..rawUrl = 'https://example.com/$id'
    ..domain = 'example.com'
    ..title = title
    ..description = ''
    ..category = categories.first
    ..categoryEmoji = ''
    ..categories = categories
    ..tags = tags
    ..savedAt = savedAt ?? DateTime.now().subtract(const Duration(days: 40))
    ..openedAt = openedAt
    ..resurfacedAt = resurfacedAt
    ..rediscoverDismissedAt = rediscoverDismissedAt
    ..intentStatus = intentStatus
    ..intentAction = intentAction
    ..revisitAfter = revisitAfter;
}

void main() {
  group('IntentClassifier', () {
    final now = DateTime(2026, 6, 16, 10); // a Tuesday

    test('done labels map to done kind', () {
      for (final label in ['Already Watched', 'Already Read', 'Already Checked']) {
        final c = IntentClassifier.classify(label, now: now);
        expect(c.kind, IntentKind.done, reason: label);
        expect(c.revisitAfter, isNull);
      }
    });

    test('queue labels map to queue kind with a revisitAfter in the future', () {
      for (final label in ['Watch Later', 'Read Later', 'Try This Weekend']) {
        final c = IntentClassifier.classify(label, now: now);
        expect(c.kind, IntentKind.queue, reason: label);
        expect(c.revisitAfter, isNotNull, reason: label);
        expect(c.revisitAfter!.isAfter(now), isTrue, reason: label);
      }
    });

    test('Try This Weekend lands on a Saturday', () {
      final c = IntentClassifier.classify('Try This Weekend', now: now);
      expect(c.revisitAfter!.weekday, DateTime.saturday);
    });

    test('non-intent labels map to note kind', () {
      for (final label in ['Share With Someone', 'Make Checklist', 'Research This']) {
        expect(IntentClassifier.classify(label).kind, IntentKind.note, reason: label);
      }
    });

    test('actions are normalized to snake_case', () {
      expect(IntentClassifier.classify('Watch Later').action, 'watch_later');
      expect(IntentClassifier.classify('Already Read').action, 'already_read');
    });
  });

  group('RevisitScorer', () {
    final now = DateTime(2026, 6, 16, 10);

    test('done and dismissed items are excluded', () {
      expect(
        RevisitScorer.score(_url(intentStatus: 'done'), seeds: const [], now: now).isExcluded,
        isTrue,
      );
      expect(
        RevisitScorer.score(
          _url(rediscoverDismissedAt: now),
          seeds: const [],
          now: now,
        ).isExcluded,
        isTrue,
      );
    });

    test('queued-but-not-due is held back; queued-and-due floats to the top', () {
      final notDue = _url(
        intentStatus: 'queued',
        intentAction: 'watch_later',
        revisitAfter: now.add(const Duration(days: 2)),
      );
      expect(RevisitScorer.score(notDue, seeds: const [], now: now).isExcluded, isTrue);

      final due = _url(
        intentStatus: 'queued',
        intentAction: 'watch_later',
        revisitAfter: now.subtract(const Duration(hours: 1)),
      );
      final scored = RevisitScorer.score(due, seeds: const [], now: now);
      expect(scored.isExcluded, isFalse);
      expect(scored.score, greaterThan(900));
      expect(scored.reason, 'Time to watch this');
    });

    test('never-opened older saves outscore recently resurfaced ones', () {
      final fresh = _url(id: 1, openedAt: null);
      final justResurfaced = _url(
        id: 2,
        openedAt: null,
        resurfacedAt: now.subtract(const Duration(days: 1)),
      );
      final a = RevisitScorer.score(fresh, seeds: const [], now: now).score;
      final b = RevisitScorer.score(justResurfaced, seeds: const [], now: now).score;
      expect(a, greaterThan(b));
    });

    test('onThisDayLabel detects a one-year anniversary', () {
      final yearOld = _url(savedAt: now.subtract(const Duration(days: 365)));
      expect(RevisitScorer.onThisDayLabel(yearOld, now: now), 'A year ago today');
    });
  });

  group('NotificationActionHandler.handleIfAction', () {
    NotificationResponse resp({String? actionId, String? payload}) =>
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: actionId,
          payload: payload,
        );

    test('a plain body tap (no actionId) is not consumed', () async {
      final consumed = await NotificationActionHandler.handleIfAction(
        resp(payload: '{"linkIds":[1]}'),
      );
      expect(consumed, isFalse);
    });

    test('an unknown actionId is not consumed', () async {
      final consumed = await NotificationActionHandler.handleIfAction(
        resp(actionId: 'something_else', payload: '{"linkIds":[1]}'),
      );
      expect(consumed, isFalse);
    });

    test('a known action with no link ids is consumed but is a no-op', () async {
      // Empty payload returns before any database access, so no Isar needed.
      final consumed = await NotificationActionHandler.handleIfAction(
        resp(actionId: NotificationActions.markDone, payload: null),
      );
      expect(consumed, isTrue);
    });
  });

  group('Geography notification accuracy', () {
    test('unreadLinksForGeo returns only the featured place, unread & not done',
        () {
      final urls = [
        _url(id: 1, tags: ['india', 'trek']),
        _url(id: 2, tags: ['new zealand']),
        _url(id: 3, tags: ['india'], openedAt: DateTime.now()), // read
        _url(id: 4, tags: ['india'], intentStatus: 'done'), // archived
        _url(id: 5, tags: ['india', 'food']),
      ];
      final india = TagAnalyzer.unreadLinksForGeo(urls, 'india');
      expect(india.map((u) => u.id).toSet(), {1, 5});
    });
  });

  group('Notification anti-repeat (recentSignatures)', () {
    test('returns recent signatures and drops ones outside the window',
        () async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'digest_history': jsonEncode([
          {'date': now.toIso8601String(), 'sig': 'A:india'},
          {
            'date': now.subtract(const Duration(days: 5)).toIso8601String(),
            'sig': 'E:42',
          },
          {'date': now.toIso8601String(), 'topic': 'no sig here'},
        ]),
      });
      final recent =
          await DigestPrefs.recentSignatures(within: const Duration(days: 3));
      expect(recent, contains('A:india'));
      expect(recent, isNot(contains('E:42'))); // 5 days old → outside window
      expect(recent.length, 1);
    });
  });
}
