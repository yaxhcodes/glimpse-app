import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'digest_prefs.dart';

class DigestScheduler {
  DigestScheduler._();

  static Future<void> reschedule() async {
    await Workmanager().cancelByUniqueName('glimpse_digest');
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(DigestPrefs.digestEnabledKey) ?? true)) return;

    final day = prefs.getInt(DigestPrefs.digestDayKey) ?? 7;
    final hour = prefs.getInt(DigestPrefs.digestHourKey) ?? 10;
    final minute = prefs.getInt(DigestPrefs.digestMinuteKey) ?? 0;
    final initialDelay = _nextDigestDelay(
      dayOfWeek: day,
      hour: hour,
      minute: minute,
    );

    await Workmanager().registerPeriodicTask(
      'glimpse_digest',
      'digestTask',
      frequency: const Duration(days: 7),
      initialDelay: initialDelay,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  static Duration _nextDigestDelay({
    required int dayOfWeek,
    required int hour,
    required int minute,
  }) {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    var daysAhead = (dayOfWeek - now.weekday) % 7;
    if (daysAhead < 0) daysAhead += 7;
    if (daysAhead == 0 &&
        (now.isAfter(target) || now.isAtSameMomentAs(target))) {
      daysAhead = 7;
    }
    target = target.add(Duration(days: daysAhead));
    var d = target.difference(now);
    if (d.isNegative) d = const Duration(minutes: 15);
    return d;
  }
}
