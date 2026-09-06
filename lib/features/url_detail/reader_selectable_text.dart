import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/saved_highlights_service.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/readable_surface.dart';

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

  @override
  void dispose() {
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
    return SelectionArea(
      contextMenuBuilder: _buildContextMenu,
      child: SelectionListener(
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
      ),
    );
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

  Widget _buildContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
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
    final items = List<ContextMenuButtonItem>.of(
      selectableRegionState.contextMenuButtonItems,
    );
    if (selectedRange != null &&
        selectedRange.end - selectedRange.start <=
            SavedHighlightsCodec.maxQuoteLength) {
      final item = ContextMenuButtonItem(
        label: existing == null
            ? context.l10n.highlight
            : context.l10n.removeHighlight,
        onPressed: () {
          selectableRegionState.hideToolbar();
          selectableRegionState.clearSelection();
          if (existing == null) {
            unawaited(widget.onAddHighlight(selectedText, selectionStart));
          } else {
            unawaited(widget.onRemoveHighlight(existing));
          }
        },
      );
      final copyIndex = items.indexWhere(
        (button) => button.type == ContextMenuButtonType.copy,
      );
      items.insert(copyIndex < 0 ? 0 : copyIndex + 1, item);
    }
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegionState.contextMenuAnchors,
      buttonItems: items,
    );
  }
}
