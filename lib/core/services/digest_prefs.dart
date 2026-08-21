// ignore_for_file: use_null_aware_elements

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persisted state for notifications, scheduling, and the notifications screen.
class DigestPrefs {
  DigestPrefs._();

  static final StreamController<void> _historyChanges =
      StreamController<void>.broadcast(sync: true);

  /// Emits after notification history is changed in this isolate.
  ///
  /// Background isolates have their own controller, so notification surfaces
  /// should also refresh when the app resumes.
  static Stream<void> get historyChanges => _historyChanges.stream;

  static const _lastKey = 'digest_last_json';
  static const _historyKey = 'digest_history';
  static const digestEnabledKey = 'digest_enabled';
  static const digestDayKey = 'digest_day';
  static const digestHourKey = 'digest_hour';
  static const digestMinuteKey = 'digest_minute';

  // ── Single last digest (kept for backward compat with DigestScreen) ──

  static Future<void> saveLastDigest({
    required List<int> ids,
    required List<String> summaries,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _lastKey,
      jsonEncode({'ids': ids, 'summaries': summaries}),
    );
  }

  static Future<Map<String, dynamic>?> loadLastDigest() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_lastKey);
    if (s == null) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Notification history (all 6 types) ──

  static String notifPayloadKey(String notifId) => 'notif_payload_$notifId';

  static Future<void> saveNotifPayload(
    String notifId,
    Map<String, dynamic> payload,
  ) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(notifPayloadKey(notifId), jsonEncode(payload));
  }

  static Future<void> deleteNotifPayload(String notifId) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(notifPayloadKey(notifId));
  }

  static Future<Map<String, dynamic>?> loadNotifPayload(String notifId) async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    final s = p.getString(notifPayloadKey(notifId));
    if (s == null) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<String> addDigestToHistory({
    required List<int> ids,
    required List<String> summaries,
    required String topic,
    String type = 'digest',
    String? notifId,
    String? body,
    String? sig,
  }) async {
    final p = await SharedPreferences.getInstance();
    final history = await loadHistory();
    final now = DateTime.now();
    final historyId = now.microsecondsSinceEpoch.toString();
    history.insert(0, {
      'id': historyId,
      'date': now.toIso8601String(),
      'ids': ids,
      'summaries': summaries,
      'topic': topic,
      'type': type,
      'read': false,
      if (notifId != null) 'notifId': notifId,
      if (body != null) 'body': body,
      if (sig != null) 'sig': sig,
    });
    if (history.length > 50) history.removeRange(50, history.length);
    await p.setString(_historyKey, jsonEncode(history));
    _historyChanges.add(null);
    return historyId;
  }

  /// Topic signatures (e.g. `A:india`, `G:42`) fired [within] the given window.
  /// Used to suppress re-sending the same notification topic day after day.
  static Future<Set<String>> recentSignatures({
    Duration within = const Duration(days: 3),
  }) async {
    final history = await loadHistory();
    final cutoff = DateTime.now().subtract(within);
    final out = <String>{};
    for (final e in history) {
      final sig = e['sig'];
      if (sig is! String || sig.isEmpty) continue;
      final date = DateTime.tryParse(e['date']?.toString() ?? '');
      if (date == null || date.isBefore(cutoff)) continue;
      out.add(sig);
    }
    return out;
  }

  static Future<List<Map<String, dynamic>>> loadHistory() async {
    final p = await SharedPreferences.getInstance();
    // Notification workers run in a background isolate with a separate
    // SharedPreferences cache. Always reload before reading history so the
    // foreground hub sees a just-delivered notification immediately.
    await p.reload();
    final s = p.getString(_historyKey);
    if (s == null) return [];
    try {
      final list = jsonDecode(s) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> markDigestRead(String digestId) async {
    final p = await SharedPreferences.getInstance();
    final history = await loadHistory();
    for (final entry in history) {
      if (entry['id'] == digestId) {
        entry['read'] = true;
      }
    }
    await p.setString(_historyKey, jsonEncode(history));
    _historyChanges.add(null);
  }

  static Future<void> deleteDigest(String digestId) async {
    final p = await SharedPreferences.getInstance();
    final history = await loadHistory();
    history.removeWhere((e) => e['id'] == digestId);
    await p.setString(_historyKey, jsonEncode(history));
    _historyChanges.add(null);
  }

  static Future<void> restoreDigest(
    Map<String, dynamic> entry, {
    int index = 0,
  }) async {
    final p = await SharedPreferences.getInstance();
    final history = await loadHistory();
    final id = entry['id'];
    history.removeWhere((e) => e['id'] == id);
    final insertAt = index.clamp(0, history.length).toInt();
    history.insert(insertAt, Map<String, dynamic>.from(entry));
    if (history.length > 50) history.removeRange(50, history.length);
    await p.setString(_historyKey, jsonEncode(history));
    _historyChanges.add(null);
  }

  static Future<int> unreadCount() async {
    final history = await loadHistory();
    return history.where((e) => e['read'] != true).length;
  }

  // ── Daily notification cap (max 1 per day) ──

  static const _dailyDateKey = 'notif_daily_date';

  static Future<bool> canFireToday() async {
    final p = await SharedPreferences.getInstance();
    final today = _todayString();
    final storedDate = p.getString(_dailyDateKey) ?? '';
    return storedDate != today;
  }

  static Future<void> recordFired() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_dailyDateKey, _todayString());
    await p.setString(_lastTimestampKey, DateTime.now().toIso8601String());
  }

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ── 20-hour gap enforcement ──

  static const _lastTimestampKey = 'notif_last_timestamp';

  static Future<bool> hasMinGap({
    Duration minGap = const Duration(hours: 20),
  }) async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_lastTimestampKey);
    if (s == null) return true;
    final last = DateTime.tryParse(s);
    if (last == null) return true;
    return DateTime.now().difference(last) >= minGap;
  }

  // ── Last fired metadata ──

  static const _lastTypeKey = 'notif_last_type';

  static Future<void> setLastFiredType(String type) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_lastTypeKey, type);
  }

  static Future<String?> lastFiredType() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_lastTypeKey);
  }

  static Future<DateTime?> lastFiredTimestamp() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_lastTimestampKey);
    return s != null ? DateTime.tryParse(s) : null;
  }

  // ── Per-type last-fired timestamps ──

  static const _lastFiredPrefix = 'notif_last_fired_';

  static Future<DateTime?> lastFired(String type) async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('$_lastFiredPrefix$type');
    return s != null ? DateTime.tryParse(s) : null;
  }

  static Future<void> setLastFired(String type) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      '$_lastFiredPrefix$type',
      DateTime.now().toIso8601String(),
    );
  }

  static Future<bool> canFireType(
    String type, {
    Duration minInterval = const Duration(days: 6),
  }) async {
    final last = await lastFired(type);
    if (last == null) return true;
    return DateTime.now().difference(last) >= minInterval;
  }

  // ── Run status diagnostics ──

  static const _lastRunKey = 'digest_last_run';

  static Future<void> saveLastRunStatus(String status) async {
    final p = await SharedPreferences.getInstance();
    final stamp = DateTime.now().toIso8601String();
    await p.setString(_lastRunKey, '$stamp | $status');
  }

  static Future<String?> loadLastRunStatus() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_lastRunKey);
  }
}
