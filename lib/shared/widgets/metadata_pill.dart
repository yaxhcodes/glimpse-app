import 'package:flutter/material.dart';

class MetadataPill extends StatelessWidget {
  const MetadataPill({
    super.key,
    required this.value,
    required this.icon,
    this.label,
  });

  final String value;
  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          if (label != null && label!.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              label!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
