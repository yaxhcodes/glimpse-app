import 'package:flutter/material.dart';

import '../../core/services/transcript_enrichment_service.dart';
import '../../shared/theme/app_icons.dart';

class NotableItemCard extends StatelessWidget {
  const NotableItemCard({
    super.key,
    required this.item,
    required this.accent,
    this.compact = false,
  });

  final EnrichedNotableItem item;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final itemType = item.type.toLowerCase();
    final isQuote = itemType == 'quote';
    final isClaim = itemType == 'claim';
    final attribution = item.attribution?.trim() ?? '';
    final label = item.label?.trim() ?? '';
    final why = item.whyImportant?.trim() ?? '';
    final meta = [
      if (!isQuote && label.isNotEmpty && label != item.text) label,
      if (attribution.isNotEmpty) attribution,
      if (why.isNotEmpty) why,
    ].join(' · ');

    return Container(
      width: compact ? null : double.infinity,
      margin: EdgeInsets.only(bottom: compact ? 0 : 9),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      constraints: compact ? const BoxConstraints(minHeight: 68) : null,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      _iconFor(item),
                      size: isQuote || itemType == 'term' ? 18 : 16,
                      color: accent,
                    ),
                  ),
                ),
                TextSpan(text: item.text),
              ],
            ),
            style:
                (isClaim
                        ? theme.textTheme.bodyLarge
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                      height: 1.42,
                    ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              meta,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(EnrichedNotableItem item) {
    final type = item.type.trim().toLowerCase();
    final label = item.label?.trim().toLowerCase() ?? '';
    final descriptor = '$type $label';
    if (RegExp(r'\balbum\b').hasMatch(descriptor)) {
      return Icons.album_outlined;
    }
    if (RegExp(r'\b(song|track|music|artist|band)\b').hasMatch(descriptor)) {
      return Icons.music_note_rounded;
    }
    if (RegExp(r'\b(game|gaming)\b').hasMatch(descriptor)) {
      return Icons.sports_esports_outlined;
    }
    return switch (type) {
      'term' => AppIcons.termMentioned,
      'quote' => Icons.format_quote_rounded,
      'claim' => Icons.lightbulb_outline_rounded,
      'tool' || 'app' || 'website' => Icons.apps_rounded,
      'product' => Icons.shopping_bag_outlined,
      _ => Icons.bookmark_border_rounded,
    };
  }
}
