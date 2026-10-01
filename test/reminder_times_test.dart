import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/reminders/reminder_times.dart';
import 'package:glimpse/l10n/generated/app_localizations_en.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  Map<ReminderPreset, DateTime> presetsAt(DateTime now) =>
      {for (final (preset, at) in reminderPresets(now)) preset: at};

  test('a Tuesday morning offers every pick, each in the future', () {
    final now = DateTime(2026, 10, 6, 9, 10); // Tuesday
    final presets = presetsAt(now);
    expect(presets.keys, [
      ReminderPreset.laterToday,
      ReminderPreset.tonight,
      ReminderPreset.tomorrow,
      ReminderPreset.weekend,
      ReminderPreset.nextWeek,
    ]);
    expect(presets[ReminderPreset.laterToday], DateTime(2026, 10, 6, 12, 15));
    expect(presets[ReminderPreset.tonight], DateTime(2026, 10, 6, 20));
    expect(presets[ReminderPreset.tomorrow], DateTime(2026, 10, 7, 9));
    expect(presets[ReminderPreset.weekend], DateTime(2026, 10, 10, 10));
    expect(presets[ReminderPreset.nextWeek], DateTime(2026, 10, 12, 9));
    for (final at in presets.values) {
      expect(at.isAfter(now), isTrue);
    }
  });

  test('late evening drops later today and tonight', () {
    final presets = presetsAt(DateTime(2026, 10, 6, 19, 30));
    expect(presets.containsKey(ReminderPreset.laterToday), isFalse);
    expect(presets.containsKey(ReminderPreset.tonight), isFalse);
    expect(presets[ReminderPreset.tomorrow], DateTime(2026, 10, 7, 9));
  });

  test('Friday: tomorrow already is the weekend', () {
    final presets = presetsAt(DateTime(2026, 10, 9, 10)); // Friday
    expect(presets.containsKey(ReminderPreset.weekend), isFalse);
    expect(presets[ReminderPreset.nextWeek], DateTime(2026, 10, 12, 9));
  });

  test('Sunday: no "this weekend", and tomorrow covers Monday', () {
    final presets = presetsAt(DateTime(2026, 10, 11, 10)); // Sunday
    expect(presets.containsKey(ReminderPreset.weekend), isFalse);
    expect(presets.containsKey(ReminderPreset.nextWeek), isFalse);
    expect(presets[ReminderPreset.tomorrow], DateTime(2026, 10, 12, 9));
  });

  test('Monday asks for next Monday, not today', () {
    final presets = presetsAt(DateTime(2026, 10, 12, 8)); // Monday
    expect(presets[ReminderPreset.nextWeek], DateTime(2026, 10, 19, 9));
  });

  test('later today rounds up to the quarter hour', () {
    final presets = presetsAt(DateTime(2026, 10, 6, 10, 46));
    expect(presets[ReminderPreset.laterToday], DateTime(2026, 10, 6, 14));
  });

  test('when a reminder fires, said the short way', () {
    final strings = AppLocalizationsEn();
    final now = DateTime(2026, 10, 6, 9); // Tuesday
    // Newer locale data puts a narrow no-break space before AM/PM.
    String say(DateTime at) => formatReminderWhen(
      strings,
      'en',
      at,
      now: now,
    ).replaceAll(' ', ' ');
    expect(say(DateTime(2026, 10, 6, 20)), 'Today 8:00 PM');
    expect(say(DateTime(2026, 10, 7, 9)), 'Tomorrow 9:00 AM');
    expect(say(DateTime(2026, 10, 10, 10)), 'Sat 10:00 AM');
    expect(say(DateTime(2026, 10, 20, 9)), 'Oct 20');
  });

  group('repeat', () {
    final now = DateTime(2026, 10, 6, 9); // Tuesday 9:00

    test('a daily reminder long past comes back today or tomorrow', () {
      final anchor = DateTime(2026, 9, 1, 7, 30);
      expect(
        nextReminderOccurrence(anchor, ReminderRepeat.daily, now: now),
        DateTime(2026, 10, 7, 7, 30),
      );
      expect(
        nextReminderOccurrence(
          DateTime(2026, 9, 1, 20),
          ReminderRepeat.daily,
          now: now,
        ),
        DateTime(2026, 10, 6, 20),
      );
    });

    test('weekdays skip the weekend', () {
      final saturday = DateTime(2026, 10, 10, 10);
      expect(
        nextReminderOccurrence(saturday, ReminderRepeat.weekdays, now: now),
        DateTime(2026, 10, 12, 10),
      );
      final friday = DateTime(2026, 10, 9, 18);
      expect(
        nextReminderOccurrence(
          friday,
          ReminderRepeat.weekdays,
          now: DateTime(2026, 10, 9, 19),
        ),
        DateTime(2026, 10, 12, 18),
      );
    });

    test('weekly keeps its weekday', () {
      final monday = DateTime(2026, 9, 7, 8);
      final next = nextReminderOccurrence(
        monday,
        ReminderRepeat.weekly,
        now: now,
      );
      expect(next, DateTime(2026, 10, 12, 8));
      expect(next.weekday, DateTime.monday);
    });

    test('once is just the time set', () {
      final at = DateTime(2026, 10, 20, 9);
      expect(nextReminderOccurrence(at, ReminderRepeat.none, now: now), at);
    });

    test('stored values round-trip', () {
      for (final repeat in ReminderRepeat.values) {
        expect(ReminderRepeat.parse(repeat.stored), repeat);
      }
      expect(ReminderRepeat.parse('nonsense'), ReminderRepeat.none);
    });

    test('a repeating reminder reads as a schedule', () {
      final strings = AppLocalizationsEn();
      String say(ReminderRepeat repeat) => formatReminderSchedule(
        strings,
        'en',
        DateTime(2026, 10, 12, 7),
        repeat,
        now: now,
      ).replaceAll(' ', ' ');
      expect(say(ReminderRepeat.daily), 'Every day 7:00 AM');
      expect(say(ReminderRepeat.weekdays), 'Weekdays 7:00 AM');
      expect(say(ReminderRepeat.weekly), 'Every Monday 7:00 AM');
      expect(say(ReminderRepeat.none), 'Mon 7:00 AM');
    });
  });
}
