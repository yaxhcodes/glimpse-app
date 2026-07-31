import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';

/// Result of a successful write to the user-chosen backup folder.
class BackupStorageWriteResult {
  /// The `content://` URI of the file we just wrote (so we can share /
  /// open it later if needed).
  final String uri;

  /// Filename as actually saved (may differ from what we asked for if
  /// the SAF provider rewrote it).
  final String displayName;

  /// Human-readable folder, e.g. `/storage/emulated/0/Documents/Glimpse`.
  final String? folderLabel;

  const BackupStorageWriteResult({
    required this.uri,
    required this.displayName,
    required this.folderLabel,
  });

  factory BackupStorageWriteResult.fromMap(Map map) {
    return BackupStorageWriteResult(
      uri: map['uri'] as String,
      displayName: map['displayName'] as String? ?? 'backup.json',
      folderLabel: map['label'] as String?,
    );
  }
}

/// One backup file already present in the configured folder.
class BackupListEntry {
  final String name;
  final String uri;
  final DateTime? lastModified;

  const BackupListEntry({
    required this.name,
    required this.uri,
    this.lastModified,
  });

  factory BackupListEntry.fromMap(Map map) {
    final ts = int.tryParse(map['lastModified']?.toString() ?? '');
    return BackupListEntry(
      name: map['name'] as String? ?? '',
      uri: map['uri'] as String? ?? '',
      lastModified: ts != null && ts > 0
          ? DateTime.fromMillisecondsSinceEpoch(ts)
          : null,
    );
  }
}

/// Bridge for the persistent backup folder (Storage Access Framework on
/// Android). All entry points are no-ops on non-Android platforms — the
/// caller is expected to fall back to the share / system save flow there.
///
/// This is the "Storage location" feature in Mihon's data and storage
/// screen: pick a folder once, the OS grants us long-lived read/write
/// permission to it, and we write our backup `.json` files straight in
/// without re-prompting.
class BackupStorageService {
  static const _tag = 'BackupStorageService';
  static const _channel = MethodChannel(
    'com.shinrinyoku.glimpse/backup_storage',
  );

  bool get isSupported => Platform.isAndroid;

  /// Opens the system folder picker. Returns the persisted folder URI on
  /// success, or null if the user cancelled. Throws on platform failures
  /// (e.g. the URI couldn't be persisted).
  Future<String?> pickLocation() async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('pickLocation');
    } on MissingPluginException {
      return null;
    } catch (e, st) {
      developer.log(
        'pickLocation failed: $e',
        name: _tag,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns the currently saved backup-folder URI, or null if the user
  /// hasn't picked one yet (or if the granted permission was revoked).
  Future<String?> currentLocationUri() async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('currentLocationUri');
    } on MissingPluginException catch (error, stackTrace) {
      developer.log(
        'Backup storage plugin is unavailable',
        name: _tag,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Friendly path for the current folder, e.g.
  /// `/storage/emulated/0/Documents/Glimpse`. Null if no folder set.
  Future<String?> currentLocationLabel() async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('currentLocationLabel');
    } on MissingPluginException {
      return null;
    }
  }

  /// Whether a backup folder has been chosen and is still writable.
  Future<bool> hasLocation() async {
    final uri = await currentLocationUri();
    return uri != null && uri.isNotEmpty;
  }

  /// Forgets the chosen folder (does not delete its contents).
  Future<void> clearLocation() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('clearLocation');
    } on MissingPluginException {
      // No-op on platforms that don't have the channel.
    }
  }

  /// Writes [bytes] to `<folder>/<fileName>`, replacing any existing
  /// file with that exact name. Throws on failure.
  Future<BackupStorageWriteResult> writeBackup({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (!isSupported) {
      throw StateError('writeBackup is only supported on Android');
    }
    final result = await _channel.invokeMethod<Map>('writeBackup', {
      'fileName': fileName,
      'bytes': bytes,
    });
    if (result == null) {
      throw StateError('writeBackup returned no result');
    }
    return BackupStorageWriteResult.fromMap(result);
  }

  /// Lists the `.json` files in the chosen folder, newest first. Returns
  /// an empty list if no folder is configured.
  Future<List<BackupListEntry>> listBackups() async {
    if (!isSupported) return const [];
    try {
      final raw = await _channel.invokeMethod<List>('listBackups');
      if (raw == null) return const [];
      return raw
          .whereType<Map>()
          .map(BackupListEntry.fromMap)
          .toList(growable: false);
    } on MissingPluginException {
      return const [];
    }
  }
}
