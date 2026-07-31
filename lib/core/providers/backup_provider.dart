import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'service_providers.dart';
import '../services/backup/backup_models.dart';
import '../services/backup/backup_service.dart';
import '../services/backup/backup_storage_service.dart';
import '../services/backup_prefs.dart';
import '../services/backup_scheduler.dart';

final backupProvider = StateNotifierProvider<BackupNotifier, BackupState>((
  ref,
) {
  return BackupNotifier(
    ref.read(backupServiceProvider),
    ref.read(backupStorageServiceProvider),
    onStorageChanged: () => _bumpStorageTick(ref),
  );
});

/// Watches the persistent backup-folder URI. Refreshes whenever
/// `_backupStorageTick` is bumped (folder picked / forgotten / written
/// to), so the UI reflects changes without coupling to the more
/// transient `backupProvider` lifecycle (which juggles error/success
/// transitions for the create/restore flow).
final backupStorageLocationProvider =
    FutureProvider.autoDispose<({String? uri, String? label})>((ref) async {
      ref.watch(_backupStorageTick);
      final svc = ref.watch(backupStorageServiceProvider);
      final uri = await svc.currentLocationUri();
      final label = uri == null ? null : await svc.currentLocationLabel();
      return (uri: uri, label: label);
    });

/// Lists existing backup files inside the persistent folder, newest
/// first. Empty when no folder is set or the folder is empty.
final backupStorageEntriesProvider =
    FutureProvider.autoDispose<List<BackupListEntry>>((ref) async {
      ref.watch(_backupStorageTick);
      final svc = ref.watch(backupStorageServiceProvider);
      return svc.listBackups();
    });

final lastBackupDateProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('glimpse_last_backup_date');
});

@immutable
class AutoBackupSettings {
  const AutoBackupSettings({
    required this.intervalHours,
    this.lastAutoBackupIso,
    this.lastAttemptIso,
    this.lastError,
  });

  final int intervalHours;
  final String? lastAutoBackupIso;
  final String? lastAttemptIso;
  final String? lastError;
}

/// Reads automatic backup prefs (interval + last WorkManager success).
/// Invalidate this after changing the interval.
final autoBackupSettingsProvider =
    FutureProvider.autoDispose<AutoBackupSettings>((ref) async {
      final prefs = await SharedPreferences.getInstance();
      return AutoBackupSettings(
        intervalHours:
            prefs.getInt(BackupPrefs.autoBackupIntervalHoursKey) ?? 0,
        lastAutoBackupIso: prefs.getString(BackupPrefs.lastAutoBackupDateKey),
        lastAttemptIso: prefs.getString(
          BackupPrefs.lastAutoBackupAttemptDateKey,
        ),
        lastError: prefs.getString(BackupPrefs.lastAutoBackupErrorKey),
      );
    });

/// Bumped whenever something about the persistent backup folder changes
/// (folder picked, folder forgotten, new file written into it). The
/// storage-related providers below watch this so they refresh without
/// being coupled to `backupProvider`'s success/error transitions.
final _backupStorageTick = StateProvider<int>((_) => 0);

void _bumpStorageTick(Ref ref) {
  ref.read(_backupStorageTick.notifier).state++;
  ref.invalidate(lastBackupDateProvider);
}

/// What a restore of the currently-previewed backup would do, in the
/// given [RestoreMode]. Returns null when there is no preview data yet.
///
/// Family parameter keys on the mode so switching merge ↔ replace
/// re-computes the impact (which is cheap — just an Isar fetch + a hash
/// lookup per link).
final restoreImpactProvider =
    FutureProvider.family<RestoreImpact?, RestoreMode>((ref, mode) async {
      final state = ref.watch(backupProvider);
      final backup = state.previewData;
      if (backup == null) return null;
      final service = ref.read(backupServiceProvider);
      return service.previewImpact(backup, mode);
    });

class BackupState {
  final BackupStatus status;
  final BackupData? previewData;
  final BackupError? error;
  final double progress;
  final String? filePath;
  final int? restoredCount;

  const BackupState({
    this.status = BackupStatus.idle,
    this.previewData,
    this.error,
    this.progress = 0,
    this.filePath,
    this.restoredCount,
  });

