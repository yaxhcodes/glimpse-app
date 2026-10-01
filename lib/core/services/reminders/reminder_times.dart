import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../models/saved_url.dart';

import '../../../l10n/l10n.dart';

enum ReminderPreset { laterToday, tonight, tomorrow, weekend, nextWeek }

/// The reminder UI's sense of "now". Tests pin it so the picks and labels
/// they draw don't change with the day the suite runs.
@visibleForTesting
DateTime Function() reminderClock = DateTime.now;

DateTime reminderNow() => reminderClock();

/// The quick picks offered when setting a reminder, each with the moment it
/// stands for, from [now]. Picks that would land in the past or on top of
/// another are left out, so the list only ever offers real choices.
List<(ReminderPreset, DateTime)> reminderPresets(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  DateTime at(DateTime day, int hour) =>
      DateTime(day.year, day.month, day.day, hour);

  final presets = <(ReminderPreset, DateTime)>[];

  // Three hours out, on the quarter hour, while the evening is still ahead.
  final later = _roundUpToQuarter(now.add(const Duration(hours: 3)));
  if (later.day == now.day && later.hour < 20) {
    presets.add((ReminderPreset.laterToday, later));
  }

  final tonight = at(today, 20);
  if (now.isBefore(tonight.subtract(const Duration(hours: 1)))) {
    presets.add((ReminderPreset.tonight, tonight));
  }

  presets.add((
    ReminderPreset.tomorrow,
    at(today.add(const Duration(days: 1)), 9),
  ));

  // Saturday morning, Monday to Thursday only: on a Friday "tomorrow"
  // already is Saturday, and on the weekend itself "this weekend" would
  // mean the next one.
  if (now.weekday <= DateTime.thursday) {
    final saturday = at(
      today.add(Duration(days: DateTime.saturday - now.weekday)),
      10,
    );
    presets.add((ReminderPreset.weekend, saturday));
  }

  final daysToMonday = (DateTime.monday - now.weekday) % 7;
  final monday = at(
    today.add(Duration(days: daysToMonday == 0 ? 7 : daysToMonday)),
    9,
  );
  if (monday.difference(today).inDays > 1) {
    presets.add((ReminderPreset.nextWeek, monday));
  }
  return presets;
}

DateTime _roundUpToQuarter(DateTime time) {
  final minutes = time.minute;
  final rounded = ((minutes + 14) ~/ 15) * 15;
  return DateTime(
    time.year,
    time.month,
    time.day,
    time.hour,
  ).add(Duration(minutes: rounded));
}

/// How a reminder comes back after it first goes off.
enum ReminderRepeat {
  none,
  daily,

  /// Monday to Friday.
  weekdays,

  /// On the first reminder's weekday.
  weekly;

  static ReminderRepeat parse(String? stored) => switch (stored) {
    'daily' => daily,
    'weekdays' => weekdays,
    'weekly' => weekly,
    _ => none,
  };

  /// As kept on the save; null for once.
  String? get stored => this == none ? null : name;

  bool get repeats => this != none;
}

String reminderRepeatLabel(AppLocalizations strings, ReminderRepeat repeat) =>
    switch (repeat) {
      ReminderRepeat.none => strings.repeatOnce,
      ReminderRepeat.daily => strings.repeatDaily,
      ReminderRepeat.weekdays => strings.repeatWeekdays,
      ReminderRepeat.weekly => strings.repeatWeekly,
    };

