import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/saved_url.dart';
import '../../core/services/category_resolver.dart';
import 'category_chip.dart' show faviconUrl;

/// Card widget for displaying a saved URL entry.
class UrlCard extends StatelessWidget {
  final SavedUrl savedUrl;
  final VoidCallback? onTap;

  const UrlCard({
    super.key,
    required this.savedUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displaySourceName = CategoryResolver.displaySourceName(
      rawUrl: savedUrl.rawUrl,
      fallbackDomain: savedUrl.domain,
    );
    final normalizedCategories = savedUrl.effectiveCategories
      .map((item) => item.toLowerCase())
      .toSet();
    final visibleTags = savedUrl.tags
        .where((tag) => !normalizedCategories.contains(tag.toLowerCase()))
        .where((tag) => tag.toLowerCase() != displaySourceName.toLowerCase())
        .toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showActions(context),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: savedUrl.thumbnailUrl != null &&
                        savedUrl.thumbnailUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: savedUrl.thumbnailUrl!,
                        width: 86,
                        height: 86,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => _placeholderIcon(
                          colorScheme,
                          savedUrl.category,
                          savedUrl.categoryEmoji,
                        ),
                      )
                    : _placeholderIcon(
                        colorScheme,
                        savedUrl.category,
                        savedUrl.categoryEmoji,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      savedUrl.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Text(
                        displaySourceName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: visibleTags
                                .take(3)
                                .toList()
                                .asMap()
                                .entries
                                .map((entry) {
                                  final i = entry.key;
                                  final tag = entry.value;
                                  final bg = switch (i % 3) {
                                    0 => colorScheme.primaryContainer,
                                    1 => colorScheme.secondaryContainer,
                                    _ => colorScheme.tertiaryContainer,
                                  };
                                  final fg = switch (i % 3) {
                                    0 => colorScheme.onPrimaryContainer,
                                    1 => colorScheme.onSecondaryContainer,
                                    _ => colorScheme.onTertiaryContainer,
                                  };
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      tag,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: fg,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                })
                                .toList(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _timeAgo(savedUrl.savedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy link'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: savedUrl.rawUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Link copied'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(ctx);
                Share.share(savedUrl.rawUrl);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _placeholderIcon(
      ColorScheme colorScheme, String category, String emoji) {
    final fav = faviconUrl(category);
    if (fav != null) {
      return Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: CachedNetworkImage(
            imageUrl: fav,
            width: 42,
            height: 42,
            fit: BoxFit.contain,
            errorWidget: (_, _, _) =>
                Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
        ),
      );
    }
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 32)),
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}

