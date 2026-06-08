import 'package:flutter/material.dart';

import 'section_header.dart';

class TagGroup extends StatelessWidget {
  const TagGroup({
    super.key,
    required this.tags,
    required this.onTap,
    required this.onLongPress,
    this.hiddenCount = 0,
    this.onShowMore,
  });

  final List<String> tags;
  final void Function(String tag) onTap;
  final void Function(String tag) onLongPress;
  final int hiddenCount;
  final VoidCallback? onShowMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Tags', accent: colorScheme.primary),
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
              ),
            ),
            if (hiddenCount > 0)
              ActionChip(
                label: Text('+$hiddenCount'),
                backgroundColor: colorScheme.secondaryContainer,
                labelStyle: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSecondaryContainer,
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
  });

  final String tag;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.secondaryContainer.withValues(alpha: 0.72),
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
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
