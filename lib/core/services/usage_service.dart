import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

export 'usage_limits.dart';

import 'ai_quota_service.dart';
import 'usage_limits.dart';

/// Thrown when a free user hits the monthly usage ceiling for a feature.
class UsageLimitReachedException implements Exception {
  final UsageFeature feature;

  const UsageLimitReachedException(this.feature);

  @override
  String toString() {
    final label = switch (feature) {
      UsageFeature.aiSave => 'AI saves',
      UsageFeature.ask => 'Ask Glimpse queries',
      UsageFeature.search => 'searches',
    };
    return "You've reached your monthly limit for $label.";
  }
}

/// Independent usage-tracking service.
///
/// Persists counters locally in [SharedPreferences] and automatically resets
/// them at the start of a new calendar month. Pro users bypass all limits.
///
/// When an [AiQuotaService] is supplied, server-metered features (see
/// [AiQuotaService.serverFeature]) are gated by the worker's monthly quota
/// instead of the local counter. The local counter is then kept only as a
/// self-healing mirror so badges stay accurate; the server is the source of
/// truth that survives reinstall. If the worker is unreachable the gate falls
/// back to the local counter — safe, because AI work also needs the worker, so
/// an unreachable worker means no cost is incurred either way.
class UsageService {
  UsageService({AiQuotaService? aiQuota}) : _aiQuota = aiQuota;

  final AiQuotaService? _aiQuota;

  static const String _prefix = 'usage_';
  static const String _countSuffix = '_count';
  static const String _lastResetKey = '${_prefix}last_reset';

  String _countKey(UsageFeature feature) =>
      '$_prefix${feature.name}$_countSuffix';

  /// Server feature key for [feature] when server metering is active, else null.
  String? _serverFeature(UsageFeature feature) =>
      _aiQuota == null ? null : AiQuotaService.serverFeature(feature);

  /// Overwrites the local mirror so badges reflect the server's [value].
  Future<void> _setLocalCount(UsageFeature feature, int value) async {
    await resetUsageIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_countKey(feature), value);
  }

  /// Checks whether the stored counters belong to the previous month and,
  /// if so, resets every counter to 0 and bumps the reset timestamp.
  Future<void> resetUsageIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResetStr = prefs.getString(_lastResetKey);
    final now = DateTime.now();

    if (lastResetStr == null) {
      await prefs.setString(_lastResetKey, now.toIso8601String());
      return;
    }

    final lastReset = DateTime.tryParse(lastResetStr);
    if (lastReset == null) {
      await prefs.setString(_lastResetKey, now.toIso8601String());
      return;
    }

    if (lastReset.year != now.year || lastReset.month != now.month) {
      for (final feature in UsageFeature.values) {
        await prefs.remove(_countKey(feature));
      }
      await prefs.setString(_lastResetKey, now.toIso8601String());
      developer.log(
        'Usage counters reset for new month (${now.year}-${now.month.toString().padLeft(2, '0')})',
        name: 'UsageService',
      );
    }
  }

  /// Current count for [feature] (resets automatically on month boundary).
  Future<int> getUsage(UsageFeature feature) async {
    await resetUsageIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_countKey(feature)) ?? 0;
  }

  /// Increments [feature] by one (resets automatically on month boundary).
  ///
  /// For server-metered features this consumes one unit of the worker's monthly
  /// quota and mirrors the authoritative count locally. Best-effort: the AI work
  /// has already happened by the time this is called, so a consume failure falls
  /// back to a local increment rather than blocking the completed save.
  Future<void> incrementUsage(UsageFeature feature) async {
    final serverFeature = _serverFeature(feature);
    if (serverFeature != null) {
      try {
        final snap = await _aiQuota!.consume(serverFeature);
        if (snap.enforced) {
          await _setLocalCount(feature, snap.used);
          developer.log(
            '${feature.name} consumed server-side: ${snap.used} / ${snap.limit}',
            name: 'UsageService',
          );
          return;
        }
      } catch (e) {
        developer.log(
          'Quota consume failed for ${feature.name}, using local counter: $e',
          name: 'UsageService',
        );
      }
    }

    await resetUsageIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_countKey(feature)) ?? 0;
    final next = current + 1;
    await prefs.setInt(_countKey(feature), next);
    developer.log(
      '${feature.name} usage incremented: $next / ${UsageLimits.getLimit(feature)}',
      name: 'UsageService',
    );
  }

  /// Whether the user has consumed the full monthly allowance.
  ///
  /// [isPro] is `true` → always returns `false` (unlimited).
  ///
  /// For server-metered features this consults the worker's authoritative count
  /// (and heals the local mirror), falling back to the local counter only when
  /// the worker is unreachable.
  Future<bool> hasReachedLimit(UsageFeature feature, bool isPro) async {
    if (isPro) return false;
    final serverFeature = _serverFeature(feature);
    if (serverFeature != null) {
      try {
        final snap = await _aiQuota!.peek(serverFeature);
        if (snap.enforced) {
          await _setLocalCount(feature, snap.used);
          return snap.reached;
        }
      } catch (e) {
        developer.log(
          'Quota peek failed for ${feature.name}, using local counter: $e',
          name: 'UsageService',
        );
      }
    }
    final usage = await getUsage(feature);
    return usage >= UsageLimits.getLimit(feature);
  }

  /// Remaining uses for the current month.
  ///
  /// [isPro] is `true` → returns a large sentinel (`9999`).
  Future<int> getRemaining(UsageFeature feature, bool isPro) async {
    if (isPro) return 9999;
    final usage = await getUsage(feature);
    final limit = UsageLimits.getLimit(feature);
    return (limit - usage).clamp(0, limit);
  }

  /// Hard-reset every counter (dev-only).
  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final feature in UsageFeature.values) {
      await prefs.remove(_countKey(feature));
    }
    await prefs.setString(_lastResetKey, DateTime.now().toIso8601String());
    developer.log('All usage counters manually reset', name: 'UsageService');
  }

  /// The hard limit for [feature].
  static int limitFor(UsageFeature feature) => UsageLimits.getLimit(feature);

  /// Whether the current usage count is at or above the soft-warning
  /// threshold (≥ 80 % of limit).
  Future<bool> isNearLimit(UsageFeature feature, bool isPro) async {
    if (isPro) return false;
    final usage = await getUsage(feature);
    final limit = UsageLimits.getLimit(feature);
    if (limit == 0) return false;
    return usage >= (limit * 0.8).ceil();
  }
}
