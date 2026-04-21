import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_proxy_config.dart';

/// What the user has access to.
enum SubscriptionTier { free, premium }

/// Features that can be gated.
enum PremiumFeature {
  askChat,
  recap,
  synthesis,
  semanticSearch,
}

/// RevenueCat configuration — keys injected at build time via --dart-define.
///
///   --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx   (public SDK key from RC)
///   --dart-define=REVENUECAT_IOS_KEY=appl_xxx
///   --dart-define=REVENUECAT_ENTITLEMENT="Glimpse Pro"
///
/// IMPORTANT: [entitlementId] must match the RevenueCat dashboard entitlement
/// identifier **exactly** (case-sensitive, spaces preserved).
class RevenueCatConfig {
  RevenueCatConfig._();

  static const androidApiKey =
      String.fromEnvironment('REVENUECAT_ANDROID_KEY');
  static const iosApiKey = String.fromEnvironment('REVENUECAT_IOS_KEY');

  // Hardcoded, NOT read from --dart-define.
  //
  // WHY: passing `--dart-define=REVENUECAT_ENTITLEMENT="Glimpse Pro"` from
  // PowerShell can embed the literal quote characters into the compiled
  // string, so `info.entitlements.active.containsKey(entitlementId)` would
  // look for the key `"Glimpse Pro"` (with quotes) and silently miss the
  // real `Glimpse Pro` key. This identifier never changes per build, so
  // hardcoding it removes the entire class of quote/spacing bugs.
  static const String entitlementId = 'Glimpse Pro';

  static String? get platformApiKey {
    if (Platform.isAndroid) return androidApiKey.isEmpty ? null : androidApiKey;
    if (Platform.isIOS) return iosApiKey.isEmpty ? null : iosApiKey;
    return null;
  }

  static bool get hasPlatformKey => platformApiKey != null;
}

/// Stable identifier used as RevenueCat `appUserID`.
///
/// Preference order:
///   1. `--dart-define=AI_PROXY_USER_ID=...` — same id the AI proxy uses,
///      so purchases and backend calls share ONE identity.
///   2. Persisted per-install UUID in SharedPreferences — fallback.
class _AppUserId {
  static const _prefsKey = 'glimpse_rc_app_user_id';

  static Future<String> getOrCreate() async {
    final injected = AiProxyConfig.userId.trim();
    if (injected.isNotEmpty) return injected;

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefsKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _generate();
    await prefs.setString(_prefsKey, id);
    return id;
  }

  static String _generate() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}'
        '-${h.substring(16, 20)}-${h.substring(20)}';
  }
}

/// Thin wrapper around `Purchases.configure` + purchase/restore/paywall
/// entry points.
///
/// STATE LIVES IN [SubscriptionTierNotifier], NOT HERE.
///
/// WHY: previously this class owned a [StreamController] that the UI
/// indirectly listened to. That stream was never wired into Riverpod — the
/// update listener would `_tierController.add(tier)`, but the UI rebuilt
/// from the notifier's `state`, which only updated when the notifier
/// happened to listen to the stream. Missed events + extra layer of
/// indirection = "RC shows Pro, app shows Free". The listener now writes
/// directly to `state = AsyncData(tier)` on the notifier.
class SubscriptionService {
  SubscriptionService._();

  static final SubscriptionService instance = SubscriptionService._();

  static bool _configured = false;
  static Future<void>? _initInProgress;

  bool get isConfigured => _configured;

  /// Initialise the RevenueCat SDK. Call once at app startup from [main]
  /// **before** [runApp] and before any purchase. Never throws.
  static Future<void> init() async {
    if (_configured) return;
    if (_initInProgress != null) {
      await _initInProgress;
      return;
    }
    _initInProgress = _configure();
    try {
      await _initInProgress;
    } finally {
      _initInProgress = null;
    }
  }

