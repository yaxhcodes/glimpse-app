import 'package:flutter/material.dart';

import '../../core/services/transcript_enrichment_service.dart';
import '../../shared/theme/app_icons.dart';

class NotableItemCard extends StatelessWidget {
  const NotableItemCard({
    super.key,
    required this.item,
    required this.accent,
    this.compact = false,
    this.onTap,
    this.actionIcon = Icons.open_in_new_rounded,
    this.actionLabel,
    this.actionText,
  });

  final EnrichedNotableItem item;
  final Color accent;
  final bool compact;
  final VoidCallback? onTap;
  final IconData actionIcon;
  final String? actionLabel;
  final String? actionText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final itemType = item.type.toLowerCase();
    final websiteUri = item.websiteUri;
    if (itemType == 'website' && websiteUri != null) {
      return _buildWebsiteCard(
        uri: websiteUri,
        theme: theme,
        colorScheme: colorScheme,
      );
    }

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

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 0 : 9),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: compact ? null : double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            constraints: compact ? const BoxConstraints(minHeight: 68) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text.rich(
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
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (actionText?.isNotEmpty == true) ...[
                              Text(
                                actionText!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Icon(
                              actionIcon,
                              size: 18,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.58,
                              ),
                              semanticLabel: actionLabel,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
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
          ),
        ),
      ),
    );
  }

  Widget _buildWebsiteCard({
    required Uri uri,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final label = item.label?.trim() ?? '';
    final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
    final hasFriendlyLabel =
        label.isNotEmpty &&
        !label.contains('://') &&
        !label.startsWith('www.');
    final title = hasFriendlyLabel ? label : host;
    final attribution = item.attribution?.trim() ?? '';
    final why = item.whyImportant?.trim() ?? '';
    final description = [
      if (attribution.isNotEmpty && attribution != title) attribution,
      if (why.isNotEmpty) why,
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 0 : 9),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 13, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.language_rounded, size: 20, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if (title != host) ...[
                        const SizedBox(height: 3),
                        Text(
                          host,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      actionIcon,
                      size: 18,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.58,
                      ),
                      semanticLabel: actionLabel,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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
    if (item.isMusicItem) {
      return Icons.music_note_rounded;
    }
    if (RegExp(r'\b(game|gaming)\b').hasMatch(descriptor)) {
      return Icons.sports_esports_outlined;
    }
    return switch (type) {
      'term' => AppIcons.termMentioned,
      'quote' => Icons.format_quote_rounded,
      'claim' => Icons.lightbulb_outline_rounded,
      'website' => Icons.language_rounded,
      'tool' || 'app' => Icons.apps_rounded,
      'product' => Icons.shopping_bag_outlined,
      _ => Icons.bookmark_border_rounded,
    };
  }
}
