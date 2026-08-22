import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart' show rootNavigatorKey;
import 'app_snackbar.dart';
import 'expressive_loading_indicator.dart';
import '../../core/providers/usage_providers.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/services/subscription_service.dart';
import '../../core/services/usage_service.dart';

/// The feature context that triggered the upgrade gate.
///
/// Each value provides context-specific copy so the modal feels
/// intentional and relevant, not generic.
enum UpgradeFeature { aiTagging, ask, search, semanticSearch, recap, synthesis }

/// Describes what Pro unlocks for each feature.
extension UpgradeFeatureCopy on UpgradeFeature {
  String get title => switch (this) {
    UpgradeFeature.aiTagging => 'AI categorization limit reached',
    UpgradeFeature.ask => 'Ask Glimpse limit reached',
    UpgradeFeature.search => 'Search limit reached',
    UpgradeFeature.semanticSearch => 'Semantic search is a Pro feature',
    UpgradeFeature.recap => 'Weekly Recap is a Pro feature',
    UpgradeFeature.synthesis => 'Multi-link synthesis is a Pro feature',
  };

  String get description => switch (this) {
    UpgradeFeature.aiTagging =>
      'Upgrade to Glimpse Pro for up to 500 AI-enriched saves each month, plus summaries and semantic search.',
    UpgradeFeature.ask =>
      'Upgrade to Glimpse Pro for generous Ask Glimpse access and deeper answers powered by semantic search.',
    UpgradeFeature.search =>
      'Upgrade to Glimpse Pro for expanded search across your saved links, including meaning-based semantic search.',
    UpgradeFeature.semanticSearch =>
      'Semantic search finds results by meaning, not just keywords. Upgrade to Glimpse Pro to unlock it with expanded search access.',
    UpgradeFeature.recap =>
      'Weekly Recap distills your recent saves into a short, insightful summary. Upgrade to Glimpse Pro to unlock it.',
    UpgradeFeature.synthesis =>
      'Multi-link synthesis connects ideas across your saves into a cohesive narrative. Upgrade to Glimpse Pro to unlock it.',
  };

  String get ctaLabel => switch (this) {
    UpgradeFeature.aiTagging => 'Get 500 AI saves / month',
    UpgradeFeature.ask => 'Upgrade Ask Glimpse',
    UpgradeFeature.search => 'Upgrade search',
    UpgradeFeature.semanticSearch => 'Upgrade for semantic search',
    UpgradeFeature.recap => 'Upgrade for Weekly Recap',
    UpgradeFeature.synthesis => 'Upgrade for synthesis',
  };

  IconData get icon => switch (this) {
    UpgradeFeature.aiTagging => Icons.auto_awesome_outlined,
    UpgradeFeature.ask => Icons.chat_bubble_outline_rounded,
    UpgradeFeature.search => Icons.search_rounded,
    UpgradeFeature.semanticSearch => Icons.psychology_outlined,
    UpgradeFeature.recap => Icons.auto_stories_outlined,
    UpgradeFeature.synthesis => Icons.merge_type_rounded,
  };
}

/// Shows a premium, minimal upgrade modal.
///
/// Returns `true` if the user completed the purchase (Pro is now active),
/// `false` if dismissed, and `null` if the dialog couldn't be shown.
Future<bool?> showUpgradeGate(BuildContext context, UpgradeFeature feature) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _UpgradeGateDialog(feature: feature),
  );
}

/// Convenience: check limit, show gate if reached, return whether to proceed.
///
/// If the limit is reached, shows the upgrade modal and returns `false`.
/// If the limit is NOT reached, returns `true` (caller should proceed).
/// After a successful upgrade within the modal, invalidates the usage
/// provider and returns `true`.
Future<bool> checkLimitOrShowGate(
  BuildContext context,
  WidgetRef ref,
  UsageFeature feature,
  UpgradeFeature upgradeFeature,
) async {
  final isPro = ref.read(isProUserProvider);
  final usageService = ref.read(usageServiceProvider);
  final reached = await usageService.hasReachedLimit(feature, isPro);

  if (!reached) return true;

  developer.log(
    'Limit reached for ${feature.name}, showing upgrade gate',
    name: 'UpgradeGate',
  );

  if (!context.mounted) return false;
  if (isPro) {
    showAiLimitSnackBar(context, isPro: true);
    return false;
  }
  final upgraded = await showUpgradeGate(context, upgradeFeature);
  if (upgraded == true && context.mounted) {
    // Invalidate usage so counts refresh after purchase
    ref.read(usageRevisionProvider.notifier).state++;
    return true;
  }
  return false;
}

