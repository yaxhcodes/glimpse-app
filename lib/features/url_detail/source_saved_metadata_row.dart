import 'package:flutter/material.dart';

class SourceSavedMetadataRow extends StatelessWidget {
  const SourceSavedMetadataRow({
    super.key,
    required this.leading,
    required this.sourceName,
    required this.savedLabel,
    required this.exactDateVisible,
    required this.isRead,
    required this.sourceColor,
    required this.onSavedLabelTap,
    this.creatorLink,
  });

  final Widget leading;
  final String sourceName;
  final String savedLabel;
  final bool exactDateVisible;
  final bool isRead;
  final Color sourceColor;
  final VoidCallback onSavedLabelTap;
  final Widget? creatorLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final sourceAndTime = Row(
      children: [
        leading,
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            sourceName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: sourceColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '·',
            style: TextStyle(color: colorScheme.outline, fontSize: 13),
          ),
        ),
        Expanded(
          flex: 2,
          child: Semantics(
            button: true,
            label: exactDateVisible
                ? '$savedLabel. Show relative saved time'
                : '$savedLabel. Show exact saved date and time',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onSavedLabelTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  reverseDuration: const Duration(milliseconds: 150),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [...previousChildren, ?currentChild],
                    );
                  },
                  transitionBuilder: (transitionChild, animation) {
                    return ClipRect(
                      child: FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.04, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: transitionChild,
                        ),
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(exactDateVisible),
                    child: Text(
                      savedLabel,
                      key: const ValueKey('saved-timestamp-label'),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    final creator = creatorLink;
    if (creator == null) {
      return Row(
        children: [
          Expanded(child: sourceAndTime),
          const SizedBox(width: 8),
          _ReadStatePill(isRead: isRead),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sourceAndTime,
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: creator),
            ),
            const SizedBox(width: 8),
            _ReadStatePill(isRead: isRead),
          ],
        ),
      ],
    );
  }
}

class _ReadStatePill extends StatelessWidget {
  const _ReadStatePill({required this.isRead});

  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isRead ? 'Read' : 'Unread',
        key: const ValueKey('read-state-label'),
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
