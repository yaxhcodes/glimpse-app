import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            padding: const EdgeInsets.all(16),
            children: [
            // Plan badge: reflects **effective** access. Store buttons below use RC.
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: isPro
                    ? LinearGradient(
                        colors: [
                          colorScheme.primaryContainer,
                          colorScheme.tertiaryContainer,
                        ],
                      )
                    : null,
                color: !isPro
                    ? colorScheme.surfaceContainerHigh
                    : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(
                    isPro
                        ? Icons.workspace_premium
                        : Icons.bookmark_outline,
                    size: 48,
                    color: isPro
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isPro
                        ? 'Glimpse Pro'
                        : 'Glimpse Free',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPro
                        ? (showDevOverrideHint
                            ? 'You have access to all features (dev override; store: Free)'
                            : 'You have access to all features')
                        : 'AI tagging included for free',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Feature comparison
            Text('What you get', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const _FeatureRow(
              icon: Icons.label_outlined,
              title: 'AI Tagging & Categorization',
              subtitle: 'Automatic when saving URLs',
              included: true,
            ),
            const _FeatureRow(
              icon: Icons.search,
              title: 'Keyword Search',
              subtitle: 'Search your saved bookmarks',
              included: true,
            ),
            const Divider(height: 32),
            Text(
              'Premium Features',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            _FeatureRow(
              icon: Icons.psychology_outlined,
              title: 'Ask Your Bookmarks',
              subtitle: 'Chat with AI about your saved links',
              included: isPro,
              isPremium: true,
            ),
            _FeatureRow(
              icon: Icons.auto_awesome_outlined,
              title: 'Weekly Recap',
              subtitle: 'AI-generated summary of your week',
              included: isPro,
              isPremium: true,
            ),
            _FeatureRow(
              icon: Icons.merge_type_outlined,
              title: 'Multi-Link Synthesis',
              subtitle: 'Cross-analyze multiple bookmarks',
              included: isPro,
              isPremium: true,
            ),
            _FeatureRow(
              icon: Icons.manage_search_outlined,
              title: 'Semantic Search',
              subtitle: 'Find links by meaning, not just keywords',
              included: isPro,
              isPremium: true,
            ),

            const SizedBox(height: 32),

            // Action buttons: always follow **RevenueCat** tier, not the dev override.
            if (rcTier == SubscriptionTier.free) ...[
              FilledButton.icon(
                onPressed: () => _showPaywall(context, ref),
                icon: const Icon(Icons.workspace_premium),
                label: const Text('Upgrade to Glimpse Pro'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _restorePurchases(context, ref),
                icon: const Icon(Icons.restore),
                label: const Text('Restore Purchases'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: () => _openCustomerCenter(context, ref),
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('Manage Subscription'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
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
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool included;
  final bool isPremium;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.included,
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 24, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                )),
              ],
            ),
          ),
          Icon(
            included ? Icons.check_circle : Icons.lock_outline,
            color: included ? Colors.green : colorScheme.onSurfaceVariant,
            size: 22,
          ),
        ],
      ),
    );
  }
}