  static Future<void> _configure() async {
    final key = RevenueCatConfig.platformApiKey;
    if (key == null) {
      developer.log(
        'RevenueCat: no platform key — running in free-only mode',
        name: 'Subscription',
      );
      return;
    }

    try {
      await Purchases.setLogLevel(
        kDebugMode ? LogLevel.debug : LogLevel.warn,
      );

      final appUserId = await _AppUserId.getOrCreate();
      final config = PurchasesConfiguration(key)..appUserID = appUserId;
      await Purchases.configure(config);

      _configured = true;

      final nativeConfigured = await Purchases.isConfigured;
      String? resolvedAppUserId;
      try {
        resolvedAppUserId = await Purchases.appUserID;
      } catch (_) {}
      developer.log(
        'RevenueCat: configured nativeIsConfigured=$nativeConfigured '
        'resolvedAppUserId=$resolvedAppUserId '
        'entitlementId="${RevenueCatConfig.entitlementId}"',
        name: 'Subscription',
      );
      // ignore: avoid_print
      print('[Subscription] configured appUserId=$resolvedAppUserId '
          'key=${_obfuscate(key)} entitlement="${RevenueCatConfig.entitlementId}"');

      // WHY no `addCustomerInfoUpdateListener` here:
      // the listener is now owned by `SubscriptionTierNotifier` so it can
      // write directly to `state = AsyncData(tier)` instead of bouncing
      // through a disconnected StreamController.
      //
      // WHY no `syncPurchases` / `invalidateCustomerInfoCache` here:
      // the spec requires those calls to happen ONLY inside
      // `refreshAfterPurchase()`. Startup must be cache-first.
    } catch (e, st) {
      developer.log(
        'RevenueCat: configure failed — $e',
        name: 'Subscription',
        stackTrace: st,
      );
      _configured = false;
    }
  }

  static String _obfuscate(String key) {
    if (key.length <= 6) return '***';
    return '${key.substring(0, 6)}…(${key.length} chars)';
  }

  static void _logCustomerInfo(String source, CustomerInfo info) {
    final activeIds = info.entitlements.active.keys.toList();
    final allIds = info.entitlements.all.keys.toList();
    final subs = info.activeSubscriptions;
    developer.log(
      'RevenueCat[$source]: activeEntitlements=$activeIds allEntitlements=$allIds '
      'activeSubscriptions=$subs '
      'lookingFor="${RevenueCatConfig.entitlementId}"',
      name: 'Subscription',
    );
    // ignore: avoid_print
    print('[Subscription] $source — entitlements.active=$activeIds '
        'activeSubscriptions=$subs '
        '(lookingFor="${RevenueCatConfig.entitlementId}")');
  }

  /// Derive the app tier from a [CustomerInfo]. Public so the notifier can
  /// use it both from its listener and from `refreshAfterPurchase`.
  ///
  /// Premium only when RC reports the entitlement in `active` — do not
  /// infer Pro from raw Play Billing states.
  /// Collapses any run of whitespace so `Glimpse  Pro` (dashboard typo /
  /// RC duplicate space) matches `Glimpse Pro` from our hardcoded constant.
  static String _normalizeEntitlementKey(String id) =>
      id.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  static SubscriptionTier tierFromInfo(CustomerInfo info) {
    final active = info.entitlements.active;
    final target = RevenueCatConfig.entitlementId;

    if (active.containsKey(target)) return SubscriptionTier.premium;

    // Defensive fallback — case drift, outer trim, AND internal whitespace:
    // logcat showed RevenueCat returning the key `Glimpse  Pro` (two spaces)
    // while the app compares `Glimpse Pro`. `trim()` alone cannot fix that.
    final targetNorm = _normalizeEntitlementKey(target);
    for (final entry in active.entries) {
      if (_normalizeEntitlementKey(entry.key) == targetNorm) {
        developer.log(
          'RevenueCat: entitlement id fuzzy match — '
          'dashboard="${entry.key}" (chars=${entry.key.codeUnits}) '
          'config="$target" (chars=${target.codeUnits}). '
          'Rename the entitlement in RevenueCat if possible so keys match '
          'exactly; fuzzy match prevented a silent free tier.',
          name: 'Subscription',
        );
        return SubscriptionTier.premium;
      }
    }
    return SubscriptionTier.free;
  }

