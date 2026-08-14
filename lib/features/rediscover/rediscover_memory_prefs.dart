import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RediscoverMemoryPrefs {
  RediscoverMemoryPrefs._();

  static const _relatedPrefix = 'rediscover_related_for_';
  static const _pairPrefix = 'rediscover_related_pair_';
  static const _recapPrefix = 'rediscover_recap_seen_';
  static const _dailySetPrefix = 'rediscover_daily_set_';
  static const _memorySnoozePrefix = 'rediscover_memory_snoozed_';
  static const _topicSuppressionPrefix = 'rediscover_topic_suppressed_';
  static const _memoryShownPrefix = 'rediscover_memory_shown_';
  static const _memoryOpenedPrefix = 'rediscover_memory_opened_';
  static const _memoryLastShownPrefix = 'rediscover_memory_last_shown_';
  static const _topicLastShownPrefix = 'rediscover_topic_last_shown_';
  static const _dailyGeneratedPrefix = 'rediscover_daily_generated_';
  static const _dailyInteractedPrefix = 'rediscover_daily_interacted_';
  static const _topicPulsesKey = 'rediscover_topic_pulses_v1';
  static const _cooldown = Duration(days: 14);

  static Future<void> saveRelatedSaves({
    required int sourceId,
    required List<int> relatedIds,
  }) async {
    if (relatedIds.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final accepted = <int>[];
    for (final id in relatedIds) {
      final pairKey = _pairKey(sourceId, id);
      final raw = prefs.getString(pairKey);
      final last = raw == null ? null : DateTime.tryParse(raw);
      if (last != null && now.difference(last) < _cooldown) continue;
      accepted.add(id);
      await prefs.setString(pairKey, now.toIso8601String());
    }
    if (accepted.isEmpty) return;
    await prefs.setString(
      '$_relatedPrefix$sourceId',
      jsonEncode({
        'sourceId': sourceId,
        'relatedIds': accepted,
        'createdAt': now.toIso8601String(),
      }),
    );
  }

  static Future<List<int>> relatedSavesFor(int sourceId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_relatedPrefix$sourceId');
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];
      final createdAt = DateTime.tryParse(
        decoded['createdAt']?.toString() ?? '',
      );
      if (createdAt == null ||
          DateTime.now().difference(createdAt) > _cooldown) {
        return const [];
      }
      final ids = decoded['relatedIds'];
      if (ids is! List) return const [];
      return ids.whereType<num>().map((id) => id.toInt()).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> canShowRecap({
    required String cadence,
    required List<int> itemIds,
  }) async {
    if (itemIds.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_recapPrefix$cadence');
    if (raw == null) return true;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return true;
      final lastSignature = decoded['signature']?.toString();
      final seenAt = DateTime.tryParse(decoded['seenAt']?.toString() ?? '');
      if (seenAt == null) return true;
      if (lastSignature != _recapSignature(itemIds)) return true;
      return DateTime.now().difference(seenAt) >= _recapCooldown(cadence);
    } catch (_) {
      return true;
    }
  }

  static Future<void> markRecapSeen({
    required String cadence,
    required List<int> itemIds,
  }) async {
    if (itemIds.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_recapPrefix$cadence',
      jsonEncode({
        'signature': _recapSignature(itemIds),
        'seenAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  static Future<List<Map<String, Object?>>> loadDailySet(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_dailySetPrefix$dateKey');
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (entry) =>
                entry.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> hasDailySet(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_dailySetPrefix$dateKey');
  }

  static Future<void> saveDailySet(
    String dateKey,
    List<Map<String, Object?>> memories, {
    DateTime? generatedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_dailySetPrefix$dateKey', jsonEncode(memories));
    if (generatedAt != null) {
      await prefs.setString(
        '$_dailyGeneratedPrefix$dateKey',
        generatedAt.toIso8601String(),
      );
    }
    await _pruneDatedKeys(
      prefs,
      prefix: _dailySetPrefix,
      currentDateKey: dateKey,
      retention: const Duration(days: 14),
    );
    await _pruneDatedKeys(
      prefs,
      prefix: _memoryShownPrefix,
      currentDateKey: dateKey,
      retention: const Duration(days: 14),
    );
    await _pruneDatedKeys(
      prefs,
      prefix: _dailyGeneratedPrefix,
      currentDateKey: dateKey,
      retention: const Duration(days: 14),
    );
    await _pruneDatedKeys(
      prefs,
      prefix: _dailyInteractedPrefix,
      currentDateKey: dateKey,
      retention: const Duration(days: 14),
    );
  }

  static Future<DateTime?> dailySetGeneratedAt(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    return DateTime.tryParse(
      prefs.getString('$_dailyGeneratedPrefix$dateKey') ?? '',
    );
  }

  static Future<void> markDailySetInteracted(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_dailyInteractedPrefix$dateKey',
      DateTime.now().toIso8601String(),
    );
  }

  static Future<bool> hasDailySetInteraction(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_dailyInteractedPrefix$dateKey');
  }

  static Future<void> snoozeMemory(String memoryId, {DateTime? until}) async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAt = until ?? DateTime.now().add(const Duration(days: 7));
    await prefs.setString(
      '$_memorySnoozePrefix${_encoded(memoryId)}',
      expiresAt.toIso8601String(),
    );
  }

  static Future<bool> isMemorySnoozed(String memoryId, {DateTime? now}) async {
    return _hasActiveExpiry(
      '$_memorySnoozePrefix${_encoded(memoryId)}',
      now: now,
    );
  }

  static Future<void> suppressTopic(String topicKey, {DateTime? until}) async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAt = until ?? DateTime.now().add(const Duration(days: 14));
    await prefs.setString(
      '$_topicSuppressionPrefix${_encoded(_normalizeTopic(topicKey))}',
      expiresAt.toIso8601String(),
    );
  }

  static Future<bool> isTopicSuppressed(
    String topicKey, {
    DateTime? now,
  }) async {
    return _hasActiveExpiry(
      '$_topicSuppressionPrefix${_encoded(_normalizeTopic(topicKey))}',
      now: now,
    );
  }

  static Future<bool> markMemoryShownOnce({
    required String memoryId,
    required String dateKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_memoryShownPrefix$dateKey-${_encoded(memoryId)}';
    if (prefs.getBool(key) == true) return false;
    await prefs.setBool(key, true);
    await prefs.setString(
      '$_memoryLastShownPrefix${_encoded(memoryId)}',
      DateTime.now().toIso8601String(),
    );
    return true;
  }

  static Future<void> markTopicShown(String topicKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_topicLastShownPrefix${_encoded(_normalizeTopic(topicKey))}',
      DateTime.now().toIso8601String(),
    );
  }

  static Future<void> markMemoryOpened(String memoryId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_memoryOpenedPrefix${_encoded(memoryId)}',
      DateTime.now().toIso8601String(),
    );
  }

  static Future<bool> wasMemoryShownRecently(
    String memoryId, {
    DateTime? now,
    Duration cooldown = const Duration(days: 7),
  }) async {
    return _isRecentTimestamp(
      '$_memoryLastShownPrefix${_encoded(memoryId)}',
      now: now,
      cooldown: cooldown,
    );
  }

  static Future<bool> wasMemoryOpenedRecently(
    String memoryId, {
    DateTime? now,
    Duration cooldown = const Duration(days: 14),
  }) async {
    return _isRecentTimestamp(
      '$_memoryOpenedPrefix${_encoded(memoryId)}',
      now: now,
      cooldown: cooldown,
    );
  }

  static Future<bool> wasTopicShownRecently(
    String topicKey, {
    DateTime? now,
    Duration cooldown = const Duration(days: 3),
  }) async {
    return _isRecentTimestamp(
      '$_topicLastShownPrefix${_encoded(_normalizeTopic(topicKey))}',
      now: now,
      cooldown: cooldown,
    );
  }

  static Future<double> topicFatigueMultiplier(
    String topicKey, {
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      '$_topicLastShownPrefix${_encoded(_normalizeTopic(topicKey))}',
    );
    final shownAt = DateTime.tryParse(raw ?? '');
    if (shownAt == null) return 1;
    final age = (now ?? DateTime.now()).difference(shownAt);
    if (age.isNegative || age >= const Duration(days: 14)) return 1;
    if (age < const Duration(days: 3)) return 0;
    final recovered =
        (age.inHours - const Duration(days: 3).inHours) /
        (const Duration(days: 11).inHours);
    return (0.45 + recovered * 0.55).clamp(0.45, 1.0);
  }

  static Future<List<Map<String, Object?>>> loadTopicPulses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_topicPulsesKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (entry) =>
                entry.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList();
    } catch (_) {
      await prefs.remove(_topicPulsesKey);
      return const [];
    }
  }

  static Future<void> replaceTopicPulses(
    List<Map<String, Object?>> pulses,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _topicPulsesKey,
      jsonEncode(pulses.take(24).toList()),
    );
  }

  static Future<void> upsertTopicPulse(Map<String, Object?> pulse) async {
    final records = await loadTopicPulses();
    final id = pulse['id']?.toString();
    final now = DateTime.now();
    final kept = records.where((record) {
      if (record['id']?.toString() == id) return false;
      final detectedAt = DateTime.tryParse(
        record['detectedAt']?.toString() ?? '',
      );
      return detectedAt != null &&
          now.difference(detectedAt) <= const Duration(days: 30);
    });
    await replaceTopicPulses([pulse, ...kept]);
  }

  static Future<bool> _hasActiveExpiry(String key, {DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return false;
    final expiry = DateTime.tryParse(raw);
    if (expiry == null) {
      await prefs.remove(key);
      return false;
    }
    if (!expiry.isAfter(now ?? DateTime.now())) {
      await prefs.remove(key);
      return false;
    }
    return true;
  }

  static Future<bool> _isRecentTimestamp(
    String key, {
    required Duration cooldown,
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return false;
    final timestamp = DateTime.tryParse(raw);
    if (timestamp == null) {
      await prefs.remove(key);
      return false;
    }
    final age = (now ?? DateTime.now()).difference(timestamp);
    return !age.isNegative && age < cooldown;
  }

  static String _encoded(String value) {
    return base64Url.encode(utf8.encode(value)).replaceAll('=', '');
  }

  static String _normalizeTopic(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static Future<void> _pruneDatedKeys(
    SharedPreferences prefs, {
    required String prefix,
    required String currentDateKey,
    required Duration retention,
  }) async {
    final currentDate = DateTime.tryParse(currentDateKey);
    if (currentDate == null) return;
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final suffix = key.substring(prefix.length);
      if (suffix.length < 10) continue;
      final date = DateTime.tryParse(suffix.substring(0, 10));
      if (date == null || currentDate.difference(date) <= retention) continue;
      await prefs.remove(key);
    }
  }

  static String _pairKey(int a, int b) {
    final first = a < b ? a : b;
    final second = a < b ? b : a;
    return '$_pairPrefix${first}_$second';
  }

  static String _recapSignature(List<int> ids) {
    final sorted = [...ids]..sort();
    return sorted.join('-');
  }

  static Duration _recapCooldown(String cadence) {
    return switch (cadence) {
      'daily' => const Duration(hours: 20),
      'weekly' => const Duration(days: 6),
      'monthly' => const Duration(days: 26),
      _ => const Duration(days: 1),
    };
  }
}
