import 'package:flutter/material.dart';

class ContentAttributionDisclaimer extends StatelessWidget {
  const ContentAttributionDisclaimer({super.key});

  static const accuracyText = 'Information may be inaccurate';
  static const attributionText = 'Original content belongs to its creator.';
  static const message = '$accuracyText. $attributionText';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      container: true,
      label: message,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            accuracyText,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            attributionText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.58),
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
