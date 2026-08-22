import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

export 'usage_limits.dart';

import 'ai_quota_service.dart';
import 'usage_limits.dart';

/// Thrown when the active plan hits its usage ceiling for a feature.
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
    return "You've reached your usage limit for $label.";
  }
}

/// Independent usage-tracking service.
///
/// Persists counters locally in [SharedPreferences]. Free AI saves are a
/// lifetime allowance; monthly counters reset at the start of each UTC month.
/// Pro AI saves use their own monthly counter, while Pro Ask and search remain
/// protected by the gateway's fair-use rate limits rather than product quotas.
///
/// When an [AiQuotaService] is supplied, server-metered features (see
/// [AiQuotaService.serverFeature]) are gated by the worker's plan quota
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
  static const String _deviceScopeMigrationPrefix =
      '${_prefix}device_scope_v3_';
  static const String _proAiSaveCountKey = '${_prefix}pro_aiSave$_countSuffix';

  String _countKey(UsageFeature feature, {required bool isPro}) {
    if (isPro && feature == UsageFeature.aiSave) return _proAiSaveCountKey;
    return '$_prefix${feature.name}$_countSuffix';
  }

  String _deviceScopeMigrationKey(UsageFeature feature, bool isPro) =>
      '$_deviceScopeMigrationPrefix${isPro ? 'pro' : 'free'}_${feature.name}';

  bool _isProductMetered(UsageFeature feature, bool isPro) =>
      !isPro || feature == UsageFeature.aiSave;

  /// Server feature key for [feature] when server metering is active, else null.
  String? _serverFeature(UsageFeature feature) =>
      _aiQuota == null ? null : AiQuotaService.serverFeature(feature);

  /// Overwrites the local mirror so badges reflect the server's [value].
  Future<void> _setLocalCount(
    UsageFeature feature,
    int value, {
    required bool isPro,
  }) async {
    await resetUsageIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_countKey(feature, isPro: isPro), value);
  }

  Future<int?> _migrationUsage(UsageFeature feature, bool isPro) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_deviceScopeMigrationKey(feature, isPro)) ?? false) {
      return null;
    }
    // The old unscoped counter represented the free allowance. A newly capped
    // Pro plan starts its own monthly counter at zero instead of inheriting it.
    if (isPro) return 0;
    return getUsage(feature, isPro: false);
  }

  Future<void> _markDeviceScopeMigrated(
    UsageFeature feature,
    bool isPro,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_deviceScopeMigrationKey(feature, isPro), true);
  }

  /// Checks whether the stored counters belong to the previous month and,
  /// if so, resets monthly counters and bumps the reset timestamp.
  /// The free AI-save counter is deliberately retained for life.
  Future<void> resetUsageIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResetStr = prefs.getString(_lastResetKey);
    final now = DateTime.now().toUtc();

    if (lastResetStr == null) {
      await prefs.setString(_lastResetKey, now.toIso8601String());
      return;
    }

    final lastReset = DateTime.tryParse(lastResetStr)?.toUtc();
    if (lastReset == null) {
      await prefs.setString(_lastResetKey, now.toIso8601String());
      return;
    }

    if (lastReset.year != now.year || lastReset.month != now.month) {
      await prefs.remove(_countKey(UsageFeature.ask, isPro: false));
      await prefs.remove(_countKey(UsageFeature.search, isPro: false));
      await prefs.remove(_proAiSaveCountKey);
      await prefs.setString(_lastResetKey, now.toIso8601String());
      developer.log(
        'Usage counters reset for new month (${now.year}-${now.month.toString().padLeft(2, '0')})',
        name: 'UsageService',
      );
    }
  }

  /// Current count for [feature] in the active plan window.
  Future<int> getUsage(UsageFeature feature, {bool isPro = false}) async {
    await resetUsageIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_countKey(feature, isPro: isPro)) ?? 0;
  }

  /// Increments [feature] by one (resets automatically on month boundary).
  ///
  /// For server-metered features this consumes one unit of the worker's plan
  /// device quota and mirrors the authoritative count locally. Best-effort: the
  /// AI work has already happened by the time this is called, so a consume
  /// failure falls back to a local increment rather than blocking the completed
  /// save.
  Future<void> incrementUsage(
    UsageFeature feature, {
    required bool isPro,
  }) async {
    if (!_isProductMetered(feature, isPro)) return;
    final serverFeature = _serverFeature(feature);
    if (serverFeature != null) {
      try {
        final migrationUsed = await _migrationUsage(feature, isPro);
        final snap = await _aiQuota!.consume(
          serverFeature,
          migrationUsed: migrationUsed,
        );
        if (snap.enforced) {
          await _setLocalCount(feature, snap.used, isPro: isPro);
          await _markDeviceScopeMigrated(feature, isPro);
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
    final key = _countKey(feature, isPro: isPro);
    final current = prefs.getInt(key) ?? 0;
    final next = current + 1;
    await prefs.setInt(key, next);
    developer.log(
      '${feature.name} usage incremented: $next / '
      '${UsageLimits.getLimit(feature, isPro: isPro)}',
      name: 'UsageService',
    );
  }

  /// Whether the active plan has consumed the feature allowance.
  ///
  /// For server-metered features this consults the worker's authoritative count
  /// (and heals the local mirror), falling back to the local counter only when
  /// the worker is unreachable.
  Future<bool> hasReachedLimit(UsageFeature feature, bool isPro) async {
    if (!_isProductMetered(feature, isPro)) return false;
    final serverFeature = _serverFeature(feature);
    if (serverFeature != null) {
      try {
        final migrationUsed = await _migrationUsage(feature, isPro);
        final snap = await _aiQuota!.peek(
          serverFeature,
          migrationUsed: migrationUsed,
        );
        if (snap.enforced) {
          await _setLocalCount(feature, snap.used, isPro: isPro);
          await _markDeviceScopeMigrated(feature, isPro);
          return snap.reached;
        }
      } catch (e) {
        developer.log(
          'Quota peek failed for ${feature.name}, using local counter: $e',
          name: 'UsageService',
        );
      }
    }
    final usage = await getUsage(feature, isPro: isPro);
    return usage >= UsageLimits.getLimit(feature, isPro: isPro);
  }

  /// Fast local-only limit snapshot for latency-sensitive acknowledgements.
  ///
  /// This never contacts the worker. The enrichment path must still call
  /// [hasReachedLimit] before doing paid work so the server remains the source
  /// of truth. Save surfaces use this mirror only to avoid holding the user's
  /// completed local save behind a quota network round trip.
  Future<bool> hasReachedLocalLimit(UsageFeature feature, bool isPro) async {
    if (!_isProductMetered(feature, isPro)) return false;
    final usage = await getUsage(feature, isPro: isPro);
    return usage >= UsageLimits.getLimit(feature, isPro: isPro);
  }

  /// Remaining uses for the active plan window.
  Future<int> getRemaining(UsageFeature feature, bool isPro) async {
    if (!_isProductMetered(feature, isPro)) return 9999;
    final serverFeature = _serverFeature(feature);
    if (serverFeature != null) {
      try {
        final migrationUsed = await _migrationUsage(feature, isPro);
        final snap = await _aiQuota!.peek(
          serverFeature,
          migrationUsed: migrationUsed,
        );
        if (snap.enforced) {
          await _setLocalCount(feature, snap.used, isPro: isPro);
          await _markDeviceScopeMigrated(feature, isPro);
          return snap.remaining.clamp(0, snap.limit);
        }
      } catch (e) {
        developer.log(
          'Quota peek failed for ${feature.name}, using local remaining: $e',
          name: 'UsageService',
        );
      }
    }
    final usage = await getUsage(feature, isPro: isPro);
    final limit = UsageLimits.getLimit(feature, isPro: isPro);
    return (limit - usage).clamp(0, limit);
  }

  /// Hard-reset every counter (dev-only).
  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final feature in UsageFeature.values) {
      await prefs.remove(_countKey(feature, isPro: false));
      await prefs.remove(_deviceScopeMigrationKey(feature, false));
      await prefs.remove(_deviceScopeMigrationKey(feature, true));
    }
    await prefs.remove(_proAiSaveCountKey);
    await prefs.setString(
      _lastResetKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    developer.log('All usage counters manually reset', name: 'UsageService');
  }

  /// The hard limit for [feature].
  static int limitFor(UsageFeature feature, {bool isPro = false}) =>
      UsageLimits.getLimit(feature, isPro: isPro);

  /// Whether the current usage count is at or above the soft-warning
  /// threshold (≥ 80 % of limit).
  Future<bool> isNearLimit(UsageFeature feature, bool isPro) async {
    if (!_isProductMetered(feature, isPro)) return false;
    final serverFeature = _serverFeature(feature);
    if (serverFeature != null) {
      try {
        final migrationUsed = await _migrationUsage(feature, isPro);
        final snap = await _aiQuota!.peek(
          serverFeature,
          migrationUsed: migrationUsed,
        );
        if (snap.enforced) {
          await _setLocalCount(feature, snap.used, isPro: isPro);
          await _markDeviceScopeMigrated(feature, isPro);
          if (snap.limit == 0) return false;
          return snap.used >= (snap.limit * 0.8).ceil();
        }
      } catch (e) {
        developer.log(
          'Quota peek failed for ${feature.name}, using local near-limit: $e',
          name: 'UsageService',
        );
      }
    }
    final usage = await getUsage(feature, isPro: isPro);
    final limit = UsageLimits.getLimit(feature, isPro: isPro);
    if (limit == 0) return false;
    return usage >= (limit * 0.8).ceil();
  }
}
