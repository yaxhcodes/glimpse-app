import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/glimpses/glimpse_activity.dart';
import 'package:glimpse/features/glimpses/glimpse_copy.dart';
import 'package:glimpse/l10n/generated/app_localizations_en.dart';
import 'package:glimpse/l10n/generated/app_localizations_de.dart';
import 'glimpse_engine_test.dart' show save;

void main() {
  test(
    'period counts all live saves once regardless of enrichment or completion',
    () {
      final a = save(1, DateTime(2026, 9, 1), summary: '')
        ..intentStatus = 'done';
      final b = save(2, DateTime(2026, 9, 8), summary: '')
        ..processingStatus = 'PENDING';
      final bin = save(3, DateTime(2026, 9, 2))
        ..deletedAt = DateTime(2026, 9, 3);
      final data = buildGlimpseActivity((
        [
          a,
          a,
          b,
          bin,
          save(4, DateTime(2026, 8, 31, 23, 59)),
          save(5, DateTime(2026, 9, 9)),
        ],
        DateTime(2026, 9, 8, 21),
      ));
      final month = data.month(DateTime(2026, 9));
      expect(month.sources.map((u) => u.id), [2, 1]);
      expect(month.days[DateTime(2026, 9, 1)], [1]);
      expect(month.days[DateTime(2026, 9, 8)], [2]);
    },
  );

  test('calendar windows respect leap day and exclusive end across years', () {
    final data = buildGlimpseActivity((
      [
        save(1, DateTime(2024, 2, 29, 23, 59)),
        save(2, DateTime(2024, 3, 1)),
        save(3, DateTime(2025, 12, 31)),
        save(4, DateTime(2026, 1, 1)),
      ],
      DateTime(2026, 2),
    ));
    expect(data.month(DateTime(2024, 2)).sources.map((u) => u.id), [1]);
    expect(
      data
          .period(DateTime(2025, 12, 29), DateTime(2026, 1, 5))
          .sources
          .map((u) => u.id),
      [4, 3],
    );
  });

  test(
    'topic totals count saves and localized brief represents the period',
    () {
      final data = buildGlimpseActivity((
        [
          save(1, DateTime(2026, 9, 1))..title = 'Cooking recipes',
          save(2, DateTime(2026, 9, 2))..title = 'Cooking recipes',
          save(3, DateTime(2026, 9, 3))..title = 'Music production',
        ],
        DateTime(2026, 9, 8),
      ));
      final month = data.month(DateTime(2026, 9));
      expect(month.topics.first.subject.key, 'recipes');
      expect(month.topics.first.sourceIds.length, 2);
      final brief = glimpsePeriodSummary(month, AppLocalizationsEn());
      expect(brief, contains('3 items'));
      expect(brief, contains('Recipes & Cooking (2)'));
      expect(brief, contains('Music (1)'));
      expect(brief, isNot(contains('reversible choices')));
      expect(
        glimpsePeriodSummary(month, AppLocalizationsDe()),
        contains('Rezepte & Kochen'),
      );
    },
  );

  test('empty periods have no invented topics or activity', () {
    final month = buildGlimpseActivity((
      [],
      DateTime(2026, 9),
    )).month(DateTime(2026, 9));
    expect(month.topics, isEmpty);
    expect(month.days, isEmpty);
    expect(
      glimpsePeriodSummary(month, AppLocalizationsEn()),
      'No saves in this period yet.',
    );
  });
}
