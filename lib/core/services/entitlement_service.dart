import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_environment.dart';
import 'subscription_service.dart';

/// Compile-time environment. Must match `--dart-define=ENV=...` and
/// [AppEnvironment] (same `String.fromEnvironment` value).
const String env = String.fromEnvironment('ENV', defaultValue: 'prod');

/// Centralized Pro access: RevenueCat tier, with an optional **dev-only**
/// local override stored under [devForceProKey].
///
/// **Priority:** if [AppEnvironment.allowsLocalProOverride] and the override is
/// on → Pro. Otherwise Pro iff [SubscriptionTier.premium] from
/// [subscriptionTierProvider].
///
/// Widgets should use [isProUserProvider] (reactive). Async code can read
/// [subscriptionTierProvider] + [devProOverrideProvider] and call
/// [isFeatureUnlocked] / [isProUser].
class EntitlementService {
  EntitlementService._();

  static const String devForceProKey = 'dev_force_pro';
  static const String _effectiveProSnapshotKey =
      'glimpse_effective_pro_snapshot_v1';

  /// Effective Pro access: dev override, else RevenueCat tier.
  ///
  /// Local Pro override is allowed only in a dev *context* — see
  /// [AppEnvironment.allowsLocalProOverride] (Android `…glimpse.dev` and/or
  /// `ENV=dev`). The Play `com.shinrinyoku.glimpse` install never qualifies.
  static bool isProUser(
    SubscriptionTier revenueCatTier, {
    bool devProOverride = false,
  }) {
    if (AppEnvironment.allowsLocalProOverride && devProOverride) return true;
    return revenueCatTier == SubscriptionTier.premium;
  }

  static bool isFeatureUnlocked(
    PremiumFeature feature, {
    required SubscriptionTier revenueCatTier,
    bool devProOverride = false,
  }) {
    final t = isProUser(revenueCatTier, devProOverride: devProOverride)
        ? SubscriptionTier.premium
        : revenueCatTier;
    return SubscriptionService.isAvailable(feature, t);
  }

  static Future<bool> getDevProOverride() async {
    if (!AppEnvironment.allowsLocalProOverride) return false;
    final p = await SharedPreferences.getInstance();
    return p.getBool(devForceProKey) ?? false;
  }

  static Future<void> setDevProOverride(bool value) async {
    if (!AppEnvironment.allowsLocalProOverride) return;
    final p = await SharedPreferences.getInstance();
    await p.setBool(devForceProKey, value);
  }

  static Future<void> persistEffectiveProSnapshot(bool isPro) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_effectiveProSnapshotKey, isPro);
  }

  static Future<bool> loadEffectiveProSnapshot({bool fallback = false}) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    return preferences.getBool(_effectiveProSnapshotKey) ?? fallback;
  }
}

// ── Riverpod (reactive) ─────────────────────────────────────────────

/// Local dev-only Pro flag; always `false` in production.
final devProOverrideProvider =
    AsyncNotifierProvider<DevProOverrideNotifier, bool>(
      DevProOverrideNotifier.new,
    );

class DevProOverrideNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => EntitlementService.getDevProOverride();

  /// Persists and updates [state] so the UI and [isProUserProvider] refresh.
  Future<void> setDevProOverride(bool value) async {
    if (!AppEnvironment.allowsLocalProOverride) return;
    await EntitlementService.setDevProOverride(value);
    state = AsyncData(value);
  }
}

/// **Effective** Pro in the app (RevenueCat **or** local dev override when allowed).
final isProUserProvider = Provider<bool>((ref) {
  final devOn = ref.watch(devProOverrideProvider).valueOrNull ?? false;
  final tier =
      ref.watch(subscriptionTierProvider).valueOrNull ?? SubscriptionTier.free;
  return EntitlementService.isProUser(tier, devProOverride: devOn);
});

/// `true` with the local dev override on (for "DEV PRO MODE" strip).
final devProOverrideActiveProvider = Provider<bool>(
  (ref) =>
      AppEnvironment.allowsLocalProOverride &&
      (ref.watch(devProOverrideProvider).valueOrNull ?? false),
);