/// When a reminder first set for [anchor] next goes off at or after [now]:
/// [anchor] itself for one that doesn't repeat. Walks the wall clock day by
/// day, so a daily 7:00 stays 7:00 across a clock change.
DateTime nextReminderOccurrence(
  DateTime anchor,
  ReminderRepeat repeat, {
  DateTime? now,
}) {
  if (!repeat.repeats) return anchor;
  final current = now ?? reminderNow();
  var at = anchor;
  // Skip whole weeks or days at once when the anchor is long past.
  if (at.isBefore(current)) {
    final behind = current.difference(at).inDays;
    final skip = repeat == ReminderRepeat.weekly ? behind ~/ 7 * 7 : behind;
    at = DateTime(at.year, at.month, at.day + skip, at.hour, at.minute);
  }
  final step = repeat == ReminderRepeat.weekly ? 7 : 1;
  while (at.isBefore(current) ||
      (repeat == ReminderRepeat.weekdays && at.weekday > DateTime.friday)) {
    at = DateTime(at.year, at.month, at.day + step, at.hour, at.minute);
  }
  return at;
}

/// A reminder said the short way, repeating or not: "Tomorrow 9:00 AM",
/// "Every day 7:00 AM", "Weekdays 7:00 AM", "Every Monday 7:00 AM".
String formatReminderSchedule(
  AppLocalizations strings,
  String locale,
  DateTime anchor,
  ReminderRepeat repeat, {
  DateTime? now,
}) {
  final time = DateFormat.jm(locale).format(anchor);
  return switch (repeat) {
    ReminderRepeat.none => formatReminderWhen(
      strings,
      locale,
      anchor,
      now: now,
    ),
    ReminderRepeat.daily => strings.reminderEveryDay(time),
    ReminderRepeat.weekdays => strings.reminderWeekdaysAt(time),
    ReminderRepeat.weekly => strings.reminderEveryWeekday(
      DateFormat.EEEE(locale).format(anchor),
      time,
    ),
  };
}

String reminderPresetLabel(AppLocalizations strings, ReminderPreset preset) =>
    switch (preset) {
      ReminderPreset.laterToday => strings.reminderLaterToday,
      ReminderPreset.tonight => strings.reminderTonight,
      ReminderPreset.tomorrow => strings.reminderTomorrow,
      ReminderPreset.weekend => strings.reminderWeekend,
      ReminderPreset.nextWeek => strings.reminderNextWeek,
    };

/// The part of a quick pick its label doesn't already say: just the time
/// for today and tomorrow ("9:00 AM"), the day too further out ("Sat
/// 10:00 AM").
String reminderPresetTime(String locale, ReminderPreset preset, DateTime at) {
  final time = DateFormat.jm(locale).format(at);
  return switch (preset) {
    ReminderPreset.laterToday ||
    ReminderPreset.tonight ||
    ReminderPreset.tomorrow => time,
    ReminderPreset.weekend ||
    ReminderPreset.nextWeek => '${DateFormat.E(locale).format(at)} $time',
  };
}

/// When a reminder fires, said the short way: "Today 20:00", "Tomorrow
/// 09:00", "Sat 10:00" within the week, then "12 Oct".
String formatReminderWhen(
  AppLocalizations strings,
  String locale,
  DateTime at, {
  DateTime? now,
}) {
  final current = now ?? reminderNow();
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(at.year, at.month, at.day);
  final days = day.difference(today).inDays;
  final time = DateFormat.jm(locale).format(at);
  if (days == 0) return strings.reminderToday(time);
  if (days == 1) return strings.reminderTomorrowAt(time);
  if (days > 1 && days < 7) return '${DateFormat.E(locale).format(at)} $time';
  return DateFormat.MMMd(locale).format(at);
}

/// The reminder on [url] that's still to come: a one-off one ahead of now,
/// or any repeating one. Null when there's none.
({DateTime anchor, DateTime next, ReminderRepeat repeat})? liveReminder(
  SavedUrl url, {
  DateTime? now,
}) {
  final anchor = url.remindAt;
  if (anchor == null || url.deletedAt != null) return null;
  final repeat = ReminderRepeat.parse(url.remindRepeat);
  final current = now ?? reminderNow();
  if (!repeat.repeats && !anchor.isAfter(current)) return null;
  return (
    anchor: anchor,
    next: nextReminderOccurrence(anchor, repeat, now: current),
    repeat: repeat,
  );
}