/// Shows a non-blocking snackbar when the active AI-save allowance is used up.
///
/// The app uses a single app-level [ScaffoldMessenger], so the snackbar
/// survives route pops (e.g. the Add-URL screen popping after save). The
/// action navigates via the root navigator so it works regardless of which
/// screen is on top when the user taps it.
void showAiLimitSnackBar(BuildContext context, {required bool isPro}) {
  showAutoDismissSnackBar(
    context,
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      content: Text(
        isPro
            ? "You've used 500 AI saves this month. It was saved without AI enrichment."
            : "You've used your 30 lifetime AI saves. It was saved without AI enrichment.",
      ),
      action: isPro
          ? null
          : SnackBarAction(
              label: 'Upgrade',
              onPressed: () {
                final navContext = rootNavigatorKey.currentContext;
                if (navContext != null) {
                  navContext.push('/settings/subscription');
                }
              },
            ),
    ),
  );
}

class _UpgradeGateDialog extends ConsumerStatefulWidget {
  const _UpgradeGateDialog({required this.feature});

  final UpgradeFeature feature;

  @override
  ConsumerState<_UpgradeGateDialog> createState() => _UpgradeGateDialogState();
}

class _UpgradeGateDialogState extends ConsumerState<_UpgradeGateDialog> {
  bool _purchasing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final feature = widget.feature;

    return AlertDialog(
      backgroundColor: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(
              feature.icon,
              size: 28,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            feature.title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            feature.description,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _benefitRow(
                  Icons.category_outlined,
                  '500 AI-enriched saves each month',
                ),
                const SizedBox(height: 8),
                _benefitRow(
                  Icons.chat_bubble_outline_rounded,
                  'Generous Ask Glimpse access',
                ),
                const SizedBox(height: 8),
                _benefitRow(
                  Icons.psychology_outlined,
                  'Semantic search across your library',
                ),
                const SizedBox(height: 8),
                _benefitRow(
                  Icons.auto_stories_outlined,
                  'Weekly Recap & multi-link synthesis',
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _purchasing
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(
            'Maybe later',
            style: textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        FilledButton(
          onPressed: _purchasing ? null : _purchase,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          child: _purchasing
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: ExpressiveLoadingIndicator(
                    size: 18,
                    color: colorScheme.onPrimary,
                  ),
                )
              : Text(feature.ctaLabel),
        ),
      ],
    );
  }

  Widget _benefitRow(IconData icon, String text) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _purchase() async {
    setState(() => _purchasing = true);
    try {
      final service = ref.read(subscriptionServiceProvider);
      final outcome = await service.purchaseRecommendedPackage();
      developer.log('Purchase result: $outcome', name: 'UpgradeGate');

      switch (outcome) {
        case SubscriptionPurchaseOutcome.success:
        case SubscriptionPurchaseOutcome.alreadyPurchased:
          await ref
              .read(subscriptionTierProvider.notifier)
              .refreshAfterPurchase();
          ref.read(usageRevisionProvider.notifier).state++;
          final entitled =
              ref.read(subscriptionTierProvider).valueOrNull ==
              SubscriptionTier.premium;
          if (mounted && entitled) {
            Navigator.of(context).pop(true);
          } else if (mounted) {
            setState(() => _purchasing = false);
            _showMessage(
              outcome == SubscriptionPurchaseOutcome.alreadyPurchased
                  ? subscriptionOwnershipMessage
                  : 'The purchase completed, but Pro could not be verified yet. '
                        'Please try Restore Purchases.',
            );
          }
          return;
        case SubscriptionPurchaseOutcome.cancelled:
          if (mounted) {
            Navigator.of(context).pop(false);
          }
          return;
        case SubscriptionPurchaseOutcome.pending:
          if (mounted) {
            setState(() => _purchasing = false);
          }
          _showMessage(
            'Your purchase is pending. Pro will unlock after payment is confirmed.',
          );
          return;
        case SubscriptionPurchaseOutcome.ownedByAnotherAccount:
          if (mounted) {
            setState(() => _purchasing = false);
          }
          _showMessage(subscriptionOwnershipMessage);
          return;
        case SubscriptionPurchaseOutcome.unavailable:
        case SubscriptionPurchaseOutcome.failed:
          if (!mounted) return;
          Navigator.of(context).pop(false);
          context.push('/settings/subscription');
          return;
      }
    } catch (e, st) {
      developer.log('Purchase error: $e', name: 'UpgradeGate', stackTrace: st);
      if (mounted) {
        Navigator.of(context).pop(false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  }
}
