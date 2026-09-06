import 'package:flutter/material.dart';

/// Adds visible hyphens only to Latin words wider than a title column.
/// Ordinary word wrapping and the original accessibility label are preserved.
class HyphenatedTitle extends StatelessWidget {
  const HyphenatedTitle({
    super.key,
    required this.text,
    required this.style,
    this.maxLines = 4,
  });

  final String text;
  final TextStyle style;
  final int maxLines;

  static final _words = RegExp(
    r'[A-Za-zÀ-ÖØ-öø-ÿ][A-Za-zÀ-ÖØ-öø-ÿ\u0300-\u036f]*',
  );

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        var displayText = text;
        if (width.isFinite && width > 0) {
          final painter = TextPainter(
            textDirection: direction,
            textScaler: scaler,
            locale: locale,
            maxLines: 1,
          );
          bool fits(String value) {
            painter.text = TextSpan(text: value, style: effectiveStyle);
            painter.layout();
            return painter.width <= width;
          }

          try {
            displayText = text.replaceAllMapped(_words, (match) {
              final word = match.group(0)!;
              if (fits(word)) return word;
              final letters = word.characters.toList(growable: false);
              final parts = <String>[];
              var start = 0;
              while (start < letters.length) {
                final remainder = letters.skip(start).join();
                if (fits(remainder)) {
                  parts.add(remainder);
                  break;
                }
                var lower = 2;
                var upper = letters.length - start - 2;
                var length = 0;
                while (lower <= upper) {
                  final middle = (lower + upper) ~/ 2;
                  if (fits(
                    '${letters.sublist(start, start + middle).join()}-',
                  )) {
                    length = middle;
                    lower = middle + 1;
                  } else {
                    upper = middle - 1;
                  }
                }
                if (length == 0) {
                  parts.add(remainder);
                  break;
                }
                parts.add(letters.sublist(start, start + length).join());
                start += length;
              }
              return parts.join('-\n');
            });
          } finally {
            painter.dispose();
          }
        }
        return Text(
          displayText,
          style: style,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          semanticsLabel: text,
        );
      },
    );
  }
}
