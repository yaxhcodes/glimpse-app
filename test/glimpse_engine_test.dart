import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/engagement_event.dart';
import 'package:glimpse/core/models/glimpse_record.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/features/glimpses/glimpse.dart';
import 'package:glimpse/features/glimpses/glimpse_engine.dart';
import 'package:glimpse/features/glimpses/glimpse_store.dart';
import 'package:glimpse/features/glimpses/glimpse_synthesis.dart';

SavedUrl save(int id, DateTime at, {String? summary}) => SavedUrl()
  ..id = id
  ..rawUrl = 'https://example.com/$id'
  ..domain = 'example.com'
  ..title = 'Decision making $id'
  ..description = ''
  ..category = 'Philosophy'
  ..categoryEmoji = ''
  ..categories = ['Philosophy']
  ..tags = ['decision making', 'reversible choices']
  ..savedAt = at
  ..summary =
      summary ??
      'Separate reversible choices from irreversible choices before making a decision.'
  ..processingStatus = 'COMPLETED';

Glimpse candidate({
  GlimpseKind kind = GlimpseKind.idea,
  String key = 'idea:1',
  List<int> ids = const [1],
  DateTime? available,
  DateTime? expires,
}) => Glimpse(
  key: key,
  kind: kind,
  topicKey: key,
  topicLabel: 'Decisions',
  sourceIds: ids,
  evidence: [
    GlimpseEvidence(
      sourceId: ids.first,
      text:
          'Separate reversible choices from irreversible choices before deciding.',
      kind: GlimpseEvidenceKind.summary,
    ),
  ],
  createdAt: DateTime(2026, 8, 1),
  availableAt: available ?? DateTime(2026, 8, 1),
  expiresAt: expires ?? DateTime(2027),
  score: 90,
  strong: true,
);

StoredGlimpse stored(
  Glimpse g, {
  DateTime? posted,
  DateTime? opened,
  DateTime? snoozed,
  DateTime? retired,
}) {
  return StoredGlimpse(
    g,
    GlimpseRecord()
      ..key = g.key
      ..contentJson = jsonEncode(g.toJson())
      ..updatedAt = g.createdAt
      ..postedAt = posted
      ..openedAt = opened
      ..snoozedUntil = snoozed
      ..retiredAt = retired,
  );
}

