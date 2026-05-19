import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/user_collection.dart';
import '../../shared/formatting.dart';
import '../../shared/widgets/url_card.dart';
import 'collection_visual.dart';
import 'collections_provider.dart';

class CollectionCard extends StatefulWidget {
  const CollectionCard({
    super.key,
    required this.summary,
  });

  final CollectionSummary summary;

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
      label: semanticParts.join(', '),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/collections/${collection.id}'),
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
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(26),
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
                  CollectionVisual(style: visual, seed: collection.name),
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
      return summary.linkCount == 0 ? 'No saves yet' : null;
    }
    return 'Added · ${formatRelativeTime(lastAddedAt)}';
  }
}

class CollectionListCard extends StatefulWidget {
  const CollectionListCard({
    super.key,
    required this.summary,
  });

  final CollectionSummary summary;

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
    final latestSaveText = _latestSaveText(widget.summary);

    return Semantics(
      button: true,
      label: [
        collection.name,
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
            color: UrlCard.listCardFillColor(theme),
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shape: UrlCard.listCardShape(theme, radius: 14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/collections/${collection.id}'),
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
                    CollectionVisual(
                      style: visual,
                      seed: collection.name,
                      size: 64,
                      iconSize: 28,
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
                            linkText,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          if (latestSaveText != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              latestSaveText,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    cs.onSurfaceVariant.withValues(alpha: 0.78),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55),
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

  String? _latestSaveText(CollectionSummary summary) {
    final lastAddedAt = summary.lastAddedAt;
    if (lastAddedAt == null) {
      return summary.linkCount == 0 ? 'No saves yet' : null;
    }
    return 'Added · ${formatRelativeTime(lastAddedAt)}';
  }
}

CollectionVisualStyle _resolveSummaryVisual(CollectionSummary summary) {
  final collection = summary.collection;
  final storedKey = collection.emoji.trim().toLowerCase();
  final key =
      storedKey == CollectionVisualStyle.fallback.key ? null : collection.emoji;
  return resolveCollectionVisualStyle(
    key,
    name: collection.name,
    description: [
      collection.description,
      summary.visualHint,
    ].whereType<String>().join(' '),
  );
}
