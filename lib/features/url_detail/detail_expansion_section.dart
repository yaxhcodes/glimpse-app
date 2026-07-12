import 'package:flutter/material.dart';

List<String> splitTranscriptParagraphs(String raw) {
  final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  if (normalized.isEmpty) return const [];

  final existingParagraphs = normalized
      .split(RegExp(r'\n\s*\n+'))
      .map((paragraph) => paragraph.trim())
      .where((paragraph) => paragraph.isNotEmpty)
      .toList();
  if (existingParagraphs.length > 1) return existingParagraphs;

  final sentences = RegExp(r'[^.!?]+(?:[.!?]+["”’]?(?=\s|$)|$)')
      .allMatches(normalized)
      .map((match) => match.group(0)?.trim() ?? '')
      .where((sentence) => sentence.isNotEmpty)
      .toList();
  if (sentences.length < 2) return _splitLongTranscriptBlock(normalized);

  final paragraphs = <String>[];
  final current = <String>[];
  var currentLength = 0;
  for (final sentence in sentences) {
    current.add(sentence);
    currentLength += sentence.length;
    if (current.length >= 3 || currentLength >= 380) {
      paragraphs.add(current.join(' '));
      current.clear();
      currentLength = 0;
    }
  }
  if (current.isNotEmpty) paragraphs.add(current.join(' '));
  return paragraphs;
}

List<String> _splitLongTranscriptBlock(String text) {
  const targetLength = 420;
  if (text.length <= targetLength) return [text];
  final paragraphs = <String>[];
  var start = 0;
  while (start < text.length) {
    var end = start + targetLength;
    if (end > text.length) end = text.length;
    if (end < text.length) {
      final breakAt = text.lastIndexOf(' ', end);
      if (breakAt > start) end = breakAt;
    }
    final paragraph = text.substring(start, end).trim();
    if (paragraph.isNotEmpty) paragraphs.add(paragraph);
    start = end;
    while (start < text.length && text.codeUnitAt(start) == 32) {
      start++;
    }
  }
  return paragraphs;
}

class DetailExpansionSection extends StatelessWidget {
  const DetailExpansionSection({
    super.key,
    required this.title,
    required this.accent,
    required this.child,
  });

  final String title;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('url-detail-$title'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: accent,
          collapsedIconColor: colorScheme.onSurfaceVariant,
          title: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          children: [Align(alignment: Alignment.centerLeft, child: child)],
        ),
      ),
    );
  }
}
