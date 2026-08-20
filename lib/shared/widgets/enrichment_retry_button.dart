import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'expressive_loading_indicator.dart';

class EnrichmentRetryButton extends StatelessWidget {
  const EnrichmentRetryButton({
    super.key,
    required this.retrying,
    required this.onPressed,
    this.color,
    this.icon = Icons.auto_awesome_rounded,
    this.label,
    this.retryingLabel,
    this.tonal = false,
  });

  final bool retrying;
  final VoidCallback? onPressed;
  final Color? color;
  final IconData? icon;
  final String? label;
  final String? retryingLabel;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = color ?? theme.colorScheme.primary;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (retrying)
          SizedBox(
            width: 14,
            height: 14,
            child: ExpressiveLoadingIndicator(size: 14, color: foreground),
          )
        else if (icon != null)
          Icon(icon, size: 16),
        if (retrying || icon != null) const SizedBox(width: 6),
        Text(
          retrying
              ? retryingLabel ?? context.l10n.retrying
              : label ?? context.l10n.retry,
        ),
      ],
    );

    final textStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    if (tonal) {
      final background = Color.alphaBlend(
        foreground.withValues(alpha: 0.13),
        theme.colorScheme.surfaceContainerHighest,
      );
      return FilledButton(
        onPressed: retrying ? null : onPressed,
        style: FilledButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: background,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: textStyle,
        ),
        child: content,
      );
    }

    return TextButton(
      onPressed: retrying ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        minimumSize: const Size(0, 28),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        textStyle: textStyle,
      ),
      child: content,
    );
  }
}
