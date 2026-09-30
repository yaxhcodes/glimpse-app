import '../theme/app_shapes.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/l10n.dart';
import '../../core/models/saved_url.dart';
import '../../core/models/url_processing_status.dart';
import '../../core/services/category_resolver.dart';
import '../../core/services/title_resolver.dart';
import '../../core/services/demo_seed_service.dart';
import '../../features/home/home_provider.dart';
import 'card_open_transition.dart';
import '../../features/url_detail/url_detail_provider.dart'
    show UrlDetailSeed, retryingUrlIdsProvider;
import 'expressive_tap_scale.dart';
import 'expressive_loading_indicator.dart';
import 'link_card_thumbnail.dart';
import 'selection_badge.dart';
import 'url_processing_presentation.dart';
import 'package:glimpse/shared/theme/app_icons.dart';
import '../../core/services/app_haptics.dart';

/// Card widget for displaying a saved URL entry.
class UrlCard extends ConsumerStatefulWidget {
  final SavedUrl savedUrl;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSelectionTap;
  final bool isPinned;
  final bool selectionMode;
  final bool isSelected;
  final Map<String, int>? tagFrequency;
  final EdgeInsetsGeometry contentPadding;

  /// Off inside a source's own page, where every row would repeat it.
  final bool showSourceName;

  const UrlCard({
    super.key,
    required this.savedUrl,
    this.onTap,
    this.onLongPress,
    this.onSelectionTap,
    this.isPinned = false,
    this.selectionMode = false,
    this.isSelected = false,
    this.tagFrequency,
    this.contentPadding = const EdgeInsets.all(12),
    this.showSourceName = true,
  });

  /// Relative time for the source · time row (shared with other link cards).
  static String timeAgoSaved(BuildContext context, DateTime savedAt) {
    final strings = context.l10n;
    final diff = clock.now().difference(savedAt);
    if (diff.inMinutes < 1) return strings.justNow;
    if (diff.inMinutes < 60) return strings.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return strings.hoursAgo(diff.inHours);
    if (diff.inDays == 1) return strings.yesterday;
    if (diff.inDays < 7) return strings.daysAgo(diff.inDays);
    if (diff.inDays < 30) return strings.weeksAgo((diff.inDays / 7).floor());
    if (diff.inDays < 365) {
      return strings.monthsAgo((diff.inDays / 30).floor());
    }
    return strings.yearsAgo((diff.inDays / 365).floor());
  }

  /// The list thumbnail's side. Details shows the thumbnail decoded at this
  /// size while its own larger image loads, so the flight never goes blank.
  static const double thumbnailSize = 56;

  /// Shared with search / notification list rows: neutral light cards, tinted dark.
  static Color listCardFillColor(ThemeData theme) {
    final cs = theme.colorScheme;
    return cs.surfaceContainerLow;
  }

  static ShapeBorder listCardShape(
    ThemeData _, {
    double radius = AppShapes.cornerRadius,
  }) {
    return RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
  }

  @override
  ConsumerState<UrlCard> createState() => _UrlCardState();
}

