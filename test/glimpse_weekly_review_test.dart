import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glimpse/features/glimpses/glimpse.dart';
import 'package:glimpse/features/glimpses/glimpse_engine.dart';
import 'package:glimpse/features/glimpses/glimpse_synthesis.dart';
import 'package:glimpse/features/glimpses/glimpse_weekly_review.dart';
import 'package:glimpse/features/glimpses/glimpse_weekly_preparation.dart';
import 'glimpse_engine_test.dart' show candidate, save, stored;

void main() {
  test('automatic written review is off until explicitly enabled', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await WeeklyReviewPreferences.enabled(), false);
    await WeeklyReviewPreferences.setEnabled(true);
    expect(await WeeklyReviewPreferences.enabled(), true);
    expect(await WeeklyReviewPreferences.claimWeek('weekly:2026-09-07'), true);
    expect(await WeeklyReviewPreferences.claimWeek('weekly:2026-09-07'), false);
    await WeeklyReviewPreferences.setEnabled(false);
    expect(await WeeklyReviewPreferences.enabled(), false);
  });

  test('completed edition is preferred over an unfinished week', () {
    Glimpse week(String key, DateTime start, DateTime end) => Glimpse.fromJson({
      ...candidate(kind: GlimpseKind.weekly, key: key).toJson(),
      'createdAt': start.toIso8601String(),
      'periodStart': start.toIso8601String(),
      'periodEnd': end.toIso8601String(),
    });
    final old = week('old', DateTime(2026, 8, 31), DateTime(2026, 9, 7));
    final current = week(
      'current',
      DateTime(2026, 9, 7),
      DateTime(2026, 9, 14),
    );
    expect(
      latestWeeklyReview([
        stored(current),
        stored(old),
      ], DateTime(2026, 9, 9))?.glimpse.key,
      'old',
    );
    final endedBefore = week(
      'before',
      DateTime(2026, 8, 25),
      DateTime(2026, 9, 1),
    );
    final startsAfter = week(
      'after',
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 8),
    );
    expect(
      weeklyReviewsInMonth([
        stored(old),
        stored(startsAfter),
        stored(current),
        stored(endedBefore),
      ], DateTime(2026, 9)).map((s) => s.glimpse.key),
      ['current', 'old'],
    );
  });

  test('review favors personal highlights and omits weak connections', () {
    final g = Glimpse.fromJson({
      ...candidate(kind: GlimpseKind.weekly, ids: [1, 2]).toJson(),
      'evidence': [
        const GlimpseEvidence(
          sourceId: 1,
          text: 'A summary of an earlier decision.',
          kind: GlimpseEvidenceKind.summary,
        ).toJson(),
        const GlimpseEvidence(
          sourceId: 2,
          text: 'An explicitly chosen passage to keep.',
          kind: GlimpseEvidenceKind.highlight,
        ).toJson(),
      ],
    });
    final weak = Glimpse.fromJson({
      ...candidate(kind: GlimpseKind.connection, ids: [1, 3]).toJson(),
      'strong': false,
    });
    final urls = {
      for (final id in [1, 2, 3]) id: save(id, DateTime(2026, 9, 1)),
    };
    final review = GlimpseWeeklyReview.build(g, [stored(weak)], urls);
    expect(review.start?.id, 2);
    expect(review.connection, isNull);
    urls[2]!.intentStatus = 'done';
    expect(GlimpseWeeklyReview.build(g, [], urls).start?.id, 1);
  });

  test('every supporting citation must match a supplied source', () {
    final evidence = [
      const GlimpseEvidence(
        sourceId: 1,
        text: 'Keep reversible decisions inexpensive.',
        kind: GlimpseEvidenceKind.summary,
      ),
      const GlimpseEvidence(
        sourceId: 2,
        text: 'Gather evidence before committing.',
        kind: GlimpseEvidenceKind.summary,
      ),
    ];
    final payload = {
      'paragraphs': [
        {
          'text': 'Two approaches to making a decision.',
          'citations': [
            {'sourceId': 1, 'quote': evidence[0].text},
            {'sourceId': 2, 'quote': evidence[1].text},
          ],
        },
      ],
    };
    expect(
      GlimpseSynthesis.validate(
        jsonEncode(payload),
        evidence,
      ).single.citations.length,
      2,
    );
    expect(
      () => GlimpseSynthesis.validate(
        jsonEncode(payload),
        evidence.take(1).toList(),
      ),
      throwsFormatException,
    );
    final private = Glimpse.fromJson({
      ...candidate().toJson(),
      'evidence': [
        const GlimpseEvidence(
          sourceId: 1,
          text: 'A personal note that must remain private.',
          kind: GlimpseEvidenceKind.note,
        ).toJson(),
      ],
    });
    expect(GlimpseSynthesis.excerpts(private, includeNotes: false), isEmpty);
  });
  test('a week focused on one topic retains distinct ideas for its review', () {
    final all = buildGlimpses(
      GlimpseBuildRequest(
        [
          for (final id in [1, 2, 3])
            save(
              id,
              DateTime(2026, 9, 8),
              summary:
                  'Decision framework $id explains a distinct approach to reversible and irreversible choices.',
            ),
        ],
        [],
        DateTime(2026, 9, 9),
      ),
    );
    final week = all.firstWhere((g) => g.kind == GlimpseKind.weekly);
    expect(week.evidence.length, 3);
  });
}
