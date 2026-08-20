import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/l10n.dart';
import '../../core/models/saved_url.dart';
import '../../core/models/url_processing_status.dart';
import '../../core/providers/usage_providers.dart';
import '../../core/services/category_resolver.dart';
import '../../core/services/saved_url_enrichment_state.dart';
import '../../core/services/tag_noise_filter.dart';
import '../../core/services/title_resolver.dart';
import '../../features/home/home_provider.dart';
import '../../features/url_detail/url_detail_provider.dart';
import 'expressive_tap_scale.dart';
import 'expressive_loading_indicator.dart';
import 'enrichment_retry_button.dart';
import 'link_card_thumbnail.dart';
import 'selection_badge.dart';
import 'tag_group.dart' show tagChipColors;
import 'url_processing_presentation.dart';

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
  });

  /// Relative time for the source · time row (shared with other link cards).
  static String timeAgoSaved(BuildContext context, DateTime savedAt) {
    final strings = context.l10n;
    final diff = DateTime.now().difference(savedAt);
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
    final tagFrequency = widget.tagFrequency;
    final Map<String, int> tagFreq =
        tagFrequency ?? ref.watch(tagOccurrenceMapProvider);

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
    final showEnrichmentRetry =
        !widget.selectionMode &&
        SavedUrlEnrichmentState.shouldOfferRetry(
          widget.savedUrl,
          hasAiSaveAccess: ref.watch(aiSaveAvailableProvider),
        );
    final processingPresentation = isProcessing || isProcessingFailed
        ? UrlProcessingPresentation.fromStatus(
            _retryingEnrichment
                ? UrlProcessingStatus.retrying
                : widget.savedUrl.processingStatus,
            sourceName: displaySourceName,
          )
        : null;
    final resolvedTitle =
        processingPresentation?.headline ??
        TitleResolver.resolveDetailTitle(
          widget.savedUrl,
          tagFrequency: tagFreq,
        );
    final chipData = (isProcessing || isProcessingFailed)
        ? (visible: <String>[], overflow: 0)
        : TagNoiseFilter.visibleTagsForCard(tagPool, tagFreq);
    final notePreview = widget.savedUrl.notePreview;

    final isRead = widget.savedUrl.openedAt != null;
    final isLight = theme.brightness == Brightness.light;
    final metaStyle = TextStyle(fontSize: 12, color: cs.outline);
    final baseTitleStyle =
        (processingPresentation != null ? tt.titleMedium : tt.titleSmall) ??
        const TextStyle();
    final cardTitleStyle = baseTitleStyle.copyWith(
      fontWeight: FontWeight.w600,
      height: processingPresentation != null ? 1.2 : 1.25,
      fontSize: processingPresentation == null
          ? (tt.titleSmall?.fontSize ?? 14) + 0.5
          : baseTitleStyle.fontSize,
      color: cs.onSurface,
    );
    final shimmerProcessingText =
        processingPresentation != null && !processingPresentation.failed;
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      : LinkCardThumbnail.build(
                          url: widget.savedUrl,
                          isRead: isRead,
                          context: context,
                          size: 56,
                          borderRadius: 10,
                        ),
                  const SizedBox(width: 12),
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
                                child: shimmerProcessingText
                                    ? _SubtleTextShimmer(
                                        text: resolvedTitle,
                                        style: cardTitleStyle,
                                        maxLines: 3,
                                      )
                                    : Text(
                                        resolvedTitle,
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
                                  Icons.push_pin_rounded,
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
                                children: [
                                  Text(displaySourceName, style: metaStyle),
                                  Text(' · ', style: metaStyle),
                                  Text(
                                    UrlCard.timeAgoSaved(
                                      context,
                                      widget.savedUrl.savedAt,
                                    ),
                                    style: metaStyle,
                                  ),
                                  Text(' · ', style: metaStyle),
                                  Text(
                                    _retryingEnrichment
                                        ? context.l10n.retrying
                                        : isProcessing
                                        ? context.l10n.processing
                                        : isProcessingFailed
                                        ? context.l10n.needsAttention
                                        : isRead
                                        ? context.l10n.read
                                        : context.l10n.unread,
                                    style: metaStyle,
                                  ),
                                ],
                              ),
                            ),
                            if (showEnrichmentRetry && !isProcessingFailed) ...[
                              const SizedBox(width: 4),
                              EnrichmentRetryButton(
                                retrying: _retryingEnrichment,
                                onPressed: _retryEnrichment,
                              ),
                            ],
                          ],
                        ),
                        if (notePreview != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                widget.savedUrl.notePreviewIsAsk
                                    ? Icons.auto_awesome_rounded
                                    : Icons.sticky_note_2_outlined,
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
                          _ProcessingStatusPanel(
                            presentation: processingPresentation!,
                            retrying: _retryingEnrichment,
                            onRetry: isProcessingFailed && showEnrichmentRetry
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
          content: Text(
            success
                ? context.l10n.enrichmentComplete
                : context.l10n.couldNotEnrichSave,
          ),
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
              leading: const Icon(Icons.share_outlined),
              title: Text(context.l10n.share),
              onTap: () {
                Navigator.pop(ctx);
                Share.share(widget.savedUrl.rawUrl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
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

class _ProcessingStatusPanel extends StatelessWidget {
  const _ProcessingStatusPanel({
    required this.presentation,
    required this.retrying,
    this.onRetry,
  });

  final UrlProcessingPresentation presentation;
  final bool retrying;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final failed = presentation.failed;
    final accent = failed ? cs.error : cs.primary;
    final foreground = failed ? cs.onErrorContainer : cs.onSurfaceVariant;

    return Semantics(
      liveRegion: true,
      label: presentation.detail,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
        decoration: BoxDecoration(
          color: (failed ? cs.errorContainer : cs.surfaceContainerHighest)
              .withValues(alpha: failed ? 0.5 : 0.55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            if (failed) ...[
              Icon(Icons.error_outline_rounded, size: 15, color: accent),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: failed
                  ? Text(
                      presentation.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        letterSpacing: 0.1,
                      ),
                    )
                  : _SubtleTextShimmer(
                      text: presentation.detail,
                      style:
                          theme.textTheme.labelMedium?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                            letterSpacing: 0.1,
                          ) ??
                          TextStyle(color: foreground),
                      maxLines: 2,
                    ),
            ),
            if (failed && onRetry != null) ...[
              const SizedBox(width: 4),
              TextButton(
                onPressed: retrying ? null : onRetry,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: accent,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: retrying
                    ? SizedBox(
                        width: 13,
                        height: 13,
                        child: ExpressiveLoadingIndicator(
                          size: 13,
                          color: accent,
                        ),
                      )
                    : Text(context.l10n.retry),
              ),
            ],
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
