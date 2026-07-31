import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'backup_prefs.dart';
import 'backup/backup_storage_service.dart';

/// Schedules periodic WorkManager runs to write a JSON backup into the
/// user-chosen SAF folder. Only meaningful on Android with a configured
/// storage location and a non-zero interval.
class BackupScheduler {
  BackupScheduler._();

  static const _uniqueName = 'glimpse_auto_backup';
  static const taskName = 'autoBackupTask';

  static const List<int> intervalHourChoices = [0, 6, 12, 24, 168];

  static String intervalLabel(int hours) {
    return switch (hours) {
      0 => 'Off',
      6 => 'Every 6 hours',
      12 => 'Every 12 hours',
      24 => 'Every 24 hours',
      168 => 'Every week',
      _ => 'Every $hours hours',
    };
  }

  static Future<int> intervalHours() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(BackupPrefs.autoBackupIntervalHoursKey) ?? 0;
  }

  static Future<void> setIntervalHours(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedHours = hours <= 0 ? 0 : hours;
    await prefs.setInt(BackupPrefs.autoBackupIntervalHoursKey, normalizedHours);
    if (normalizedHours == 0) {
      await prefs.remove(BackupPrefs.lastAutoBackupErrorKey);
    }
    await reschedule();
  }

  /// Re-read prefs and register or cancel the periodic task.
  static Future<void> reschedule() async {
    await Workmanager().cancelByUniqueName(_uniqueName);

    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    final hours = prefs.getInt(BackupPrefs.autoBackupIntervalHoursKey) ?? 0;
    if (hours <= 0) return;

    final storage = BackupStorageService();
    if (!await storage.hasLocation()) return;

    final frequency = Duration(hours: hours);

    await Workmanager().registerPeriodicTask(
      _uniqueName,
      taskName,
      frequency: frequency,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }
}
