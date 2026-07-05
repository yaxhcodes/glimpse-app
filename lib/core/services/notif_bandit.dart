import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// On-device contextual bandit that learns which notification *types* this
/// user actually opens, and ranks future candidates accordingly.
///
/// Each type is an arm with a Beta(opens+1, ignored+1) belief. We Thompson-
/// sample one value per eligible arm and rank by the samples: arms the user
/// opens earn higher beliefs (exploit), while rarely-tried arms keep wide
/// distributions and still get their turn (explore). The randomness also keeps
/// the daily pick from feeling mechanical.
///
/// Pure on-device — stats live in SharedPreferences and never leave the device.
class NotifBandit {
  NotifBandit._();

  static const _statsKey = 'notif_bandit_stats_v2';
  static const _legacyStatsKey = 'notif_bandit_stats_v1';
  static const _rewardedIdsKey = 'notif_bandit_rewarded_ids_v1';
  static const _rewardedIdsCap = 200;

  /// Above this many sends for an arm, halve its counts so recent behaviour
  /// dominates (tastes drift). Keeps beliefs bounded and adaptive.
  static const _decayCap = 40.0;
  static const _decayFactor = 0.5;

  static final Random _defaultRng = Random();

  /// Record that a notification of [type] (scheduler letter A–G) was sent.
  static Future<void> recordSend(String type) =>
      _bump(type, opened: false);

  /// Record that a notification of [type] was opened — the positive reward.
  static Future<void> recordOpen(String type) => _bump(type, opened: true);

  /// Reward [type] at most once per [notifId]: the same notification can be
  /// tapped in the tray and then re-opened from the hub history any number of
  /// times, but only the first engagement counts. Repeat-counting is what
  /// inflated open rates past 100% and froze the ranking. Returns true when
  /// the reward was actually counted.
  static Future<bool> recordOpenOnce(String type, String? notifId) async {
    if (notifId == null || notifId.isEmpty) {
      // Legacy payload without an id — can't dedupe, count it.
      await recordOpen(type);
      return true;
    }
    final p = await SharedPreferences.getInstance();
    final ids = p.getStringList(_rewardedIdsKey) ?? const <String>[];
    if (ids.contains(notifId)) return false;
    final next = [...ids, notifId];
    if (next.length > _rewardedIdsCap) {
      next.removeRange(0, next.length - _rewardedIdsCap);
    }
    await p.setStringList(_rewardedIdsKey, next);
    await recordOpen(type);
    return true;
  }

  /// Rank [eligibleTypes] best-first by a Thompson sample of each arm's belief.
  /// [rng] is injectable for deterministic tests.
  static Future<List<String>> rank(
    List<String> eligibleTypes, {
    Random? rng,
  }) async {
    if (eligibleTypes.length <= 1) return List.of(eligibleTypes);
    final stats = await _load();
    final r = rng ?? _defaultRng;
    final scored = <MapEntry<String, double>>[];
    for (final t in eligibleTypes) {
      final s = stats[t] ?? const _Arm(0, 0);
      // Beta(opens+1, ignored+1); both shape params are >= 1.
      final ignored = (s.sends - s.opens).clamp(0.0, double.infinity);
      final theta = _betaSample(s.opens + 1.0, ignored + 1.0, r);
      scored.add(MapEntry(t, theta));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  /// Open-rate estimate per type (for diagnostics / settings display).
  static Future<Map<String, double>> openRates() async {
    final stats = await _load();
    return {
      for (final e in stats.entries)
        if (e.value.sends > 0)
          e.key: (e.value.opens / e.value.sends).clamp(0.0, 1.0),
    };
  }

  // ── persistence ──────────────────────────────────────────────────────────

  static Future<void> _bump(String type, {required bool opened}) async {
    final p = await SharedPreferences.getInstance();
    final stats = await _load();
    var arm = stats[type] ?? const _Arm(0, 0);
    // Decay before incrementing so a long-running arm stays adaptive.
    if (arm.sends >= _decayCap) {
      arm = _Arm(arm.opens * _decayFactor, arm.sends * _decayFactor);
    }
    stats[type] = _Arm(
      arm.opens + (opened ? 1.0 : 0.0),
      arm.sends + (opened ? 0.0 : 1.0),
    );
    await p.setString(_statsKey, _encode(stats));
  }

  static Future<Map<String, _Arm>> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_statsKey);
    if (raw != null) return _decode(raw);
    // One-time migration: v1 counted every re-open (hub history taps) as a new
    // reward, so opens could exceed sends and lock an arm's belief near 1.
    // Clamp opens to sends on the way in, keep the send history.
    final legacy = p.getString(_legacyStatsKey);
    if (legacy == null) return {};
    final clamped = {
      for (final e in _decode(legacy).entries)
        e.key: _Arm(min(e.value.opens, e.value.sends), e.value.sends),
    };
    await p.setString(_statsKey, _encode(clamped));
    await p.remove(_legacyStatsKey);
    return clamped;
  }

  static Map<String, _Arm> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) {
        final m = v as Map<String, dynamic>;
        return MapEntry(
          k,
          _Arm((m['o'] as num).toDouble(), (m['s'] as num).toDouble()),
        );
      });
    } catch (_) {
      return {};
    }
  }

  static String _encode(Map<String, _Arm> stats) => jsonEncode(
        stats.map((k, v) => MapEntry(k, {'o': v.opens, 's': v.sends})),
      );

  // ── sampling ───────────────────────────────────────────────────────────────

  /// Beta(a, b) via two Gamma draws: X/(X+Y), X~Gamma(a), Y~Gamma(b).
  static double _betaSample(double a, double b, Random rng) {
    final x = _gammaSample(a, rng);
    final y = _gammaSample(b, rng);
    final denom = x + y;
    return denom <= 0 ? 0.5 : x / denom;
  }

  /// Marsaglia–Tsang Gamma sampler (shape k >= 1; our shapes always are).
  static double _gammaSample(double k, Random rng) {
    final d = k - 1.0 / 3.0;
    final c = 1.0 / sqrt(9.0 * d);
    while (true) {
      double x, v;
      do {
        x = _gaussian(rng);
        v = 1.0 + c * x;
      } while (v <= 0);
      v = v * v * v;
      final u = rng.nextDouble();
      if (u < 1.0 - 0.0331 * x * x * x * x) return d * v;
      if (log(u) < 0.5 * x * x + d * (1.0 - v + log(v))) return d * v;
    }
  }

  static double _gaussian(Random rng) {
    final u1 = rng.nextDouble();
    final u2 = rng.nextDouble();
    return sqrt(-2.0 * log(u1 <= 0 ? 1e-12 : u1)) * cos(2 * pi * u2);
  }
}

/// Beta belief for one arm: [opens] successes out of [sends] trials.
class _Arm {
  const _Arm(this.opens, this.sends);
  final double opens;
  final double sends;
}
