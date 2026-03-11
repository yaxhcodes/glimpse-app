import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// What the user has access to.
enum SubscriptionTier { free, premium }

/// Features that can be gated.
enum PremiumFeature {
  askChat,
  recap,
  synthesis,
  semanticSearch,
}

/// RevenueCat configuration constants.
class RevenueCatConfig {
  RevenueCatConfig._();

  /// Google Play API key for RevenueCat.
  static const apiKey = 'test_uzVPYTOwXARdLDJqsnKxnRRFEjT';

  /// The entitlement identifier configured in RevenueCat dashboard.
  static const entitlementId = 'Glimpse Pro';

  /// Product identifiers (configured in RevenueCat dashboard & Google Play).
  static const monthlyProductId = 'monthly';
  static const yearlyProductId = 'yearly';
  static const lifetimeProductId = 'lifetime';
}

/// Manages the user's subscription via RevenueCat.
///
/// Free tier: AI tagging (categorization) only.
/// Premium tier: Ask chat, Recap, Synthesis, Semantic search.
class SubscriptionService {
  /// Initialise the RevenueCat SDK. Call once at app startup.
  /// Skipped — all features unlocked for direct API testing.
  static Future<void> init() async {
    log('RevenueCat: init skipped — all features unlocked');
  }

  /// Returns the current [SubscriptionTier].
  /// All features unlocked — using Gemini and Voyage AI APIs directly.
  Future<SubscriptionTier> getTier() async {
    return SubscriptionTier.premium;
  }

  /// Restore previous purchases (e.g. after reinstall).
  Future<SubscriptionTier> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      if (customerInfo.entitlements.active.containsKey(
        RevenueCatConfig.entitlementId,
      )) {
        return SubscriptionTier.premium;
      }
    } catch (e) {
      log('RevenueCat: restore failed — $e');
    }
    return SubscriptionTier.free;
  }

  /// Present the RevenueCat paywall. Returns `true` if a purchase was made.
  Future<bool> presentPaywall() async {
    final result = await RevenueCatUI.presentPaywall();
    return result == PaywallResult.purchased ||
        result == PaywallResult.restored;
  }

  /// Present the paywall only if the user does NOT already have [RevenueCatConfig.entitlementId].
  Future<bool> presentPaywallIfNeeded() async {
    final result = await RevenueCatUI.presentPaywallIfNeeded(
      RevenueCatConfig.entitlementId,
    );
    return result == PaywallResult.purchased ||
        result == PaywallResult.restored;
  }

  /// Open the RevenueCat Customer Center (manage subscription, cancel, etc.).
  Future<void> presentCustomerCenter() async {
    await RevenueCatUI.presentCustomerCenter();
  }

  /// Get the current offerings configured in RevenueCat.
  Future<Offerings> getOfferings() async {
    return Purchases.getOfferings();
  }

  /// Get the current [CustomerInfo] from RevenueCat.
  Future<CustomerInfo> getCustomerInfo() async {
    return Purchases.getCustomerInfo();
  }

  /// Whether the given feature is available on the given tier.
  /// All features unlocked for direct API usage.
  static bool isAvailable(PremiumFeature feature, SubscriptionTier tier) {
    return true;
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

/// Notifier that tracks the subscription tier.
/// All features unlocked — using Gemini and Voyage AI APIs directly.
class SubscriptionTierNotifier extends AsyncNotifier<SubscriptionTier> {
  @override
  Future<SubscriptionTier> build() async {
    return SubscriptionTier.premium;
  }

  /// Force a refresh (e.g. after presenting a paywall).
  Future<void> refresh() async {
    state = const AsyncData(SubscriptionTier.premium);
  }
}

/// Current subscription tier — watched by UI to gate features.
/// Automatically updates when RevenueCat customer info changes.
final subscriptionTierProvider =
    AsyncNotifierProvider<SubscriptionTierNotifier, SubscriptionTier>(
  SubscriptionTierNotifier.new,
);

/// Convenience provider for the subscription service singleton.
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});
