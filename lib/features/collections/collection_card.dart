import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/user_collection.dart';
import '../../shared/formatting.dart';
import '../../shared/widgets/selection_badge.dart';
import '../../shared/widgets/url_card.dart';
import 'collection_thumbnail_preview.dart';
import 'collection_visual.dart';
import 'collections_provider.dart';

class CollectionCard extends StatefulWidget {
  const CollectionCard({
    super.key,
    required this.summary,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectionStart,
    this.onSelectionToggle,
  });

  final CollectionSummary summary;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onSelectionStart;
  final VoidCallback? onSelectionToggle;

  @override
  State<CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends State<CollectionCard> {
  bool _pressed = false;
  bool _focused = false;

  UserCollection get collection => widget.summary.collection;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final visual = _resolveSummaryVisual(widget.summary);
    final linkText = formatLinkCount(widget.summary.linkCount);
    final latestSaveText = _latestSaveText(widget.summary);
    final semanticParts = [
      collection.name,
      linkText,
      if (widget.summary.lastAddedAt != null)
        'last added ${formatRelativeTime(widget.summary.lastAddedAt!)}',
    ];

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: semanticParts.join(', '),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              if (widget.selectionMode) {
                widget.onSelectionToggle?.call();
              } else {
                context.push('/collections/${collection.id}');
              }
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              if (widget.selectionMode) {
                widget.onSelectionToggle?.call();
              } else {
                widget.onSelectionStart?.call();
              }
            },
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onFocusChange: (value) => setState(() => _focused = value),
            borderRadius: BorderRadius.circular(26),
            splashColor: cs.primary.withValues(alpha: 0.08),
            highlightColor: cs.primary.withValues(alpha: 0.05),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? Color.alphaBlend(
                        cs.primary.withValues(alpha: 0.06),
                        cs.surfaceContainerLow,
                      )
                    : cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(26),
                border: widget.isSelected
                    ? Border.all(
                        color: cs.primary.withValues(alpha: 0.48),
                        width: 1.5,
                      )
                    : null,
                boxShadow: _focused
                    ? [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.10),
                          blurRadius: 24,
                          spreadRadius: -6,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CollectionVisual(style: visual, seed: collection.name),
                      if (widget.selectionMode)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: SelectionBadge(selected: widget.isSelected),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    collection.name,
                    style: tt.titleSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                      height: 1.18,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    linkText,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (latestSaveText != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      latestSaveText,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.68),
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _latestSaveText(CollectionSummary summary) {
    final lastAddedAt = summary.lastAddedAt;
    if (lastAddedAt == null) {
      // Empty collections already read "No links" on the count line above —
      // a second "No saves yet" line is redundant, so show nothing here.
      return null;
    }
    return 'Added · ${formatRelativeTime(lastAddedAt)}';
  }
}

class CollectionListCard extends StatefulWidget {
  const CollectionListCard({
    super.key,
    required this.summary,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectionStart,
    this.onSelectionToggle,
  });

  final CollectionSummary summary;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onSelectionStart;
  final VoidCallback? onSelectionToggle;

  @override
  State<CollectionListCard> createState() => _CollectionListCardState();
}

class _CollectionListCardState extends State<CollectionListCard> {
  bool _pressed = false;

  UserCollection get collection => widget.summary.collection;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final tt = Theme.of(context).textTheme;
    final visual = _resolveSummaryVisual(widget.summary);
    final linkText = formatLinkCount(widget.summary.linkCount);
    final description = collection.description?.trim();
    final subtitleText = description == null || description.isEmpty
        ? linkText
        : description;
    final latestSaveText = _latestSaveText(widget.summary);
    final selectedFill = Color.alphaBlend(
      cs.primary.withValues(alpha: 0.045),
      UrlCard.listCardFillColor(theme),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: widget.isSelected
          ? BorderSide(color: cs.primary.withValues(alpha: 0.48), width: 1.5)
          : BorderSide.none,
    );

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: [
        collection.name,
        if (description != null && description.isNotEmpty) description,
        linkText,
        if (widget.summary.lastAddedAt != null)
          'last added ${formatRelativeTime(widget.summary.lastAddedAt!)}',
      ].join(', '),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Material(
            color: widget.isSelected
                ? selectedFill
                : UrlCard.listCardFillColor(theme),
            elevation: widget.isSelected ? 2 : 0,
            shadowColor: widget.isSelected
                ? cs.shadow.withValues(alpha: 0.18)
                : Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                if (widget.selectionMode) {
                  widget.onSelectionToggle?.call();
                } else {
                  context.push('/collections/${collection.id}');
                }
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                if (widget.selectionMode) {
                  widget.onSelectionToggle?.call();
                } else {
                  widget.onSelectionStart?.call();
                }
              },
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              splashColor: cs.primary.withValues(alpha: 0.08),
              highlightColor: cs.primary.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CollectionVisual(
                          style: visual,
                          seed: collection.name,
                          size: 64,
                          iconSize: 28,
                        ),
                        if (widget.selectionMode)
                          Positioned(
                            top: -5,
                            right: -5,
                            child: SelectionBadge(selected: widget.isSelected),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            collection.name,
                            style: tt.titleSmall?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                              fontSize: (tt.titleSmall?.fontSize ?? 14) + 0.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitleText,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (latestSaveText != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              latestSaveText,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.78,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.summary.previewUrls.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      ExcludeSemantics(
                        child: CollectionThumbnailPreview(
                          key: ValueKey(
                            'collection-thumbnail-preview-${collection.id}',
                          ),
                          previewUrls: widget.summary.previewUrls,
                          linkCount: widget.summary.linkCount,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _latestSaveText(CollectionSummary summary) {
    final lastAddedAt = summary.lastAddedAt;
    if (lastAddedAt == null) {
      // Empty collections already read "No links" on the count line above —
      // a second "No saves yet" line is redundant, so show nothing here.
      return null;
    }
    return 'Added · ${formatRelativeTime(lastAddedAt)}';
  }
}

CollectionVisualStyle _resolveSummaryVisual(CollectionSummary summary) {
  final collection = summary.collection;
  final storedKey = collection.emoji.trim().toLowerCase();
  final key = storedKey == CollectionVisualStyle.fallback.key
      ? null
      : collection.emoji;
  return resolveCollectionVisualStyle(
    key,
    name: collection.name,
    description: [
      collection.description,
      summary.visualHint,
    ].whereType<String>().join(' '),
  );
}