  BackupState copyWith({
    BackupStatus? status,
    BackupData? previewData,
    BackupError? error,
    double? progress,
    String? filePath,
    int? restoredCount,
  }) {
    return BackupState(
      status: status ?? this.status,
      previewData: previewData ?? this.previewData,
      error: error,
      progress: progress ?? this.progress,
      filePath: filePath ?? this.filePath,
      restoredCount: restoredCount ?? this.restoredCount,
    );
  }
}

class BackupNotifier extends StateNotifier<BackupState> {
  final BackupService _backupService;
  final BackupStorageService _storageService;
  final VoidCallback? _onStorageChanged;

  BackupNotifier(
    this._backupService,
    this._storageService, {
    VoidCallback? onStorageChanged,
  }) : _onStorageChanged = onStorageChanged,
       super(const BackupState());

  /// Asks the OS for a folder, persists the grant, and pings any
  /// listeners that the location has changed.
  ///
  /// Returns the human-readable label of the chosen folder on success,
  /// `null` if the user cancelled, or throws on permission failure.
  Future<String?> pickStorageLocation() async {
    final uri = await _storageService.pickLocation();
    if (uri == null) return null;
    final label = await _storageService.currentLocationLabel();
    _onStorageChanged?.call();
    unawaited(BackupScheduler.reschedule());
    return label;
  }

  Future<void> clearStorageLocation() async {
    await _storageService.clearLocation();
    _onStorageChanged?.call();
    unawaited(BackupScheduler.reschedule());
  }

