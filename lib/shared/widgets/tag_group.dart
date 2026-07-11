import 'package:flutter/material.dart';

import 'section_header.dart';

/// Canonical colors for tag / keyword chips, used everywhere a tag pill is
/// shown (home cards, detail screen, recommendations) so they look identical.
///
/// Light: soft `secondaryContainer` tint — reads as a warm, clearly-grouped
/// chip. Dark: a muted neutral surface with only a *hint* of the secondary
/// tone, so chips stay legible without the over-saturated "pop" that a full
/// container picks up from a vivid dynamic accent.
({Color background, Color foreground}) tagChipColors(ColorScheme cs) {
  if (cs.brightness == Brightness.dark) {
    return (
      background: Color.alphaBlend(
        cs.secondaryContainer.withValues(alpha: 0.30),
        cs.surfaceContainerHigh,
      ),
      foreground: cs.onSurface.withValues(alpha: 0.92),
    );
  }
  return (
    background: cs.secondaryContainer,
    foreground: cs.onSecondaryContainer,
  );
}

class TagGroup extends StatelessWidget {
  const TagGroup({
    super.key,
    required this.tags,
    required this.onTap,
    required this.onLongPress,
    this.hiddenCount = 0,
    this.onShowMore,
    this.accent,
    this.chipColor,
    this.chipForeground,
  });

  final List<String> tags;
  final void Function(String tag) onTap;
  final void Function(String tag) onLongPress;
  final int hiddenCount;
  final VoidCallback? onShowMore;
  final Color? accent;
  final Color? chipColor;
  final Color? chipForeground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chip = tagChipColors(colorScheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Tags', accent: accent ?? colorScheme.primary),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...tags.map(
              (tag) => _TagChip(
                tag: tag,
                onTap: () => onTap(tag),
                onLongPress: () => onLongPress(tag),
                color: chipColor ?? chip.background,
                foreground: chipForeground ?? chip.foreground,
              ),
            ),
            if (hiddenCount > 0)
              ActionChip(
                label: Text('+$hiddenCount'),
                backgroundColor: chipColor ?? chip.background,
                labelStyle: theme.textTheme.labelMedium?.copyWith(
                  color: chipForeground ?? chip.foreground,
                ),
                side: BorderSide.none,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onPressed: onShowMore,
              ),
          ],
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.tag,
    required this.onTap,
    required this.onLongPress,
    this.color,
    this.foreground,
  });

  final String tag;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Color? color;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chip = tagChipColors(colorScheme);

    return Semantics(
      button: true,
      label: tag,
      child: Material(
        color: color ?? chip.background,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            child: Text(
              tag,
              style: theme.textTheme.labelMedium?.copyWith(
                color: foreground ?? chip.foreground,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
