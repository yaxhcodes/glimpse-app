import 'package:shared_preferences/shared_preferences.dart';

import '../database/isar_service.dart';
import 'digest_notifications.dart';
import 'digest_prefs.dart';
import 'notification_scheduler.dart';

class DigestBackgroundTask {
  /// [singleType] — pass a type letter (A–F) to test a single type,
  /// bypassing schedule/cap checks.
  static Future<void> run({String? singleType}) async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getBool(DigestPrefs.digestEnabledKey) ?? true) == false) {
      await DigestPrefs.saveLastRunStatus('skipped: digest disabled');
      return;
    }

    final isar = IsarService();
    await isar.ensureInitialized();

    await DigestNotifications.initForBackground();

    final String result;
    if (singleType != null) {
      result = await NotificationScheduler.runSingle(isar, singleType);
    } else {
      result = await NotificationScheduler.runScheduled(isar);
    }

    await DigestPrefs.saveLastRunStatus(result);
  }
}