void main() {
  final now = DateTime(2026, 9, 8, 19);
  List<Glimpse> build(
    List<SavedUrl> urls, {
    DateTime? at,
    List<EngagementEvent> events = const [],
  }) => buildGlimpses(GlimpseBuildRequest(urls, events, at ?? now));

  test('thin saves produce a local recap without an automatic push', () {
    final url = save(1, now, summary: 'Too short');
    final all = build([url]);
    expect(all.every((g) => g.isRecap), isTrue);
    expect(all.every((g) => !g.canNotify), isTrue);
    expect(all.first.sourceIds, [1]);
  });

  test('category overlap alone does not create a connection', () {
    final old = save(1, DateTime(2026, 6, 1))..tags = ['Philosophy'];
    final recent = save(2, now)..tags = ['Philosophy'];
    expect(
      build([old, recent]).where((g) => g.kind == GlimpseKind.connection),
      isEmpty,
    );
  });

  test('strong semantic connection waits after enrichment and expires', () {
    final old = save(1, DateTime(2026, 6, 1))..embedding = [1, 0, 0];
    final recent = save(2, now)
      ..embedding = [1, 0, 0]
      ..processingUpdatedAt = now;
    final g = build([
      old,
      recent,
    ]).where((g) => g.kind == GlimpseKind.connection).single;
    expect(g.strong, isTrue);
    expect(g.availableAt, now.add(const Duration(hours: 1)));
    expect(g.expiresAt, now.add(const Duration(days: 7)));
    expect(g.evidence.first.sourceId, old.id);
  });

  test('completed saves stay in historical briefs, not active suggestions', () {
    final url = save(1, DateTime(2026, 8, 1))..intentStatus = 'done';
    final all = build([url]);
    expect(all, isNotEmpty);
    expect(all.every((g) => g.isRecap), isTrue);
    url.deletedAt = now;
    expect(build([url]), isEmpty);
  });

  test(
    'explicit intentions preserve due dates and never become random ideas',
    () {
      final due = DateTime(2026, 9, 12, 12);
      final url = save(1, DateTime(2026, 8, 1))
        ..intentStatus = 'queued'
        ..revisitAfter = due;
      final actionable = build([url]).where((g) => !g.isRecap).single;
      expect(actionable.kind, GlimpseKind.intention);
      expect(actionable.availableAt, due);
    },
  );

  test('calendar periods include completed saves and exclude future saves', () {
    final old = save(1, DateTime(2026, 8, 31, 23, 59));
    final today = save(2, DateTime(2026, 9, 1, 0));
    final future = save(3, DateTime(2026, 9, 2));
    final all = build([old, today, future], at: DateTime(2026, 9, 1, 12));
    final daily = all.singleWhere((g) => g.key == 'daily:2026-09-01');
    expect(daily.sourceIds, [2]);
    final monthly = all.singleWhere((g) => g.key == 'monthly:2026-08-01');
    expect(monthly.sourceIds, [1]);
  });

  test('editing a note at the same save count changes evidence and revision', () {
    final url = save(1, DateTime(2026, 8, 1));
    final before = build([url]).firstWhere((g) => g.kind == GlimpseKind.idea);
    url.userNotes =
        'My own note about separating choices that can be undone from those that cannot.';
    final after = build([url]).firstWhere((g) => g.kind == GlimpseKind.idea);
    expect(before.key, after.key);
    expect(before.revision, isNot(after.revision));
    expect(after.evidence.single.kind, GlimpseEvidenceKind.note);
  });

  test(
    'monthly return counts need recorded activity, not an opened timestamp',
    () {
      final old = save(1, DateTime(2026, 7, 1))..openedAt = now;
      final recent = save(2, now);
      final before = build([
        old,
        recent,
      ]).singleWhere((g) => g.key == 'monthly:2026-09-01');
      expect(before.returnedCount, 0);
      final event = EngagementEvent()
        ..type = EngagementEventType.cardOpened
        ..at = now
        ..urlId = 1
        ..hourLocal = 19;
      final after = build(
        [old, recent],
        events: [event],
      ).singleWhere((g) => g.key == 'monthly:2026-09-01');
      expect(after.returnedCount, 1);
      expect(after.sourceIds, contains(1));
    },
  );

  test('record round trip preserves evidence and calendar boundaries', () {
    final g = candidate();
    expect(
      Glimpse.fromJson(jsonDecode(jsonEncode(g.toJson()))).revision,
      g.revision,
    );
  });

  group('delivery policy', () {
    test(
      'quiet hours, future availability, expiration and retirement suppress',
      () {
        final g = stored(candidate());
        expect(GlimpseDeliveryPolicy.canPost(g, [], now), isTrue);
        expect(
          GlimpseDeliveryPolicy.canPost(g, [], DateTime(2026, 9, 8, 21)),
          isFalse,
        );
        expect(
          GlimpseDeliveryPolicy.canPost(
            stored(candidate(available: now.add(const Duration(hours: 1)))),
            [],
            now,
          ),
          isFalse,
        );
        expect(
          GlimpseDeliveryPolicy.canPost(
            stored(candidate(expires: now)),
            [],
            now,
          ),
          isFalse,
        );
        expect(
          GlimpseDeliveryPolicy.canPost(
            stored(candidate(), retired: now),
            [],
            now,
          ),
          isFalse,
        );
      },
    );
    test(
      'failed posts do not spend a slot, successful posts enforce 48 hours',
      () {
        final g = stored(candidate());
        final other = candidate(key: 'idea:2', ids: [2]);
        expect(GlimpseDeliveryPolicy.canPost(g, [stored(other)], now), isTrue);
        expect(
          GlimpseDeliveryPolicy.canPost(g, [
            stored(other, posted: now.subtract(const Duration(hours: 47))),
          ], now),
          isFalse,
        );
      },
    );
    test('three automatic posts in seven days exhaust the budget', () {
      final receipts = [
        for (var i = 0; i < 3; i++)
          stored(
            candidate(key: 'idea:${i + 2}', ids: [i + 2]),
            posted: now.subtract(Duration(hours: 49 + i * 48)),
          ),
      ];
      expect(
        GlimpseDeliveryPolicy.canPost(stored(candidate()), receipts, now),
        isFalse,
      );
    });
    test('same source cannot be repromoted within fourteen days', () {
      final receipt = stored(
        candidate(key: 'connection:1'),
        posted: now.subtract(const Duration(days: 9)),
      );
      expect(
        GlimpseDeliveryPolicy.canPost(stored(candidate()), [receipt], now),
        isFalse,
      );
    });
    test(
      'opened ideas do not push; explicit Later can return after three days',
      () {
        final g = stored(
          candidate(),
          opened: now.subtract(const Duration(days: 4)),
        );
        expect(GlimpseDeliveryPolicy.canPost(g, [], now), isFalse);
        g.record.snoozedUntil = now;
        expect(GlimpseDeliveryPolicy.canPost(g, [], now), isTrue);
        g.record.reminderPostedAt = now;
        expect(GlimpseDeliveryPolicy.canPost(g, [g], now), isFalse);
      },
    );
    test('a pending worker lease prevents a second worker claiming a slot', () {
      final g = stored(candidate())
        ..record.deliveryLeaseUntil = now.add(const Duration(minutes: 5));
      expect(
        GlimpseDeliveryPolicy.canPost(
          stored(candidate(key: 'idea:2', ids: [2])),
          [g],
          now,
        ),
        isFalse,
      );
    });
    test('weekly brief only targets Sunday before its period ends', () {
      final g = stored(candidate(kind: GlimpseKind.weekly));
      expect(GlimpseDeliveryPolicy.canPost(g, [], now), isFalse);
      expect(
        GlimpseDeliveryPolicy.canPost(g, [], DateTime(2026, 9, 13, 19)),
        isTrue,
      );
    });
  });

  group('optional AI evidence', () {
    test('personal notes are excluded unless explicitly included', () {
      final url = save(1, DateTime(2026, 8, 1))
        ..userNotes =
            'A private note with enough detail to become the selected local idea.';
      final g = build([url]).firstWhere((g) => g.kind == GlimpseKind.idea);
      expect(GlimpseSynthesis.excerpts(g, includeNotes: false), isEmpty);
      expect(GlimpseSynthesis.excerpts(g, includeNotes: true), hasLength(1));
    });
    test('unknown sources and fabricated supporting quotes are rejected', () {
      final evidence = candidate().evidence;
      for (final paragraph in [
        {'text': 'A claim', 'sourceId': 99, 'quote': evidence.first.text},
        {
          'text': 'A claim',
          'sourceId': 1,
          'quote': 'This quotation does not exist.',
        },
      ]) {
        expect(
          () => GlimpseSynthesis.validate(
            jsonEncode({
              'paragraphs': [paragraph],
            }),
            evidence,
          ),
          throwsFormatException,
        );
      }
    });
    test('a supported paragraph retains its exact source', () {
      final evidence = candidate().evidence;
      final result = GlimpseSynthesis.validate(
        jsonEncode({
          'paragraphs': [
            {
              'text': 'This excerpt distinguishes two types of choice.',
              'sourceId': 1,
              'quote': evidence.first.text,
            },
          ],
        }),
        evidence,
      );
      expect(result.single.sourceId, 1);
    });
  });
}
