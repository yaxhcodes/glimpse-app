import 'package:flutter/material.dart';

import '../../core/services/app_haptics.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';

/// Step through the chart's days and open the chosen one. The day itself is
/// one tonal bar, flanked by quiet arrows.
class GlimpseDayNavigation extends StatelessWidget {
  const GlimpseDayNavigation({
    super.key,
    required this.dateLabel,
    required this.countLabel,
    required this.onOpen,
    this.onPrevious,
    this.onNext,
  });

  final String dateLabel;
  final String countLabel;
  final VoidCallback onOpen;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = context.l10n;
    VoidCallback? step(VoidCallback? action) => action == null
        ? null
        : () {
            AppHaptics.play(AppHaptics.tick);
            action();
          };

    return Row(
      children: [
        IconButton(
          tooltip: l.glimpsesPreviousDay,
          onPressed: step(onPrevious),
          icon: const Icon(AppIcons.arrowBack, size: 18),
        ),
        Expanded(
          child: FilledButton(
            key: const ValueKey('glimpse-selected-day'),
            style: FilledButton.styleFrom(
              backgroundColor: cs.secondaryContainer,
              foregroundColor: cs.onSecondaryContainer,
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: () {
              AppHaptics.play(AppHaptics.tap);
              onOpen();
            },
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dateLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: cs.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        countLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSecondaryContainer.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(AppIcons.arrowForward, size: 18),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: l.glimpsesNextDay,
          onPressed: step(onNext),
          icon: const Icon(AppIcons.arrowForward, size: 18),
        ),
      ],
    );
  }
}