  Future<void> exportBackup() async {
    state = const BackupState(status: BackupStatus.exporting);

    try {
      final filePath = await _backupService.exportBackup();
      final result = _backupService.lastResult;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'glimpse_last_backup_date',
        DateTime.now().toIso8601String(),
      );
      _onStorageChanged?.call();

      state = BackupState(
        status: BackupStatus.success,
        filePath: filePath,
        restoredCount: result?.linkCount,
      );
    } catch (e, st) {
      developer.log(
        'Export failed: $e',
        name: 'BackupNotifier',
        error: e,
        stackTrace: st,
      );
      state = BackupState(
        status: BackupStatus.error,
        error: BackupError(
          message: _userFriendlyExportError(e),
          detail: '${e.runtimeType}: $e\n$st',
        ),
      );
    }
  }

  /// Creates a backup. The behavior depends on what the user has set up:
  ///
  /// 1. If a persistent backup folder has been configured (Mihon-style),
  ///    we write the file straight in via SAF — no picker required.
  /// 2. Otherwise we fall back to the OS save dialog, letting the user
  ///    pick a one-off destination.
  Future<void> saveBackupLocally() async {
    state = const BackupState(status: BackupStatus.savingLocal);

    try {
      final built = await _backupService.buildBackupBytes();

      String savedDestination;
      String? folderLabel;

      if (await _storageService.hasLocation()) {
        final result = await _storageService.writeBackup(
          fileName: built.payload.fileName,
          bytes: built.bytes,
        );
        savedDestination = result.uri;
        folderLabel = result.folderLabel ?? result.displayName;
      } else {
        final savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Glimpse backup',
          fileName: built.payload.fileName,
          type: FileType.custom,
          allowedExtensions: const ['json'],
          bytes: built.bytes,
        );

        if (savedPath == null) {
          // User cancelled the picker.
          state = const BackupState();
          return;
        }

        // On Android the file_picker plugin already wrote the bytes
        // through SAF (because we passed `bytes`). On iOS / desktop the
        // returned path is a writable filesystem path that we still
        // need to write into.
        if (!Platform.isAndroid) {
          try {
            await _backupService.saveBackupToPath(savedPath);
          } catch (e, st) {
            developer.log(
              'Local save fallback write failed: $e',
              name: 'BackupNotifier',
              error: e,
              stackTrace: st,
            );
            rethrow;
          }
        }
        savedDestination = savedPath;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'glimpse_last_backup_date',
        DateTime.now().toIso8601String(),
      );

      state = BackupState(
        status: BackupStatus.savedLocal,
        filePath: folderLabel ?? savedDestination,
        restoredCount: built.payload.linkCount,
      );
      _onStorageChanged?.call();
    } catch (e, st) {
      developer.log(
        'Local save failed: $e',
        name: 'BackupNotifier',
        error: e,
        stackTrace: st,
      );
      state = BackupState(
        status: BackupStatus.error,
        error: BackupError(
          message: _userFriendlyExportError(e),
          detail: '${e.runtimeType}: $e\n$st',
        ),
      );
    }
  }

  Future<void> shareBackup() async {
    final filePath = state.filePath ?? _backupService.lastResult?.filePath;
    if (filePath == null) return;

    try {
      await _backupService.shareBackup(filePath);
    } catch (e, st) {
      // Share cancellation is not an error — the user simply closed the sheet.
      // Only surface genuine failures.
      final msg = e.toString();
      if (msg.contains('cancel') || msg.contains('CANCEL')) return;

      developer.log(
        'Share failed: $e',
        name: 'BackupNotifier',
        error: e,
        stackTrace: st,
      );
      state = BackupState(
        status: BackupStatus.error,
        error: BackupError(
          message: 'Could not share the backup file.',
          detail: '${e.runtimeType}: $msg\n$st',
        ),
      );
    }
  }

  Future<void> validateBackupFile(String filePath) async {
    state = const BackupState(status: BackupStatus.validating);

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        state = BackupState(
          status: BackupStatus.error,
          error: const BackupError(message: 'File not found'),
        );
        return;
      }

      final content = await file.readAsString();
      await validateBackupContent(content);
    } on BackupValidationException catch (e) {
      state = BackupState(
        status: BackupStatus.error,
        error: BackupError(message: e.message),
      );
    } catch (e) {
      state = BackupState(
        status: BackupStatus.error,
        error: BackupError(
          message: 'Could not read the selected file.',
          detail: e.toString(),
        ),
      );
    }
  }

  Future<void> validateBackupContent(String content) async {
    state = const BackupState(status: BackupStatus.validating);

    try {
      final backup = await _backupService.validateBackup(content);
      state = BackupState(status: BackupStatus.previewing, previewData: backup);
    } on BackupValidationException catch (e) {
      state = BackupState(
        status: BackupStatus.error,
        error: BackupError(message: e.message),
      );
    } catch (e) {
      state = BackupState(
        status: BackupStatus.error,
        error: BackupError(
          message: 'Could not read backup data.',
          detail: e.toString(),
        ),
      );
    }
  }

  Future<void> restoreBackup(RestoreMode mode) async {
    final previewData = state.previewData;
    if (previewData == null) {
      state = BackupState(
        status: BackupStatus.error,
        error: const BackupError(message: 'No backup data to restore'),
      );
      return;
    }

    state = const BackupState(status: BackupStatus.restoring);

    try {
      final count = await _backupService.restoreBackup(
        previewData,
        mode,
        onProgress: (progress) {
          state = state.copyWith(
            status: BackupStatus.restoring,
            progress: progress,
          );
        },
      );
      state = BackupState(status: BackupStatus.success, restoredCount: count);
    } catch (e) {
      state = BackupState(
        status: BackupStatus.error,
        error: BackupError(
          message: _userFriendlyRestoreError(e),
          detail: e.toString(),
        ),
      );
    }
  }

  void reset() {
    state = const BackupState();
  }

  String _userFriendlyExportError(Object error) {
    final msg = error.toString();

    if (msg.contains('ArgumentError') ||
        msg.contains('NaN') ||
        msg.contains('Infinity')) {
      return 'Export failed due to invalid data in your library. '
          'Please try again — the system will skip any corrupt values.';
    }

    if (msg.contains('FileSystemException') ||
        msg.contains('writeAsString') ||
        msg.contains('Permission')) {
      return 'Could not save the backup file. '
          'Please check your device storage.';
    }

    if (msg.contains('OutOfMemory') || msg.contains('stackoverflow')) {
      return 'Your library is too large to export in one go. '
          'Try again after restarting the app.';
    }

    return 'Could not export your backup. Please try again.';
  }

  String _userFriendlyRestoreError(Object error) {
    final msg = error.toString();

    if (msg.contains('FormatException') || msg.contains('DateTime')) {
      return 'The backup contains invalid dates. The file may be corrupted.';
    }

    if (msg.contains('Isar') || msg.contains('database')) {
      return 'Could not write to your library. Please restart the app and try again.';
    }

    return 'Could not restore your backup. Please try again.';
  }
}
