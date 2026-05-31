import 'package:flutter/material.dart';

import 'section_header.dart';

class TagGroup extends StatelessWidget {
  const TagGroup({
    super.key,
    required this.tags,
    required this.onDelete,
    required this.onAdd,
    this.hiddenCount = 0,
    this.onShowMore,
  });

  final List<String> tags;
  final void Function(String tag) onDelete;
  final VoidCallback onAdd;
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
                onDeleted: () => onDelete(tag),
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
            ActionChip(
              avatar: Icon(
                Icons.add_rounded,
                size: 16,
                color: colorScheme.onSecondaryContainer,
              ),
              label: const Text('Add tag'),
              backgroundColor: colorScheme.secondaryContainer,
              labelStyle: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
              side: BorderSide.none,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              onPressed: onAdd,
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
    required this.onDeleted,
  });

  final String tag;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InputChip(
      label: Text(tag),
      backgroundColor: colorScheme.secondaryContainer,
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: colorScheme.onSecondaryContainer,
        fontWeight: FontWeight.w500,
      ),
      deleteIconColor: colorScheme.onSecondaryContainer,
      side: BorderSide.none,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      onDeleted: onDeleted,
    );
  }
}
