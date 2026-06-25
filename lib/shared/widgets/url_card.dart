import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/saved_url.dart';
import '../../core/models/url_processing_status.dart';
import '../../core/services/category_resolver.dart';
import '../../core/services/tag_noise_filter.dart';
import '../../core/services/title_resolver.dart';
import '../../features/home/home_provider.dart';
import '../../features/url_detail/url_detail_provider.dart';
import 'expressive_tap_scale.dart';
import 'link_card_thumbnail.dart';
import 'tag_group.dart' show tagChipColors;

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

  const _ShimmerBox(
    this.color, {
    required this.height,
    required this.width,
    this.radius = 5,
  });

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
  final VoidCallback? onLongPress;
  final VoidCallback? onSelectionTap;
  final bool isPinned;
  final bool selectionMode;
  final bool isSelected;

  const UrlCard({
    super.key,
    required this.savedUrl,
    this.onTap,
    this.onLongPress,
    this.onSelectionTap,
    this.isPinned = false,
    this.selectionMode = false,
    this.isSelected = false,
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
    return RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
  }

  @override
  ConsumerState<UrlCard> createState() => _UrlCardState();
}

class _UrlCardState extends ConsumerState<UrlCard> {
  bool _retryingEnrichment = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final tagColors = tagChipColors(cs);
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

    final isProcessing =
        widget.savedUrl.isProcessingActive ||
        _isRecentlyEnriching(widget.savedUrl);
    final isProcessingFailed = widget.savedUrl.isProcessingFailed;
    final resolvedTitle = isProcessing
        ? _processingTitle(displaySourceName)
        : TitleResolver.resolveDetailTitle(
            widget.savedUrl,
            tagFrequency: tagFreq,
          );
    final chipData = (isProcessing || isProcessingFailed)
        ? (visible: <String>[], overflow: 0)
        : TagNoiseFilter.visibleTagsForCard(tagPool, tagFreq);

