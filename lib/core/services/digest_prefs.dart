import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persisted payload for the digest notification and [DigestScreen].
class DigestPrefs {
  DigestPrefs._();

  static const _lastKey = 'digest_last_json';
  static const digestEnabledKey = 'digest_enabled';
  static const digestDayKey = 'digest_day';
  static const digestHourKey = 'digest_hour';
  static const digestMinuteKey = 'digest_minute';

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
}