  static Offering? _offeringWithPackages(Offerings offerings) {
    final current = offerings.current;
    if (current != null && current.availablePackages.isNotEmpty) {
      return current;
    }
    for (final off in offerings.all.values) {
      if (off.availablePackages.isNotEmpty) return off;
    }
    return null;
  }

  /// Prefer monthly → annual → weekly → first package.
  static Package? _preferredPackage(Offering offering) {
    final packages = offering.availablePackages;
    if (packages.isEmpty) return null;
    Package? pick(PackageType t) {
      for (final p in packages) {
        if (p.packageType == t) return p;
      }
      return null;
    }
    return pick(PackageType.monthly) ??
        pick(PackageType.annual) ??
        pick(PackageType.weekly) ??
        packages.first;
  }

  /// Run a native RevenueCat purchase.
  ///
  /// Returns `true` when the Play Billing transaction succeeded (or the
  /// user was already entitled). Returns `false` for cancellation or a
  /// genuine failure.
  ///
  /// WHY this method no longer pokes at caches, streams, or polls:
  /// that logic belongs to `SubscriptionTierNotifier.refreshAfterPurchase()`.
  /// The UI calls this, then calls `refreshAfterPurchase()`, and Riverpod
  /// state flips to Pro.
  Future<bool> purchaseRecommendedPackage() async {
    if (!_configured) return false;
    try {
      final offerings = await Purchases.getOfferings();
      final curId = offerings.current?.identifier ?? 'null';
      final pkgIds = offerings.current?.availablePackages
              .map((p) => p.identifier)
              .toList() ??
          const <String>[];
      developer.log(
        'RevenueCat: offerings current="$curId" packageIds=$pkgIds '
        'allOfferingKeys=${offerings.all.keys.toList()}',
        name: 'Subscription',
      );
      // ignore: avoid_print
      print('[Subscription] offerings current="$curId" packageIds=$pkgIds');

      final offering = _offeringWithPackages(offerings);
      if (offering == null) {
        developer.log(
          'RevenueCat: no offering with packages — link products in RC & set a current offering',
          name: 'Subscription',
        );
        return false;
      }

      final pkg = _preferredPackage(offering);
      if (pkg == null) return false;

      developer.log(
        'RevenueCat: Purchases.purchase start offering=${offering.identifier} '
        'package=${pkg.identifier} storeProduct=${pkg.storeProduct.identifier}',
        name: 'Subscription',
      );
      // ignore: avoid_print
      print('[Subscription] Purchases.purchase → package=${pkg.identifier} '
          'product=${pkg.storeProduct.identifier}');

      final result = await Purchases.purchase(PurchaseParams.package(pkg));

      final tx = result.storeTransaction;
      developer.log(
        'RevenueCat: purchase success transactionId=${tx.transactionIdentifier} '
        'product=${tx.productIdentifier} date=${tx.purchaseDate}',
        name: 'Subscription',
      );
      _logCustomerInfo('afterPurchase', result.customerInfo);
      return true;
    } on PlatformException catch (e, st) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      developer.log(
        'RevenueCat: purchase PlatformException code=$code '
        'details=${e.details} message=${e.message}',
        name: 'Subscription',
        stackTrace: st,
      );
      // ignore: avoid_print
      print('[Subscription] purchase error code=$code message=${e.message}');

      if (code == PurchasesErrorCode.purchaseCancelledError) return false;
      if (code == PurchasesErrorCode.paymentPendingError) return false;

      // "Already subscribed" → the user IS entitled; let refreshAfterPurchase
      // reconcile the notifier state.
      if (code == PurchasesErrorCode.productAlreadyPurchasedError ||
          code == PurchasesErrorCode.receiptAlreadyInUseError) {
        return true;
      }
      return false;
    } catch (e, st) {
      developer.log(
        'RevenueCat: purchase failed — $e',
        name: 'Subscription',
        stackTrace: st,
      );
      return false;
    }
  }

  /// Restore previous purchases. The SDK fetches fresh CustomerInfo from
  /// the server and fires the update listener, which the notifier is
  /// already subscribed to — so the UI updates automatically.
  ///
  /// Returns the derived tier so the caller can show a snackbar.
  Future<SubscriptionTier> restorePurchases() async {
    if (!_configured) return SubscriptionTier.free;
    try {
      final info = await Purchases.restorePurchases();
      _logCustomerInfo('restorePurchases', info);
      return tierFromInfo(info);
    } catch (e) {
      developer.log('RevenueCat: restore failed — $e', name: 'Subscription');
      return SubscriptionTier.free;
    }
  }

  /// Present the RC-UI paywall. The listener will push any state change.
  Future<bool> presentPaywall() async {
    if (!_configured) return false;
    try {
      final result = await RevenueCatUI.presentPaywall();
      developer.log('RevenueCat: paywall result=$result', name: 'Subscription');
      return result == PaywallResult.purchased ||
          result == PaywallResult.restored;
    } catch (e) {
      developer.log('RevenueCat: paywall failed — $e', name: 'Subscription');
      return false;
    }
  }

  Future<bool> presentPaywallIfNeeded() async {
    if (!_configured) return false;
    try {
      final result = await RevenueCatUI.presentPaywallIfNeeded(
        RevenueCatConfig.entitlementId,
      );
      developer.log(
        'RevenueCat: paywallIfNeeded result=$result',
        name: 'Subscription',
      );
      return result == PaywallResult.purchased ||
          result == PaywallResult.restored;
    } catch (e) {
      developer.log(
        'RevenueCat: paywallIfNeeded failed — $e',
        name: 'Subscription',
      );
      return false;
    }
  }

  Future<void> presentCustomerCenter() async {
    if (!_configured) return;
    try {
      await RevenueCatUI.presentCustomerCenter();
      // No manual refresh: the update listener will reflect any change
      // (cancel / plan switch) the user made inside the Customer Center.
    } catch (e) {
      developer.log(
        'RevenueCat: customer center failed — $e',
        name: 'Subscription',
      );
    }
  }

  Future<Offerings?> getOfferings() async {
    if (!_configured) return null;
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      developer.log('RevenueCat: offerings failed — $e', name: 'Subscription');
      return null;
    }
  }

  /// Free tier: AI tagging & keyword search only. Premium: everything.
  static bool isAvailable(PremiumFeature feature, SubscriptionTier tier) {
    if (tier == SubscriptionTier.premium) return true;
    switch (feature) {
      case PremiumFeature.askChat:
      case PremiumFeature.recap:
      case PremiumFeature.synthesis:
      case PremiumFeature.semanticSearch:
        return false;
    }
  }

  static String featureLabel(PremiumFeature feature) {
    return switch (feature) {
      PremiumFeature.askChat => 'Ask Your Bookmarks',
      PremiumFeature.recap => 'Weekly Recap',
      PremiumFeature.synthesis => 'Multi-Link Synthesis',
      PremiumFeature.semanticSearch => 'Semantic Search',
    };
  }
}

