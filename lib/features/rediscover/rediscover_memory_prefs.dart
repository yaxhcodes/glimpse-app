import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RediscoverMemoryPrefs {
  RediscoverMemoryPrefs._();

  static const _relatedPrefix = 'rediscover_related_for_';
  static const _pairPrefix = 'rediscover_related_pair_';
  static const _recapPrefix = 'rediscover_recap_seen_';
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