    final isRead = widget.savedUrl.openedAt != null;
    final isLight = theme.brightness == Brightness.light;
    final metaStyle = TextStyle(fontSize: 12, color: cs.outline);
    final selectedFill = Color.alphaBlend(
      cs.primary.withValues(alpha: 0.045),
      UrlCard.listCardFillColor(theme),
    );
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: widget.isSelected
          ? BorderSide(color: cs.primary.withValues(alpha: 0.45))
          : BorderSide.none,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ExpressiveTapScale(
        child: Material(
          color: widget.isSelected
              ? selectedFill
              : UrlCard.listCardFillColor(theme),
          elevation: widget.isSelected ? 2 : 0,
          shadowColor: widget.isSelected
              ? cs.shadow.withValues(alpha: 0.18)
              : Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shape: cardShape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              if (widget.selectionMode) {
                widget.onSelectionTap?.call();
              } else {
                widget.onTap?.call();
              }
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              if (widget.onLongPress != null) {
                widget.onLongPress?.call();
              } else if (!widget.selectionMode) {
                _showActions(context);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  widget.selectionMode
                      ? _SelectionThumbnailControl(
                          selected: widget.isSelected,
                          size: 64,
                          onTap: widget.onSelectionTap,
                        )
                      : LinkCardThumbnail.build(
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AnimatedOpacity(
                                opacity: (isRead && isLight) ? 0.45 : 1.0,
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  resolvedTitle,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: (tt.titleSmall ?? const TextStyle())
                                      .copyWith(
                                        fontWeight: FontWeight.w600,
                                        height: 1.25,
                                        fontSize:
                                            (tt.titleSmall?.fontSize ?? 14) +
                                            0.5,
                                        color: cs.onSurface,
                                      ),
                                ),
                              ),
                            ),
                            if (widget.isPinned) ...[
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.push_pin_rounded,
                                  size: 13,
                                  color: cs.primary.withValues(alpha: 0.68),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 0,
                          runSpacing: 2,
                          children: [
                            Text(displaySourceName, style: metaStyle),
                            Text(' · ', style: metaStyle),
                            Text(
                              UrlCard.timeAgoSaved(widget.savedUrl.savedAt),
                              style: metaStyle,
                            ),
                            Text(' · ', style: metaStyle),
                            Text(isRead ? 'Read' : 'Unread', style: metaStyle),
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
                                    color: tagColors.background,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: tagColors.foreground,
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
                                    color: tagColors.background,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '+${chipData.overflow}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: tagColors.foreground,
                                      fontFamily: tt.labelSmall?.fontFamily,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ] else if (isProcessing || isProcessingFailed) ...[
                          const SizedBox(height: 8),
                          _EnrichmentProgressPill(
                            sourceName: displaySourceName,
                            failed: isProcessingFailed,
                            retrying: _retryingEnrichment,
                            onRetry: isProcessingFailed
                                ? () => _retryEnrichment()
                                : null,
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
      ),
    );
  }

  bool _isRecentlyEnriching(SavedUrl url) {
    // A save with a definitive terminal status (READY/FAILED) is never
    // "enriching". The heuristics below exist only for legacy saves that
    // predate the processingStatus field; without this guard a non-AI save
    // (e.g. saved while out of free AI saves) with no summary would show a
    // spinner for 10 minutes despite being fully done.
    final status = url.processingStatus;
    if (status != null &&
        status.trim().isNotEmpty &&
        !UrlProcessingStatus.isActive(status)) {
      return false;
    }
    if ((url.enrichmentJson ?? '').trim().isNotEmpty) return false;
    if ((url.summary ?? '').trim().isNotEmpty) return false;
    if (DateTime.now().difference(url.savedAt) > const Duration(minutes: 10)) {
      return false;
    }
    if (TitleResolver.isLowSignalTitle(url.title, domain: url.domain)) {
      return true;
    }
    final lowerTitle = url.title.trim().toLowerCase();
    if (const {'social', 'web', 'link', 'video', 'reel'}.contains(lowerTitle)) {
      return true;
    }
    final noisyTags = {'social', 'instagram', 'youtube', 'tiktok', 'video'};
    return url.tags.any((tag) => noisyTags.contains(tag.trim().toLowerCase()));
  }

  String _processingTitle(String sourceName) {
    final source = sourceName.trim().isEmpty ? 'link' : sourceName.trim();
    if (source.toLowerCase() == 'instagram') return 'Reading Instagram reel';
    if (source.toLowerCase() == 'youtube') return 'Reading YouTube video';
    if (source.toLowerCase() == 'tiktok') return 'Reading TikTok video';
    return 'Reading $source';
  }

  Future<void> _retryEnrichment() async {
    if (_retryingEnrichment) return;
    setState(() => _retryingEnrichment = true);
    final success = await ref
        .read(urlDetailNotifierProvider.notifier)
        .retryEnrichment(widget.savedUrl.id);
    if (!mounted) return;
    setState(() => _retryingEnrichment = false);
    ref.invalidate(urlStreamProvider);
    ref.invalidate(categoriesProvider);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(success ? 'Retrying enrichment' : 'Could not retry'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
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
              title: const Text('Copy Link'),
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
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('Open Original'),
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.tryParse(widget.savedUrl.rawUrl);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _EnrichmentProgressPill extends StatelessWidget {
  const _EnrichmentProgressPill({
    required this.sourceName,
    required this.failed,
    required this.retrying,
    this.onRetry,
  });

  final String sourceName;
  final bool failed;
  final bool retrying;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final label = failed
        ? 'Couldn\'t finish enrichment'
        : sourceName.trim().isEmpty
        ? 'Enriching save'
        : 'Enriching ${sourceName.trim()} save';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: (failed ? cs.errorContainer : cs.primaryContainer).withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (failed ? cs.error : cs.primary).withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          failed
              ? Icon(Icons.error_outline_rounded, size: 14, color: cs.error)
              : SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: cs.primary,
                  ),
                ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: failed ? cs.onErrorContainer : cs.onPrimaryContainer,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
          if (failed && onRetry != null) ...[
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: retrying ? null : onRetry,
              icon: retrying
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.error,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: cs.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectionThumbnailControl extends StatelessWidget {
  const _SelectionThumbnailControl({
    required this.selected,
    required this.size,
    required this.onTap,
  });

  final bool selected;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? 'Deselect item' : 'Select item',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: AnimatedScale(
              scale: selected ? 1 : 0.84,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? cs.primary : Colors.transparent,
                  border: Border.all(
                    color: selected ? cs.primary : cs.outline,
                    width: selected ? 0 : 1.6,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check_rounded, size: 20, color: cs.onPrimary)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
