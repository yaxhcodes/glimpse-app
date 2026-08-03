import 'package:flutter/material.dart';

import '../../core/services/transcript_enrichment_service.dart';

const int _compactTermTitleLimit = 28;
const int _compactTermContentLimit = 42;

bool shouldUseCompactTermGrid(List<EnrichedNotableItem> items) {
  if (items.isEmpty ||
      items.any((item) => item.type.trim().toLowerCase() != 'term')) {
    return false;
  }

  return items.every((item) {
    final title = item.text.trim();
    final label = item.label?.trim() ?? '';
    final visibleLabel = label == title ? '' : label;
    final attribution = item.attribution?.trim() ?? '';
    final explanation = item.whyImportant?.trim() ?? '';

    return attribution.isEmpty &&
        explanation.isEmpty &&
        title.length <= _compactTermTitleLimit &&
        title.length + visibleLabel.length <= _compactTermContentLimit;
  });
}

/// Lays out short notable terms as compact, responsive tiles.
///
/// Detail pages normally have enough room for two tiles per row. On very
/// narrow layouts, each tile expands to the available width so its content
/// never becomes cramped or clipped.
class NotableTermGrid extends StatelessWidget {
  const NotableTermGrid({super.key, required this.children});

  static const double _twoColumnBreakpoint = 300;
  static const double _spacing = 8;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final columnCount = availableWidth >= _twoColumnBreakpoint ? 2 : 1;
        final tileWidth = columnCount == 2
            ? (availableWidth - _spacing) / 2
            : availableWidth;

        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}
