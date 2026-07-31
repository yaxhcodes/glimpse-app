/// SharedPreferences keys for automatic backup scheduling.
class BackupPrefs {
  BackupPrefs._();

  /// Hours between automatic backups. `0` means off.
  /// Allowed values: 0, 6, 12, 24, 168 (1 week).
  static const autoBackupIntervalHoursKey =
      'glimpse_auto_backup_interval_hours';

  /// ISO-8601 timestamp of the last successful automatic backup (not manual).
  static const lastAutoBackupDateKey = 'glimpse_last_auto_backup_date';

  /// ISO-8601 timestamp of the most recent automatic-backup attempt.
  static const lastAutoBackupAttemptDateKey =
      'glimpse_last_auto_backup_attempt_date';

  /// Short diagnostic from the last failed automatic backup.
  static const lastAutoBackupErrorKey = 'glimpse_last_auto_backup_error';
}
