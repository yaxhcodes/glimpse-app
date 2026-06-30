import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_environment.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/services/subscription_service.dart';
import 'settings_components.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  // NO initState refresh. The notifier's `build()` already serves the
  // cached tier from RevenueCat's local cache instantly, and the
  // `addCustomerInfoUpdateListener` pushes any future change into state.
  // Kicking off a refresh here was the source of the "loader every time
  // the screen opens" and the "Free flash over a correct Pro badge".

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tierAsync = ref.watch(subscriptionTierProvider);
    developer.log(
      'SubscriptionScreen: rebuild with tier=$tierAsync',
      name: 'Subscription',
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        title: Text(
          'Subscription',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: tierAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              const Text('Could not load subscription info'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(subscriptionTierProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (rcTier) {
          final isPro = ref.watch(isProUserProvider);
          final showDevOverrideHint =
              AppEnvironment.allowsLocalProOverride &&
              (ref.watch(devProOverrideProvider).valueOrNull ?? false) &&
              rcTier == SubscriptionTier.free;

          return Column(
            children: [
              // Scrollable feature list.
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _PlanHero(
                      isPro: isPro,
                      showDevOverrideHint: showDevOverrideHint,
                    ),
                    const SizedBox(height: 28),

                    // ── Core Library (free) ──
                    const SettingsGroupLabel('Core Library'),
                    const SettingsGroup(
                      children: [
                        _PlanFeatureTile(
                          title: 'Unlimited link saving',
                          subtitle: 'Save as many links as you want',
                          included: true,
                        ),
                        _PlanFeatureTile(
                          title: 'Collections & organization',
                          subtitle: 'Group and manage bookmarks your way',
                          included: true,
                        ),
                        _PlanFeatureTile(
                          title: 'Smart notifications',
                          subtitle:
                              'Behavior-based alerts and reading reminders',
                          included: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── AI Assistant (free with monthly caps) ──
                    const SettingsGroupLabel('AI Assistant'),
                    const SettingsGroup(
                      children: [
                        _PlanFeatureTile(
                          title: 'AI tagging & categorization',
                          subtitle: 'Free: 15 saves / mo  ·  Pro: Unlimited',
                          included: true,
                        ),
                        _PlanFeatureTile(
                          title: 'Keyword search',
                          subtitle: 'Free: 15 searches / mo  ·  Pro: Unlimited',
                          included: true,
                        ),
                        _PlanFeatureTile(
                          title: 'Ask Your Bookmarks',
                          subtitle: 'Free: 5 questions / mo  ·  Pro: Unlimited',
                          included: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Pro Insights (Pro only) ──
                    const SettingsGroupLabel('Pro Insights'),
                    SettingsGroup(
                      children: [
                        _PlanFeatureTile(
                          title: 'Semantic search',
                          subtitle: 'Find links by meaning, not just words',
                          included: isPro,
                          proOnly: true,
                        ),
                        _PlanFeatureTile(
                          title: 'Weekly Recap',
                          subtitle: 'AI-generated summary of your saved links',
                          included: isPro,
                          proOnly: true,
                        ),
                        _PlanFeatureTile(
                          title: 'Multi-Link Synthesis',
                          subtitle: 'Cross-analyze any set of bookmarks',
                          included: isPro,
                          proOnly: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Pinned action bar — the CTA is always visible, no scroll.
              _CtaFooter(
                rcTier: rcTier,
                onUpgrade: () => _showPaywall(context, ref),
                onRestore: () => _restorePurchases(context, ref),
                onManage: () => _openCustomerCenter(context, ref),
                onManageOnPlay: () => _manageSubscription(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showPaywall(BuildContext context, WidgetRef ref) async {
    final service = ref.read(subscriptionServiceProvider);
    if (!service.isConfigured) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Subscriptions are unavailable in this build.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
      }
      return;
    }

    // 1. Native purchase via RevenueCat.
    final purchased = await service.purchaseRecommendedPackage();
    if (!purchased) return;

    // 2. Explicit, one-shot reconciliation. This is the ONLY call site
    // of refreshAfterPurchase() in the app — it runs syncPurchases +
    // invalidateCustomerInfoCache + getCustomerInfo and flips Riverpod
    // state to Pro. Without it the local RC cache could serve the
    // pre-purchase "free" payload for up to 5 minutes.
    await ref.read(subscriptionTierProvider.notifier).refreshAfterPurchase();

    if (!context.mounted) return;
    final entitled =
        ref.read(subscriptionTierProvider).valueOrNull ==
        SubscriptionTier.premium;
    if (entitled) {
      unawaited(
        ref.read(analyticsServiceProvider).trackEvent(
              AnalyticsEvent.subscriptionPurchased,
              screen: AnalyticsScreen.subscription,
            ),
      );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Welcome to Glimpse Pro!'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
    }
  }

  Future<void> _restorePurchases(BuildContext context, WidgetRef ref) async {
    final service = ref.read(subscriptionServiceProvider);
    // Purchases.restorePurchases() returns fresh CustomerInfo AND fires
    // the update listener, which the notifier is subscribed to — so the
    // Riverpod state updates on its own. No manual refresh required.
    final tier = await service.restorePurchases();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              tier == SubscriptionTier.premium
                  ? 'Purchases restored — welcome back!'
                  : 'No previous purchases found',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
    }
  }

  Future<void> _openCustomerCenter(BuildContext context, WidgetRef ref) async {
    // Any change the user makes inside the Customer Center (cancel, switch
    // plan, etc.) fires the RC update listener, which flips Riverpod state
    // automatically. No manual refresh required.
    await ref.read(subscriptionServiceProvider).presentCustomerCenter();
  }

  Future<void> _manageSubscription(BuildContext context) async {
    const packageName = 'com.shinrinyoku.glimpse';
    final uri = Uri.parse(
      'https://play.google.com/store/account/subscriptions?package=$packageName',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Could not open Google Play.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Could not open Google Play.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
      }
    }
  }
}

/// Premium plan header — brand mark, plan name, status pill and the value
/// pitch, in a single rounded hero.
class _PlanHero extends StatelessWidget {
  const _PlanHero({required this.isPro, required this.showDevOverrideHint});

  final bool isPro;
  final bool showDevOverrideHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final description = isPro
        ? (showDevOverrideHint
              ? 'Every AI feature, no limits, across your whole library. '
                    '(dev override; store: Free)'
              : 'Every AI feature, no limits, across your whole library.')
        : 'Build your personal knowledge library with essential tools. AI '
              'features are included so you can explore before upgrading.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isPro ? cs.primaryContainer : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(kSettingsGroupRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPro
                      ? cs.onPrimaryContainer.withValues(alpha: 0.12)
                      : SettingsAccents.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/glimpse.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    isPro ? cs.onPrimaryContainer : SettingsAccents.gold,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  isPro ? 'Glimpse Pro' : 'Glimpse Free',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: isPro ? cs.onPrimaryContainer : cs.onSurface,
                  ),
                ),
              ),
              SettingsBadge(
                label: isPro ? 'Active' : 'Free',
                emphasized: isPro,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.4,
              color: isPro
                  ? cs.onPrimaryContainer.withValues(alpha: 0.85)
                  : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// One feature row — a check chip when included, a lock chip + "Pro" pill
/// when it's a locked Pro-only feature.
class _PlanFeatureTile extends StatelessWidget {
  const _PlanFeatureTile({
    required this.title,
    required this.subtitle,
    required this.included,
    this.proOnly = false,
  });

  final String title;
  final String subtitle;
  final bool included;
  final bool proOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final locked = proOnly && !included;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: locked
                  ? cs.onSurfaceVariant.withValues(alpha: 0.10)
                  : cs.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              locked ? Icons.lock_outline_rounded : Icons.check_rounded,
              size: 19,
              color: locked ? cs.onSurfaceVariant : cs.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: locked ? cs.onSurfaceVariant : cs.onSurface,
                        ),
                      ),
                    ),
                    // The "Pro" pill is an upsell cue — show it only while the
                    // feature is locked (free users). Owned Pro features just
                    // read as a plain check.
                    if (locked) ...[
                      const SizedBox(width: 8),
                      const SettingsBadge(label: 'Pro', emphasized: true),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinned bottom action bar so the primary CTA never requires scrolling.
class _CtaFooter extends StatelessWidget {
  const _CtaFooter({
    required this.rcTier,
    required this.onUpgrade,
    required this.onRestore,
    required this.onManage,
    required this.onManageOnPlay,
  });

  final SubscriptionTier rcTier;
  final VoidCallback onUpgrade;
  final VoidCallback onRestore;
  final VoidCallback onManage;
  final VoidCallback onManageOnPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Action buttons always follow **RevenueCat** tier, not the dev override.
    final isFree = rcTier == SubscriptionTier.free;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: isFree
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton(
                      onPressed: onUpgrade,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      child: const Text('Upgrade to Glimpse Pro'),
                    ),
                    TextButton(
                      onPressed: onRestore,
                      child: const Text('Restore Purchases'),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton(
                      onPressed: onManage,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      child: const Text('Manage Subscription'),
                    ),
                    TextButton(
                      onPressed: onManageOnPlay,
                      child: const Text('Manage on Google Play'),
                    ),
                    if (AppEnvironment.isDevContext)
                      Text(
                        'May not work in debug builds',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
