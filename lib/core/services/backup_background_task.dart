import 'dart:developer' as developer;
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../database/isar_service.dart';
import 'backup/backup_service.dart';
import 'backup/backup_storage_service.dart';
import 'backup_prefs.dart';

/// Runs inside the WorkManager isolate. Must not depend on Riverpod.
class BackupBackgroundTask {
  static const _tag = 'BackupBackgroundTask';

  /// Writes a backup JSON into the configured SAF folder if interval is on
  /// and a folder exists. Updates [BackupPrefs.lastAutoBackupDateKey].
  static Future<bool> run() async {
    if (!Platform.isAndroid) return true;

    final prefs = await SharedPreferences.getInstance();
    final hours = prefs.getInt(BackupPrefs.autoBackupIntervalHoursKey) ?? 0;
    if (hours <= 0) {
      developer.log('Auto backup disabled', name: _tag);
      return true;
    }

    try {
      final attempt = DateTime.now().toIso8601String();
      await prefs.setString(BackupPrefs.lastAutoBackupAttemptDateKey, attempt);

      final storage = BackupStorageService();
      if (!await storage.hasLocation()) {
        await prefs.remove(BackupPrefs.lastAutoBackupErrorKey);
        developer.log('No backup folder — skipping auto backup', name: _tag);
        return true;
      }

      final isar = IsarService();
      await isar.ensureInitialized();

      final backupService = BackupService(isarService: isar);
      final built = await backupService.buildBackupBytes();

      await storage.writeBackup(
        fileName: built.payload.fileName,
        bytes: built.bytes,
      );

      final now = DateTime.now().toIso8601String();
      await prefs.setString(BackupPrefs.lastAutoBackupDateKey, now);
      await prefs.setString('glimpse_last_backup_date', now);
      await prefs.remove(BackupPrefs.lastAutoBackupErrorKey);

      developer.log(
        'Auto backup OK (${built.payload.linkCount} links)',
        name: _tag,
      );
      return true;
    } catch (e, st) {
      await prefs.setString(
        BackupPrefs.lastAutoBackupErrorKey,
        '${e.runtimeType}: $e',
      );
      developer.log(
        'Auto backup failed: $e',
        name: _tag,
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }
}