/// Reactive subscription tier — THE ONLY SOURCE OF TRUTH FOR THE UI.
///
/// Lifecycle:
///   * `build()`  → register RC listener, then one cached
///     `Purchases.getCustomerInfo()` call. Never calls `syncPurchases` or
///     `invalidateCustomerInfoCache`, so the screen renders instantly with
///     the last-known tier on cold starts / screen re-opens.
///   * listener  → pushes every RC-originated change straight into
///     `state = AsyncData(tier)`. No StreamController in between.
///   * `refreshAfterPurchase()` → the ONLY method that calls
///     `syncPurchases` + `invalidateCustomerInfoCache` + `getCustomerInfo`.
///     Call it exactly once, right after a successful purchase.
class SubscriptionTierNotifier extends AsyncNotifier<SubscriptionTier> {
  /// Held so we can `removeCustomerInfoUpdateListener` in `ref.onDispose`
  /// (otherwise a `ref.invalidate(subscriptionTierProvider)` would leak a
  /// listener pointing at the old, disposed notifier instance).
  CustomerInfoUpdateListener? _listener;

  @override
  Future<SubscriptionTier> build() async {
    // 1. Register the RC listener ONCE per notifier lifetime. It writes
    // directly into Riverpod state — no StreamController in the middle.
    final listener = (CustomerInfo info) {
      final tier = SubscriptionService.tierFromInfo(info);
      developer.log(
        'SubscriptionTierNotifier: listener → $tier '
        '(active=${info.entitlements.active.keys.toList()})',
        name: 'Subscription',
      );
      // ignore: avoid_print
      print('[Subscription] notifier listener → $tier '
          '(active=${info.entitlements.active.keys.toList()})');
      // Overwrite any AsyncLoading / AsyncError the UI might be showing.
      state = AsyncData(tier);
    };
    Purchases.addCustomerInfoUpdateListener(listener);
    _listener = listener;
    ref.onDispose(() {
      final l = _listener;
      if (l != null) {
        Purchases.removeCustomerInfoUpdateListener(l);
        _listener = null;
      }
    });

    // 2. Initial read: CACHED ONLY. No syncPurchases. No invalidate.
    // This is what eliminates the "loader every time the screen opens"
    // and the "flash of Free after launch" — the cached value is served
    // synchronously by RC after the first session.
    if (!SubscriptionService.instance.isConfigured) {
      developer.log(
        'SubscriptionTierNotifier: SDK not configured → free',
        name: 'Subscription',
      );
      return SubscriptionTier.free;
    }
    try {
      final info = await Purchases.getCustomerInfo();

      final tier = SubscriptionService.tierFromInfo(info);
      developer.log(
        'SubscriptionTierNotifier: build (cached) → $tier '
        '(active=${info.entitlements.active.keys.toList()})',
        name: 'Subscription',
      );
      // ignore: avoid_print
      print('[Subscription] notifier build (cached) → $tier '
          '(active=${info.entitlements.active.keys.toList()})');
      return tier;
    } catch (e) {
      developer.log(
        'SubscriptionTierNotifier: build failed — $e',
        name: 'Subscription',
      );
      return SubscriptionTier.free;
    }
  }

