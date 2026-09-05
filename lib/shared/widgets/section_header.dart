import 'package:flutter/material.dart';

enum SectionHeaderEmphasis { primary, secondary }

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    required this.accent,
    this.emphasis = SectionHeaderEmphasis.primary,
  });

  final String title;
  final Color accent;
  final SectionHeaderEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPrimary = emphasis == SectionHeaderEmphasis.primary;
    return Semantics(
      header: true,
      child: Text(
        title,
        style:
            (isPrimary
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.titleSmall)
                ?.copyWith(
                  color: isPrimary
                      ? accent
                      : Color.alphaBlend(
                          accent.withValues(alpha: 0.16),
                          colorScheme.onSurface,
                        ),
                  fontWeight: FontWeight.w700,
                  height: isPrimary ? 1.18 : 1.22,
                ),
      ),
    );
  }
}
