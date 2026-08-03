import 'package:flutter/material.dart';

/// A deliberately small Markdown renderer for trusted model prose.
/// Supports headings, unordered lists, bold, and italic emphasis without
/// introducing an HTML-capable document surface.
class LightweightMarkdownText extends StatelessWidget {
  const LightweightMarkdownText({
    super.key,
    required this.text,
    required this.baseStyle,
    this.selectable = true,
    this.maxLines,
  });

  final String text;
  final TextStyle baseStyle;
  final bool selectable;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final lineLimit = maxLines;
    if (lineLimit != null) {
      return Text(
        toPlainText(text),
        maxLines: lineLimit,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }

    final blocks = <Widget>[];
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) {
        if (blocks.isNotEmpty) blocks.add(const SizedBox(height: 10));
        continue;
      }

      final heading = RegExp(
        r'^#{1,6}(?:\s+|$)(.*)$',
      ).firstMatch(line.trimLeft());
      final bullet = RegExp(r'^\s*[-*](?:\s+|$)(.*)$').firstMatch(line);
      if (heading != null) {
        blocks.add(
          Padding(
            padding: EdgeInsets.only(top: blocks.isEmpty ? 0 : 8, bottom: 2),
            child: _richLine(
              TextSpan(
                style: baseStyle.copyWith(fontWeight: FontWeight.w700),
                children: _inlineSpans(heading.group(1)!, baseStyle),
              ),
            ),
          ),
        );
      } else if (bullet != null) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1, right: 9),
                  child: Text('•', style: baseStyle),
                ),
                Expanded(
                  child: _richLine(
                    TextSpan(
                      style: baseStyle,
                      children: _inlineSpans(bullet.group(1)!, baseStyle),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        blocks.add(
          _richLine(
            TextSpan(style: baseStyle, children: _inlineSpans(line, baseStyle)),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  Widget _richLine(TextSpan span) {
    return selectable ? SelectableText.rich(span) : Text.rich(span);
  }

  static String toPlainText(String markdown) {
    final lines = <String>[];
    for (final rawLine in markdown.split('\n')) {
      var line = rawLine.trimRight();
      final heading = RegExp(r'^\s*#{1,6}(?:\s+|$)(.*)$').firstMatch(line);
      final bullet = RegExp(r'^\s*[-*](?:\s+|$)(.*)$').firstMatch(line);
      if (heading != null) {
        line = heading.group(1) ?? '';
      } else if (bullet != null) {
        line = '• ${bullet.group(1) ?? ''}';
      }
      line = line
          .replaceAllMapped(
            RegExp(r'\*\*(.+?)\*\*'),
            (match) => match.group(1) ?? '',
          )
          .replaceAllMapped(
            RegExp(r'\*(.+?)\*'),
            (match) => match.group(1) ?? '',
          )
          .replaceAllMapped(RegExp(r'_(.+?)_'), (match) => match.group(1) ?? '')
          .replaceAll('**', '')
          .replaceAll('*', '');
      lines.add(line);
    }
    return lines.join('\n').trim();
  }

  static List<InlineSpan> _inlineSpans(String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final emphasis = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|_(.+?)_');
    var cursor = 0;
    for (final match in emphasis.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: _removeDanglingMarkers(text.substring(cursor, match.start)),
          ),
        );
      }
      final bold = match.group(1);
      spans.add(
        TextSpan(
          text: bold ?? match.group(2) ?? match.group(3) ?? '',
          style: baseStyle.copyWith(
            fontWeight: bold == null ? null : FontWeight.w700,
            fontStyle: bold == null ? FontStyle.italic : null,
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      final remaining = _removeDanglingMarkers(text.substring(cursor));
      if (remaining.isNotEmpty) spans.add(TextSpan(text: remaining));
    }
    return spans;
  }

  static String _removeDanglingMarkers(String value) {
    return value.replaceAll('**', '').replaceAll('*', '');
  }
}