class _UrlCardState extends ConsumerState<UrlCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.l10n;
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final tagFrequency = widget.tagFrequency;
    final Map<String, int> tagFreq =
        tagFrequency ?? ref.watch(tagOccurrenceMapProvider);

    final displaySourceName = CategoryResolver.displaySourceName(
      rawUrl: widget.savedUrl.rawUrl,
      fallbackDomain: widget.savedUrl.domain,
    );

    // Every list shows a save the way Home does: title, source and time, no
    // tag chips and no retry. Fixing a save's enrichment lives in Details.
    final retrying = ref.watch(
      retryingUrlIdsProvider.select((ids) => ids.contains(widget.savedUrl.id)),
    );
    final isProcessing =
        retrying ||
        widget.savedUrl.isProcessingActive ||
        _isRecentlyEnriching(widget.savedUrl);
    final isProcessingFailed = widget.savedUrl.isProcessingFailed;
    final processingPresentation = isProcessing
        ? UrlProcessingPresentation.fromStatus(
            retrying
                ? UrlProcessingStatus.retrying
                : widget.savedUrl.processingStatus,
            sourceName: displaySourceName,
            strings: strings,
          )
        : null;
    final resolvedTitle =
        processingPresentation?.headline ??
        TitleResolver.resolveDetailTitle(
          widget.savedUrl,
          tagFrequency: tagFreq,
        );
    final notePreview = widget.savedUrl.notePreview;

    final isRead = widget.savedUrl.openedAt != null;
    // onSurfaceVariant keeps metadata legible on cards in both themes
    // (outline, a border colour, was ~3:1).
    final metaStyle = TextStyle(fontSize: 12, color: cs.onSurfaceVariant);
    // A save in progress wears exactly the finished card's shape: same title
    // style and height, so nothing jumps when the real title lands.
    final cardTitleStyle = (tt.titleSmall ?? const TextStyle()).copyWith(
      // Medium: regular read as too faint beside the source line, semibold
      // as shouting.
      fontWeight: FontWeight.w500,
      height: 1.3,
      letterSpacing: -0.1,
      // Read saves dim slightly, the same in light and dark themes.
      color: isRead && processingPresentation == null
          ? cs.onSurface.withValues(alpha: 0.78)
          : cs.onSurface,
    );
    final shimmerProcessingText =
        processingPresentation != null && !processingPresentation.failed;
    final selectedFill = Color.alphaBlend(
      cs.primary.withValues(alpha: 0.045),
      UrlCard.listCardFillColor(theme),
    );
    final cardShape = RoundedRectangleBorder(
      borderRadius: AppShapes.borderRadius,
      side: widget.isSelected
          ? BorderSide(color: cs.primary.withValues(alpha: 0.45))
          : BorderSide.none,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: CardOpenOrigin(
        openTag: CardOpenOrigin.urlTag(widget.savedUrl.id),
        borderRadius: AppShapes.cornerRadius,
        color: widget.isSelected
            ? selectedFill
            : UrlCard.listCardFillColor(theme),
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
                AppHaptics.play(AppHaptics.tap);
                if (widget.selectionMode) {
                  widget.onSelectionTap?.call();
                } else {
                  UrlDetailSeed.offer(widget.savedUrl);
                  widget.onTap?.call();
                }
              },
              onLongPress: () {
                AppHaptics.play(AppHaptics.hold);
                if (widget.onLongPress != null) {
                  widget.onLongPress?.call();
                } else if (!widget.selectionMode) {
                  _showActions(context);
                }
              },
              child: Padding(
                padding: widget.contentPadding,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    widget.selectionMode
                        ? _SelectionThumbnail(
                            selected: widget.isSelected,
                            size: 56,
                            child: LinkCardThumbnail.build(
                              url: widget.savedUrl,
                              isRead: isRead,
                              context: context,
                              size: 56,
                              borderRadius: 10,
                            ),
                          )
                        : Stack(
                            clipBehavior: Clip.none,
                            children: [
                              LinkCardThumbnail.build(
                                url: widget.savedUrl,
                                isRead: isRead,
                                context: context,
                                size: UrlCard.thumbnailSize,
                                borderRadius: 10,
                              ),
                              // Unread sits on the thumbnail's corner like a
                              // badge, keeping the text lines clean.
                              if (!isRead &&
                                  !isProcessing &&
                                  !isProcessingFailed)
                                Positioned(
                                  top: -3,
                                  right: -3,
                                  child: _UnreadDot(
                                    color: cs.primary,
                                    ring: UrlCard.listCardFillColor(
                                      Theme.of(context),
                                    ),
                                    label: context.l10n.unread,
                                  ),
                                ),
                            ],
                          ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (DemoSeedService.isDemoUrl(widget.savedUrl.rawUrl))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                context.l10n.obExample,
                                style: tt.labelSmall?.copyWith(
                                  color: cs.primary,
                                ),
                              ),
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                // Each stage, then the real title, fades in
                                // over the last.
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 280),
                                  layoutBuilder: (current, previous) => Stack(
                                    alignment: AlignmentDirectional.topStart,
                                    children: [...previous, ?current],
                                  ),
                                  child: shimmerProcessingText
                                      ? Semantics(
                                          key: ValueKey('stage:$resolvedTitle'),
                                          liveRegion: true,
                                          label: processingPresentation.detail,
                                          child: _SubtleTextShimmer(
                                            text: resolvedTitle,
                                            style: cardTitleStyle,
                                            maxLines: 3,
                                          ),
                                        )
                                      : Text(
                                          resolvedTitle,
                                          key: ValueKey('title:$resolvedTitle'),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: cardTitleStyle,
                                        ),
                                ),
                              ),
                              if (widget.isPinned) ...[
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Icon(
                                    AppIcons.pinFilled,
                                    size: 13,
                                    color: cs.primary.withValues(alpha: 0.68),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 0,
                                  runSpacing: 2,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (widget.showSourceName) ...[
                                      Text(displaySourceName, style: metaStyle),
                                      Text(' · ', style: metaStyle),
                                    ],
                                    Text(
                                      UrlCard.timeAgoSaved(
                                        context,
                                        widget.savedUrl.savedAt,
                                      ),
                                      style: metaStyle,
                                    ),
                                    // The save is safe; this only says the
                                    // summary didn't come. Retry is in Details.
                                    if (isProcessingFailed &&
                                        !isProcessing) ...[
                                      Text(' · ', style: metaStyle),
                                      Text(
                                        strings.processingFailedShort,
                                        style: metaStyle.copyWith(
                                          color: cs.error.withValues(
                                            alpha: 0.85,
                                          ),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (isProcessing) ...[
                                const SizedBox(width: 8),
                                Semantics(
                                  label: context.l10n.enriching,
                                  child: ExpressiveLoadingIndicator(
                                    size: 14,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (notePreview != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                AppIcon(
                                  widget.savedUrl.notePreviewIsAsk
                                      ? AppIcons.sparkle
                                      : AppIcons.note,
                                  size: 13,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    notePreview,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tt.bodySmall?.copyWith(
                                      fontSize: 11.5,
                                      height: 1.25,
                                      color: cs.onSurfaceVariant.withValues(
                                        alpha: 0.82,
                                      ),
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

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.copy),
              title: Text(context.l10n.copyLink),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: widget.savedUrl.rawUrl));
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.linkCopied),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                    ),
                  );
              },
            ),
            ListTile(
              leading: const Icon(AppIcons.share),
              title: Text(context.l10n.share),
              onTap: () {
                Navigator.pop(ctx);
                Share.share(widget.savedUrl.rawUrl);
              },
            ),
            ListTile(
              leading: const Icon(AppIcons.externalLink),
              title: Text(context.l10n.openOriginal),
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

class _SubtleTextShimmer extends StatelessWidget {
  const _SubtleTextShimmer({
    required this.text,
    required this.style,
    required this.maxLines,
  });

  final String text;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations || media.accessibleNavigation;
    if (reduceMotion) return _text();

    final theme = Theme.of(context);
    final textColor = style.color ?? theme.colorScheme.onSurface;
    final baseColor = Color.alphaBlend(
      textColor.withValues(alpha: 0.72),
      theme.colorScheme.surface,
    );

    return Shimmer.fromColors(
      period: const Duration(milliseconds: 1800),
      baseColor: baseColor,
      highlightColor: textColor,
      child: _text(style.copyWith(color: Colors.white)),
    );
  }

  Widget _text([TextStyle? resolvedStyle]) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: resolvedStyle ?? style,
    );
  }
}

class _SelectionThumbnail extends StatelessWidget {
  const _SelectionThumbnail({
    required this.selected,
    required this.size,
    required this.child,
  });

  final bool selected;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      label: selected ? 'Deselect item' : 'Select item',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: KeyedSubtree(
                key: const ValueKey('url-card-selection-thumbnail'),
                child: child,
              ),
            ),
            Positioned(
              top: -4,
              right: -4,
              child: SelectionBadge(selected: selected),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small accent dot marking an unopened save. Replaces the repeated
/// "Unread" word: status should be glanceable, not read.
class _UnreadDot extends StatelessWidget {
  const _UnreadDot({
    required this.color,
    required this.ring,
    required this.label,
  });

  final Color color;
  final Color ring;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: ring, width: 2),
        ),
      ),
    );
  }
}