  /// Call exactly once after a successful `Purchases.purchase(...)`.
  ///
  /// This is the ONLY place in the app that calls `syncPurchases()` and
  /// `invalidateCustomerInfoCache()`. Doing it here solves the "RC dashboard
  /// shows Pro but app shows Free for 5 min" race, because RC's default
  /// 5-minute CustomerInfo cache would otherwise hide the fresh receipt.
  Future<void> refreshAfterPurchase() async {
    if (!SubscriptionService.instance.isConfigured) {
      state = const AsyncData(SubscriptionTier.free);
      return;
    }
    state = const AsyncLoading();
    try {
      if (Platform.isAndroid) {
        try {
          await Purchases.syncPurchases();
        } catch (e) {
          developer.log(
            'SubscriptionTierNotifier: syncPurchases failed — $e',
            name: 'Subscription',
          );
        }
      }
      try {
        await Purchases.invalidateCustomerInfoCache();
      } catch (e) {
        developer.log(
          'SubscriptionTierNotifier: invalidateCustomerInfoCache failed — $e',
          name: 'Subscription',
        );
      }
      final info = await Purchases.getCustomerInfo();

      final tier = SubscriptionService.tierFromInfo(info);
      developer.log(
        'SubscriptionTierNotifier: refreshAfterPurchase → $tier '
        '(active=${info.entitlements.active.keys.toList()})',
        name: 'Subscription',
      );
      // ignore: avoid_print
      print('[Subscription] refreshAfterPurchase → $tier '
          '(active=${info.entitlements.active.keys.toList()})');
      state = AsyncData(tier);
    } catch (e, st) {
      developer.log(
        'SubscriptionTierNotifier: refreshAfterPurchase failed — $e',
        name: 'Subscription',
        stackTrace: st,
      );
      state = AsyncError(e, st);
    }
  }
}

/// Current subscription tier — watched by UI to gate features.
final subscriptionTierProvider =
    AsyncNotifierProvider<SubscriptionTierNotifier, SubscriptionTier>(
  SubscriptionTierNotifier.new,
);

/// Convenience provider for the subscription service singleton.
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService.instance;
});
