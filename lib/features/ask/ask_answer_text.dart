import 'package:flutter/material.dart';

/// Small, non-HTML answer renderer. Citations resolve only through the supplied
/// references; model-generated URLs never become navigation targets.
class AskAnswerText extends StatelessWidget {
  const AskAnswerText({
    super.key,
    required this.text,
    required this.style,
    required this.onCitation,
    this.selectable = true,
  });
  final String text;
  final TextStyle style;
  final void Function(int)? onCitation;
  final bool selectable;

  List<InlineSpan> _spans(BuildContext context, String value) {
    final spans = <InlineSpan>[];
    // "[12]" and grouped "[4, 9]" render the same way: one small pill per
    // source, so a sentence never mixes bold brackets with plain ones.
    final pattern = RegExp(
      r'\[(\d+(?:\s*,\s*\d+)*)\]|\*\*([^*]+)\*\*|`([^`]+)`',
    );
    var offset = 0;
    for (final match in pattern.allMatches(value)) {
      if (match.start > offset) {
        spans.add(
          TextSpan(
            text: value
                .substring(offset, match.start)
                .replaceFirst(RegExp(r' +$'), ' '),
          ),
        );
      }
      if (match.group(1) != null && onCitation != null) {
        final indexes = match
            .group(1)!
            .split(',')
            .map((part) => int.parse(part.trim()));
        for (final index in indexes) {
          spans.add(_citation(context, index));
        }
      } else {
        spans.add(
          TextSpan(
            text: match.group(2) ?? match.group(3) ?? match.group(0),
            style: match.group(2) != null
                ? const TextStyle(fontWeight: FontWeight.w600)
                : null,
          ),
        );
      }
      offset = match.end;
    }
    if (offset < value.length) {
      spans.add(TextSpan(text: value.substring(offset)));
    }
    return spans;
  }

  InlineSpan _citation(BuildContext context, int index) {
    final cs = Theme.of(context).colorScheme;
    final size = (style.fontSize ?? 16) * 0.72;
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label: 'Source $index',
        onTap: () => onCitation!(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: Material(
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => onCitation!(index),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Text(
                  '$index',
                  style: style.copyWith(
                    fontSize: size,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: cs.onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(BuildContext context, String value, {bool heading = false}) =>
      Text.rich(
        TextSpan(children: _spans(context, value)),
        style: heading ? style.copyWith(fontWeight: FontWeight.w600) : style,
      );

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final children = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        children.add(const SizedBox(height: 10));
        continue;
      }
      if (line.contains('|') &&
          i + 1 < lines.length &&
          RegExp(r'^\|?\s*:?-{3,}').hasMatch(lines[i + 1].trim())) {
        final rows = <List<String>>[];
        List<String> cells(String row) => row
            .replaceAll(RegExp(r'^\||\|$'), '')
            .split('|')
            .map((s) => s.trim())
            .toList();
        rows.add(cells(line));
        i += 2;
        while (i < lines.length && lines[i].contains('|')) {
          rows.add(cells(lines[i].trim()));
          i++;
        }
        i--;
        final width = rows.first.length;
        children.add(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                children: [
                  for (var r = 0; r < rows.length; r++)
                    TableRow(
                      children: [
                        for (var c = 0; c < width; c++)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: _line(
                                context,
                                c < rows[r].length ? rows[r][c] : '',
                                heading: r == 0,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
        continue;
      }
      final heading = RegExp(r'^#{1,6}\s+').firstMatch(line);
      final bullet = RegExp(r'^[-*]\s+').firstMatch(line);
      children.add(
        Padding(
          padding: EdgeInsets.only(top: heading == null ? 2 : 10),
          child: _line(
            context,
            heading != null
                ? line.substring(heading.end)
                : bullet != null
                ? '• ${line.substring(bullet.end)}'
                : line,
            heading: heading != null,
          ),
        ),
      );
    }
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return selectable ? SelectionArea(child: content) : content;
  }
}
