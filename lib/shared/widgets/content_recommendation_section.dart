import 'package:flutter/material.dart';

import 'section_header.dart';

class ContentRecommendationSection<T> extends StatelessWidget {
  const ContentRecommendationSection({
    super.key,
    required this.title,
    required this.items,
    required this.itemBuilder,
    required this.accent,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<T> items;
  final Color accent;
  final Widget Function(BuildContext context, T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          accent: accent,
          emphasis: SectionHeaderEmphasis.secondary,
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!.trim(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 10),
        for (var i = 0; i < items.length; i++) ...[
          itemBuilder(context, items[i]),
          if (i != items.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}
