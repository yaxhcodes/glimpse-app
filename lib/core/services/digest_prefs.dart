import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persisted payload for digest notifications and the notifications screen.
class DigestPrefs {
  DigestPrefs._();

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

  // ── Digest history (list of past digests for the notifications screen) ──

  static Future<void> addDigestToHistory({
    required List<int> ids,
    required List<String> summaries,
    required String topic,
  }) async {
    final p = await SharedPreferences.getInstance();
    final history = await loadHistory();
    history.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'date': DateTime.now().toIso8601String(),
      'ids': ids,
      'summaries': summaries,
      'topic': topic,
      'read': false,
    });
    // Keep the last 50 digests.
    if (history.length > 50) history.removeRange(50, history.length);
    await p.setString(_historyKey, jsonEncode(history));
  }

  static Future<List<Map<String, dynamic>>> loadHistory() async {
    final p = await SharedPreferences.getInstance();
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
  }

  static Future<void> deleteDigest(String digestId) async {
    final p = await SharedPreferences.getInstance();
    final history = await loadHistory();
    history.removeWhere((e) => e['id'] == digestId);
    await p.setString(_historyKey, jsonEncode(history));
  }

  static Future<int> unreadCount() async {
    final history = await loadHistory();
    return history.where((e) => e['read'] != true).length;
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
