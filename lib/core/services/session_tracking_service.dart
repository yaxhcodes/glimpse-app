import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A lightweight, migration-safe record that links a saved URL to a capture
/// session.  Stored as JSON on disk so it never touches the Isar schema.
class SessionRecord {
  final int urlId;
  final String sessionId;
  final DateTime savedAt;

  const SessionRecord({
    required this.urlId,
    required this.sessionId,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
    'urlId': urlId,
    'sessionId': sessionId,
    'savedAt': savedAt.toIso8601String(),
  };

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
    urlId: json['urlId'] as int,
    sessionId: json['sessionId'] as String,
    savedAt: DateTime.parse(json['savedAt'] as String),
  );
}

/// Persists URL → session mappings outside Isar so the feature is fully
/// migration-safe and does not require regenerating collection code.
class SessionTrackingService {
  static const _fileName = 'glimpse_save_sessions.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<SessionRecord>> _readAll() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];
      final json = await file.readAsString();
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => SessionRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeAll(List<SessionRecord> records) async {
    final file = await _file();
    final json = jsonEncode(records.map((r) => r.toJson()).toList());
    await file.writeAsString(json);
  }

  Future<List<SessionRecord>> readAll() => _readAll();

  Future<void> writeAll(List<SessionRecord> records) => _writeAll(records);

  /// Removes every capture-session record for permanently deleted URLs in one
  /// file rewrite.
  Future<void> removeUrlIds(Iterable<int> urlIds) async {
    final ids = urlIds.toSet();
    if (ids.isEmpty) return;
    final all = await _readAll();
    final remaining = all
        .where((record) => !ids.contains(record.urlId))
        .toList();
    if (remaining.length == all.length) return;
    await _writeAll(remaining);
  }

  /// Record that [urlId] belongs to [sessionId].
  Future<void> record({required int urlId, required String sessionId}) async {
    final all = await _readAll();
    all.add(
      SessionRecord(
        urlId: urlId,
        sessionId: sessionId,
        savedAt: DateTime.now(),
      ),
    );
    await _writeAll(all);
  }

  /// Record many URL IDs at once (atomic write).
  Future<void> recordBatch({
    required List<int> urlIds,
    required String sessionId,
  }) async {
    final now = DateTime.now();
    final all = await _readAll();
    for (final id in urlIds) {
      all.add(SessionRecord(urlId: id, sessionId: sessionId, savedAt: now));
    }
    await _writeAll(all);
  }

  /// All URL IDs belonging to [sessionId].
  Future<List<int>> urlIdsForSession(String sessionId) async {
    final all = await _readAll();
    return all
        .where((r) => r.sessionId == sessionId)
        .map((r) => r.urlId)
        .toList();
  }

  /// Session IDs sorted by most recent first.
  Future<List<String>> allSessionIds() async {
    final all = await _readAll();
    final grouped = <String, DateTime>{};
    for (final r in all) {
      final existing = grouped[r.sessionId];
      if (existing == null || r.savedAt.isAfter(existing)) {
        grouped[r.sessionId] = r.savedAt;
      }
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList();
  }

  /// Full records for a session, newest first.
  Future<List<SessionRecord>> recordsForSession(String sessionId) async {
    final all = await _readAll();
    return all.where((r) => r.sessionId == sessionId).toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  /// The session ID for a given URL, or null.
  Future<String?> sessionIdForUrl(int urlId) async {
    final all = await _readAll();
    for (final r in all.reversed) {
      if (r.urlId == urlId) return r.sessionId;
    }
    return null;
  }

  /// Delete all records (used by "Clear all data").
  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
