import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/models/saved_url.dart';
import '../../core/services/category_resolver.dart';
import '../../core/services/tag_noise_filter.dart';
import '../../core/services/title_resolver.dart';
import '../../features/home/home_provider.dart';
import 'link_card_thumbnail.dart';

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
        final theme = Theme.of(context);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          padding: const EdgeInsets.all(14),
          decoration: ShapeDecoration(
            color: UrlCard.listCardFillColor(theme),
            shape: UrlCard.listCardShape(theme, radius: 14),
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
                    _ShimmerBox(shimmer, height: 12, width: 140),
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
class UrlCard extends ConsumerStatefulWidget {
  final SavedUrl savedUrl;
  final VoidCallback? onTap;

  const UrlCard({
    super.key,
    required this.savedUrl,
    this.onTap,
  });

  /// Relative time for the source · time row (shared with other link cards).
  static String timeAgoSaved(DateTime savedAt) {
    final diff = DateTime.now().difference(savedAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  /// Shared with search / notification list rows: neutral light cards, tinted dark.
  static Color listCardFillColor(ThemeData theme) {
    final cs = theme.colorScheme;
    return cs.surfaceContainerLow;
  }

  static ShapeBorder listCardShape(ThemeData _, {double radius = 14}) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
  }

  @override
  ConsumerState<UrlCard> createState() => _UrlCardState();
}

class _UrlCardState extends ConsumerState<UrlCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final tagFreq = ref.watch(tagOccurrenceMapProvider);

    final displaySourceName = CategoryResolver.displaySourceName(
      rawUrl: widget.savedUrl.rawUrl,
      fallbackDomain: widget.savedUrl.domain,
    );
    final normalizedCategories = widget.savedUrl.effectiveCategories
        .map((item) => item.toLowerCase())
        .toSet();
    final tagPool = widget.savedUrl.tags
        .where((tag) => !normalizedCategories.contains(tag.toLowerCase()))
        .where((tag) => tag.toLowerCase() != displaySourceName.toLowerCase())
        .toList();

    final resolvedTitle = TitleResolver.formatForCompactCard(
      widget.savedUrl,
      TitleResolver.collapseWhitespace(
        TitleResolver.resolve(
          widget.savedUrl,
          tagFrequency: tagFreq,
        ),
      ),
    );
    final chipData = TagNoiseFilter.visibleTagsForCard(tagPool, tagFreq);

    final isRead = widget.savedUrl.openedAt != null;
    final isLight = theme.brightness == Brightness.light;
    final metaStyle = TextStyle(fontSize: 12, color: cs.outline);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: UrlCard.listCardFillColor(theme),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: UrlCard.listCardShape(theme, radius: 14),
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
                LinkCardThumbnail.build(
                  url: widget.savedUrl,
                  isRead: isRead,
                  context: context,
                  size: 64,
                  borderRadius: 10,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedOpacity(
                        opacity: (isRead && isLight) ? 0.45 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          resolvedTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: (tt.titleSmall ?? const TextStyle()).copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            fontSize: (tt.titleSmall?.fontSize ?? 14) + 0.5,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(displaySourceName, style: metaStyle),
                          Text(' · ', style: metaStyle),
                          Text(
                            UrlCard.timeAgoSaved(widget.savedUrl.savedAt),
                            style: metaStyle,
                          ),
                        ],
                      ),
if (chipData.visible.isNotEmpty ||
                           chipData.overflow > 0) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 3,
                          children: [
                            ...chipData.visible.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.secondaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSecondaryContainer,
                                    fontFamily: tt.labelSmall?.fontFamily,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              );
                            }),
                            if (chipData.overflow > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.secondaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '+${chipData.overflow}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSecondaryContainer,
                                    fontFamily: tt.labelSmall?.fontFamily,
                                  ),
                                ),
                              ),
                          ],
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
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Link copied'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 3),
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
}
