import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/subscription_service.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tierAsync = ref.watch(subscriptionTierProvider);

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
        data: (tier) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ΓöÇΓöÇ Current plan badge ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: tier == SubscriptionTier.premium
                    ? LinearGradient(
                        colors: [
                          colorScheme.primaryContainer,
                          colorScheme.tertiaryContainer,
                        ],
                      )
                    : null,
                color: tier == SubscriptionTier.free
                    ? colorScheme.surfaceContainerHigh
                    : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(
                    tier == SubscriptionTier.premium
                        ? Icons.workspace_premium
                        : Icons.bookmark_outline,
                    size: 48,
                    color: tier == SubscriptionTier.premium
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tier == SubscriptionTier.premium
                        ? 'Glimpse Pro'
                        : 'Glimpse Free',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tier == SubscriptionTier.premium
                        ? 'You have access to all features'
                        : 'AI tagging included for free',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ΓöÇΓöÇ Feature comparison ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
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
              included: tier == SubscriptionTier.premium,
              isPremium: true,
            ),
            _FeatureRow(
              icon: Icons.auto_awesome_outlined,
              title: 'Weekly Recap',
              subtitle: 'AI-generated summary of your week',
              included: tier == SubscriptionTier.premium,
              isPremium: true,
            ),
            _FeatureRow(
              icon: Icons.merge_type_outlined,
              title: 'Multi-Link Synthesis',
              subtitle: 'Cross-analyze multiple bookmarks',
              included: tier == SubscriptionTier.premium,
              isPremium: true,
            ),
            _FeatureRow(
              icon: Icons.manage_search_outlined,
              title: 'Semantic Search',
              subtitle: 'Find links by meaning, not just keywords',
              included: tier == SubscriptionTier.premium,
              isPremium: true,
            ),

            const SizedBox(height: 32),

            // ΓöÇΓöÇ Action buttons ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
            if (tier == SubscriptionTier.free) ...[
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
                onPressed: () => _openCustomerCenter(context),
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('Manage Subscription'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showPaywall(BuildContext context, WidgetRef ref) async {
    final purchased = await SubscriptionService().presentPaywall();
    if (purchased) {
      ref.read(subscriptionTierProvider.notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome to Glimpse Pro!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _restorePurchases(BuildContext context, WidgetRef ref) async {
    final tier = await SubscriptionService().restorePurchases();
    ref.read(subscriptionTierProvider.notifier).refresh();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tier == SubscriptionTier.premium
                ? 'Purchases restored ΓÇö welcome back!'
                : 'No previous purchases found',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openCustomerCenter(BuildContext context) async {
    await SubscriptionService().presentCustomerCenter();
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
