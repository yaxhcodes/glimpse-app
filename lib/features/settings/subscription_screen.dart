import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_environment.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/services/subscription_service.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() =>
      _SubscriptionScreenState();
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
      appBar: AppBar(title: const Text('Subscription')),
      body: tierAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              const Text('Could not load subscription info'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(subscriptionTierProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (rcTier) {
          final isPro = ref.watch(isProUserProvider);
          final showDevOverrideHint = AppEnvironment.allowsLocalProOverride &&
              (ref.watch(devProOverrideProvider).valueOrNull ?? false) &&
              rcTier == SubscriptionTier.free;
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              // Header
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPro ? 'Glimpse Pro' : 'Glimpse Free',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isPro
                        ? (showDevOverrideHint
                            ? 'Unlock the full power of AI across your entire library. Every feature, with no limits. (dev override; store: Free)'
                            : 'Unlock the full power of AI across your entire library. Every feature, with no limits.')
                        : 'Build your personal knowledge library with essential tools. AI features are included so you can explore before upgrading.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StatusBadge(isPro: isPro),
                ],
              ),
              const SizedBox(height: 40),

              // Core Library
              Text(
                'Core Library',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              const _FeatureRow(
                title: 'Unlimited link saving',
                subtitle: 'Save as many links as you want',
                mode: _FeatureMode.free,
              ),
              const SizedBox(height: 20),
              const _FeatureRow(
                title: 'Collections & organization',
                subtitle: 'Group and manage bookmarks your way',
                mode: _FeatureMode.free,
              ),
              const SizedBox(height: 20),
              const _FeatureRow(
                title: 'Smart notifications',
                subtitle: 'Behavior-based alerts and reading reminders',
                mode: _FeatureMode.free,
              ),
              const SizedBox(height: 40),

              // AI Assistant
              Text(
                'AI Assistant',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              const _FeatureRow(
                title: 'AI tagging & categorization',
                subtitle: 'Free: 15 saves per month · Pro: Unlimited',
                mode: _FeatureMode.limited,
              ),
              const SizedBox(height: 20),
              const _FeatureRow(
                title: 'Keyword search',
                subtitle: 'Free: 15 searches per month · Pro: Unlimited',
                mode: _FeatureMode.limited,
              ),
              const SizedBox(height: 20),
              const _FeatureRow(
                title: 'Ask Your Bookmarks',
                subtitle: 'Free: 5 questions per month · Pro: Unlimited',
                mode: _FeatureMode.limited,
              ),
              const SizedBox(height: 40),

              // Pro Insights
              Text(
                'Pro Insights',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              _FeatureRow(
                title: 'Semantic search',
                subtitle: 'Find links by meaning, not just words',
                mode: _FeatureMode.proOnly,
                isPro: isPro,
              ),
              const SizedBox(height: 20),
              _FeatureRow(
                title: 'Weekly Recap',
                subtitle: 'AI-generated summary of your saved links',
                mode: _FeatureMode.proOnly,
                isPro: isPro,
              ),
              const SizedBox(height: 20),
              _FeatureRow(
                title: 'Multi-Link Synthesis',
                subtitle: 'Cross-analyze any set of bookmarks',
                mode: _FeatureMode.proOnly,
                isPro: isPro,
              ),
              const SizedBox(height: 48),

              // Action buttons: always follow **RevenueCat** tier, not the dev override.
              if (rcTier == SubscriptionTier.free) ...[
                FilledButton(
                  onPressed: () => _showPaywall(context, ref),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Upgrade to Glimpse Pro'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _restorePurchases(context, ref),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Restore Purchases'),
                ),
              ] else ...[
                FilledButton(
                  onPressed: () => _openCustomerCenter(context, ref),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Manage Subscription'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _manageSubscription(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Manage on Google Play'),
                ),
                if (AppEnvironment.isDevContext) ...[
                  const SizedBox(height: 8),
                  Text(
                    'May not work in debug builds',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
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
    final entitled = ref.read(subscriptionTierProvider).valueOrNull ==
        SubscriptionTier.premium;
    if (entitled) {
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

class _StatusBadge extends StatelessWidget {
  final bool isPro;

  const _StatusBadge({required this.isPro});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPro
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isPro ? 'Active' : 'Free',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isPro
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

enum _FeatureMode { free, limited, proOnly }

class _FeatureRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final _FeatureMode mode;
  final bool isPro;

  const _FeatureRow({
    required this.title,
    required this.subtitle,
    required this.mode,
    this.isPro = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    switch (mode) {
      case _FeatureMode.free:
        return _buildRow(
          indicator: _SubtleTick(colorScheme: colorScheme),
          title: title,
          titleColor: colorScheme.onSurface,
          subtitle: subtitle,
          subtitleColor: colorScheme.onSurfaceVariant,
        );
      case _FeatureMode.limited:
        return _buildRow(
          indicator: _SubtleTick(colorScheme: colorScheme),
          title: title,
          titleColor: colorScheme.onSurface,
          subtitle: subtitle,
          subtitleColor: colorScheme.onSurfaceVariant,
        );
      case _FeatureMode.proOnly:
        if (isPro) {
          return _buildRow(
            indicator: _SubtleTick(colorScheme: colorScheme),
            title: title,
            titleColor: colorScheme.onSurface,
            subtitle: subtitle,
            subtitleColor: colorScheme.onSurfaceVariant,
          );
        }
        return _buildRow(
          indicator: const SizedBox.shrink(),
          title: title,
          titleColor: colorScheme.onSurfaceVariant,
          subtitle: subtitle,
          subtitleColor: colorScheme.onSurfaceVariant,
          trailing: const _ProLabel(),
        );
    }
  }

  Widget _buildRow({
    required Widget indicator,
    required String title,
    required Color titleColor,
    required String subtitle,
    required Color subtitleColor,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        indicator,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        color: titleColor,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing,
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: subtitleColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubtleTick extends StatelessWidget {
  final ColorScheme colorScheme;

  const _SubtleTick({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Text(
      '✓',
      style: TextStyle(
        fontSize: 14,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    );
  }
}

class _ProLabel extends StatelessWidget {
  const _ProLabel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Pro',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
