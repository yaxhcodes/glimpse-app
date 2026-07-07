import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'digest_prefs.dart';
import 'tag_analyzer.dart';

/// Schedules a daily one-off WorkManager task that fires 1 hour before the
/// user's peak open hour (defaulting to 7pm if no histogram data yet).
/// After each run the background callback chains the next day's task.
class DigestScheduler {
  DigestScheduler._();

  static const _taskUniqueName = 'glimpse_notif_daily';
  static const taskName = 'notifTask';

  /// Cancel pending work and schedule the next run.
  /// Called on app start and whenever settings change.
  static Future<void> reschedule() async {
    final workmanager = Workmanager();
    try {
      await workmanager.cancelByUniqueName(_taskUniqueName);
    } on UnimplementedError catch (error) {
      developer.log(
        'Digest scheduling unavailable: $error',
        name: 'DigestScheduler',
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(DigestPrefs.digestEnabledKey) ?? true)) return;

    final delay = await _nextDelay();

    try {
      await workmanager.registerOneOffTask(
        _taskUniqueName,
        taskName,
        initialDelay: delay,
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    } on UnimplementedError catch (error) {
      developer.log(
        'Digest scheduling unavailable: $error',
        name: 'DigestScheduler',
      );
    }
  }

  /// Schedule tomorrow's run. Called by the background callback after each run.
  static Future<void> scheduleNext() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(DigestPrefs.digestEnabledKey) ?? true)) return;

    final delay = await _nextDelay();

    try {
      await Workmanager().registerOneOffTask(
        _taskUniqueName,
        taskName,
        initialDelay: delay,
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    } on UnimplementedError catch (error) {
      developer.log(
        'Digest scheduling unavailable: $error',
        name: 'DigestScheduler',
      );
    }
  }

  /// Compute delay until next fire window: (peak_hour - 1) tomorrow,
  /// or today if the window hasn't passed yet.
  static Future<Duration> _nextDelay() async {
    final peak = await TagAnalyzer.peakOpenHour();
    // Fire 1 hour before peak. Clamp to 8–22 range.
    var fireHour = (peak - 1).clamp(8, 22);

    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, fireHour);

    // If today's window already passed, schedule for tomorrow.
    if (now.isAfter(target) || now.isAtSameMomentAs(target)) {
      target = target.add(const Duration(days: 1));
    }

    var d = target.difference(now);
    if (d.isNegative) d = const Duration(minutes: 15);
    return d;
  }
}
