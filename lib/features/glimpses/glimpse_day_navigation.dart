import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';

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
    final l = context.l10n;
    ButtonStyle edgeStyle(bool leading) => FilledButton.styleFrom(
      minimumSize: const Size(48, 56),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadiusDirectional.horizontal(
          start: Radius.circular(leading ? 20 : 8),
          end: Radius.circular(leading ? 8 : 20),
        ),
      ),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Tooltip(
            message: l.glimpsesPreviousDay,
            child: FilledButton.tonal(
              style: edgeStyle(true),
              onPressed: onPrevious,
              child: const Icon(AppIcons.arrowBack, size: 18),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: FilledButton.tonal(
              key: const ValueKey('glimpse-selected-day'),
              style: FilledButton.styleFrom(
                backgroundColor: Color.lerp(
                  theme.colorScheme.primary,
                  theme.colorScheme.secondaryContainer,
                  theme.brightness == Brightness.dark ? .2 : .08,
                ),
                foregroundColor: theme.colorScheme.onPrimary,
                minimumSize: const Size(0, 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onOpen,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dateLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    countLabel,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: l.glimpsesNextDay,
            child: FilledButton.tonal(
              style: edgeStyle(false),
              onPressed: onNext,
              child: const Icon(AppIcons.arrowForward, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
