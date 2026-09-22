import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/saved_highlights_service.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/readable_surface.dart';

class ReaderSelectionArea extends StatefulWidget {
  const ReaderSelectionArea({super.key, required this.child});
  final Widget child;

  @override
  State<ReaderSelectionArea> createState() => _ReaderSelectionAreaState();
}

class _ReaderSelectionAreaState extends State<ReaderSelectionArea> {
  final _texts = <_ReaderSelectableTextState>{};

  @override
  Widget build(BuildContext context) => SelectionArea(
    contextMenuBuilder: (context, region) {
      final actions = [for (final text in _texts) ?text._highlightAction()];
      final items = List<ContextMenuButtonItem>.of(
        region.contextMenuButtonItems,
      );
      if (actions.isNotEmpty) {
        final removing = actions.every((action) => action.removing);
        items.add(
          ContextMenuButtonItem(
            label: removing
                ? context.l10n.removeHighlight
                : context.l10n.highlight,
            onPressed: () {
              region.hideToolbar();
              region.clearSelection();
              unawaited(_apply(actions, removing: removing));
            },
          ),
        );
      }
      return AdaptiveTextSelectionToolbar.buttonItems(
        anchors: region.contextMenuAnchors,
        buttonItems: items,
      );
    },
    child: widget.child,
  );

  Future<void> _apply(
    List<({bool removing, Future<void> Function() run})> actions, {
    required bool removing,
  }) async {
    for (final action in actions) {
      if (!mounted) return;
      if (action.removing == removing) await action.run();
    }
  }
}

class ReaderSelectableText extends StatefulWidget {
  const ReaderSelectableText({
    super.key,
    required this.text,
    required this.sectionKey,
    required this.highlights,
    required this.onAddHighlight,
    required this.onRemoveHighlight,
    this.style,
    this.textAlign,
    this.highlightColor,
    this.isHeading = false,
  });

  final String text;
  final String sectionKey;
  final List<SavedTextHighlight> highlights;
  final Future<void> Function(String selectedText, int startOffset)
  onAddHighlight;
  final Future<void> Function(SavedTextHighlight highlight) onRemoveHighlight;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Color? highlightColor;
  final bool isHeading;

  @override
  State<ReaderSelectableText> createState() => _ReaderSelectableTextState();
}

class _ReaderSelectableTextState extends State<ReaderSelectableText> {
  final _selectionNotifier = SelectionListenerNotifier();
  _ReaderSelectionAreaState? _area;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _area?._texts.remove(this);
    _area = context.findAncestorStateOfType<_ReaderSelectionAreaState>();
    _area?._texts.add(this);
  }

  @override
  void dispose() {
    _area?._texts.remove(this);
    _selectionNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final highlightColor = readableTintedSurface(
      base: colorScheme.surface,
      tint: widget.highlightColor ?? colorScheme.primary,
      foregrounds: [colorScheme.onSurface],
      opacity: widget.highlightColor == null ? .18 : 1,
    );
    final text = SelectionListener(
      selectionNotifier: _selectionNotifier,
      child: Semantics(
        header: widget.isHeading,
        child: Text.rich(
          TextSpan(
            children: _buildSpans(highlightColor, colorScheme.onSurface),
            style: widget.style,
          ),
          textAlign: widget.textAlign,
          semanticsLabel: widget.text,
        ),
      ),
    );
    return _area == null
        ? SelectionArea(contextMenuBuilder: _buildContextMenu, child: text)
        : text;
  }

  List<InlineSpan> _buildSpans(
    Color highlightColor,
    Color highlightForeground,
  ) {
    final ranges = SavedHighlightsCodec.rangesFor(
      sectionKey: widget.sectionKey,
      sourceText: widget.text,
      highlights: widget.highlights,
    );
    if (ranges.isEmpty) return [TextSpan(text: widget.text)];

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final range in ranges) {
      if (range.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, range.start)));
      }
      spans.add(
        TextSpan(
          text: widget.text.substring(range.start, range.end),
          style: TextStyle(
            backgroundColor: highlightColor,
            color: highlightForeground,
          ),
        ),
      );
      cursor = range.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }
    return spans;
  }

  ({bool removing, Future<void> Function() run})? _highlightAction() {
    final range = _selectionNotifier.selection.range;
    final start = range == null
        ? 0
        : (range.startOffset < range.endOffset
              ? range.startOffset
              : range.endOffset);
    final end = range == null
        ? 0
        : (range.startOffset > range.endOffset
              ? range.startOffset
              : range.endOffset);
    final rawSelection = start >= 0 && end <= widget.text.length
        ? widget.text.substring(start, end)
        : '';
    final selectedText = rawSelection.trim();
    final selectionStart =
        start + rawSelection.length - rawSelection.trimLeft().length;
    final selectedRange = SavedHighlightsCodec.selectionRange(
      widget.text,
      selectedText,
      startOffset: selectionStart,
    );
    final existing = SavedHighlightsCodec.intersectingHighlight(
      sectionKey: widget.sectionKey,
      sourceText: widget.text,
      selectedText: selectedText,
      highlights: widget.highlights,
      selectionStart: selectionStart,
    );
    if (selectedRange == null ||
        selectedRange.end - selectedRange.start >
            SavedHighlightsCodec.maxQuoteLength) {
      return null;
    }
    return (
      removing: existing != null,
      run: existing == null
          ? () => widget.onAddHighlight(selectedText, selectionStart)
          : () => widget.onRemoveHighlight(existing),
    );
  }

  Widget _buildContextMenu(BuildContext context, SelectableRegionState region) {
    final action = _highlightAction();
    final items = List<ContextMenuButtonItem>.of(region.contextMenuButtonItems);
    if (action != null) {
      items.add(
        ContextMenuButtonItem(
          label: action.removing
              ? context.l10n.removeHighlight
              : context.l10n.highlight,
          onPressed: () {
            region.hideToolbar();
            region.clearSelection();
            unawaited(action.run());
          },
        ),
      );
    }
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: region.contextMenuAnchors,
      buttonItems: items,
    );
  }
}
