import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/usage_providers.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/services/usage_service.dart';

/// Compact chip that shows remaining usage for a [UsageFeature].
///
/// * Pro users → hidden.
/// * Free users → "X remaining" in muted text.
/// * When ≥ 80 % consumed → tinted warning color.
class UsageBadge extends ConsumerWidget {
  final UsageFeature feature;
  final EdgeInsets padding;

  const UsageBadge({
    super.key,
    required this.feature,
    this.padding = const EdgeInsets.only(right: 12),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remainingAsync = ref.watch(remainingUsageProvider(feature));
    final nearLimitAsync = ref.watch(nearLimitProvider(feature));

    return remainingAsync.when(
      data: (remaining) {
        if (remaining >= 9999) return const SizedBox.shrink();
        final nearLimit = nearLimitAsync.valueOrNull ?? false;
        final colorScheme = Theme.of(context).colorScheme;

        return Padding(
          padding: padding,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: nearLimit
                    ? colorScheme.errorContainer.withValues(alpha: 0.6)
                    : colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.6,
                      ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$remaining left',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: nearLimit
                      ? colorScheme.onErrorContainer
                      : colorScheme.onSurfaceVariant,
                  fontWeight: nearLimit ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}

/// Inline row that shows either:
///
/// * "X / limit used"  (free user)
/// * hidden            (Pro user)
class UsageInlineIndicator extends ConsumerWidget {
  final UsageFeature feature;

  const UsageInlineIndicator({super.key, required this.feature});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(usageProvider(feature));
    final nearLimitAsync = ref.watch(nearLimitProvider(feature));

    return usageAsync.when(
      data: (usage) {
        final isPro = ref.watch(isProUserProvider);
        final limit = UsageService.limitFor(feature, isPro: isPro);
        final nearLimit = nearLimitAsync.valueOrNull ?? false;
        final colorScheme = Theme.of(context).colorScheme;

        return Text(
          '$usage / $limit used',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: nearLimit ? colorScheme.error : colorScheme.onSurfaceVariant,
            fontWeight: nearLimit ? FontWeight.w700 : FontWeight.w500,
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}
