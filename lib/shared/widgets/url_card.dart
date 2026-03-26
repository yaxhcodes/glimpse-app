import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/saved_url.dart';
import '../../core/services/category_resolver.dart';
import 'category_chip.dart' show faviconUrl;

/// Animated skeleton placeholder that matches the UrlCard layout.
class UrlCardSkeleton extends StatefulWidget {
  const UrlCardSkeleton({super.key});

  @override
  State<UrlCardSkeleton> createState() => _UrlCardSkeletonState();
}

class _UrlCardSkeletonState extends State<UrlCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final shimmer = cs.onSurface.withValues(
          alpha: 0.08 + 0.10 * _anim.value,
        );
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(width: 64, height: 64, color: shimmer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(shimmer, height: 14, width: double.infinity),
                    const SizedBox(height: 6),
                    _ShimmerBox(shimmer, height: 14, width: 180),
                    const SizedBox(height: 8),
                    _ShimmerBox(shimmer, height: 12, width: 110),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _ShimmerBox(shimmer, height: 20, width: 60, radius: 10),
                        const SizedBox(width: 6),
                        _ShimmerBox(shimmer, height: 20, width: 80, radius: 10),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final Color color;
  final double height;
  final double width;
  final double radius;

  const _ShimmerBox(this.color,
      {required this.height, required this.width, this.radius = 5});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Card widget for displaying a saved URL entry.
class UrlCard extends StatefulWidget {
  final SavedUrl savedUrl;
  final VoidCallback? onTap;

  const UrlCard({
    super.key,
    required this.savedUrl,
    this.onTap,
  });

  @override
  State<UrlCard> createState() => _UrlCardState();
}

class _UrlCardState extends State<UrlCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    final displaySourceName = CategoryResolver.displaySourceName(
      rawUrl: widget.savedUrl.rawUrl,
      fallbackDomain: widget.savedUrl.domain,
    );
    final normalizedCategories = widget.savedUrl.effectiveCategories
        .map((item) => item.toLowerCase())
        .toSet();
    final visibleTags = widget.savedUrl.tags
        .where((tag) => !normalizedCategories.contains(tag.toLowerCase()))
        .where((tag) => tag.toLowerCase() != displaySourceName.toLowerCase())
        .toList();

    final hasThumbnail = widget.savedUrl.thumbnailUrl != null &&
        widget.savedUrl.thumbnailUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: cs.surfaceContainerLow,
        elevation: 0.5,
        shadowColor: cs.shadow.withValues(alpha: 0.3),
        surfaceTintColor: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap?.call();
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _showActions(context);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: hasThumbnail
                      ? CachedNetworkImage(
                          imageUrl: widget.savedUrl.thumbnailUrl!,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => _FallbackThumbnail(
                            category: widget.savedUrl.category,
                            emoji: widget.savedUrl.categoryEmoji,
                            domain: widget.savedUrl.domain,
                          ),
                        )
                      : _FallbackThumbnail(
                          category: widget.savedUrl.category,
                          emoji: widget.savedUrl.categoryEmoji,
                          domain: widget.savedUrl.domain,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.savedUrl.title,
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: cs.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$displaySourceName  ·  ${_timeAgo(widget.savedUrl.savedAt)}',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (visibleTags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: visibleTags.take(3).map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: cs.secondaryContainer.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSecondaryContainer,
                                  fontFamily: tt.labelSmall?.fontFamily,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy link'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: widget.savedUrl.rawUrl));
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
                Share.share(widget.savedUrl.rawUrl);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
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

class _FallbackThumbnail extends StatelessWidget {
  const _FallbackThumbnail({
    required this.category,
    required this.emoji,
    required this.domain,
  });

  final String category;
  final String emoji;
  final String domain;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fav = faviconUrl(category);
    if (fav != null) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: CachedNetworkImage(
            imageUrl: fav,
            width: 30,
            height: 30,
            fit: BoxFit.contain,
            errorWidget: (_, _, _) =>
                Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
        ),
      );
    }

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        domain.isNotEmpty ? domain[0].toUpperCase() : emoji,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
