import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/intent_classifier.dart';
import 'package:glimpse/core/services/revisit_scorer.dart';

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
}
