import 'dart:convert';
import 'dart:developer' as developer;

import '../database/isar_service.dart';

class SavedTextHighlight {
  const SavedTextHighlight({
    required this.id,
    required this.sectionKey,
    required this.quote,
    required this.prefix,
    required this.suffix,
    required this.createdAt,
  });

  final String id;
  final String sectionKey;
  final String quote;
  final String prefix;
  final String suffix;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'section_key': sectionKey,
    'quote': quote,
    'prefix': prefix,
    'suffix': suffix,
    'created_at': createdAt.toIso8601String(),
  };

  static SavedTextHighlight? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final sectionKey = json['section_key']?.toString().trim() ?? '';
    final quote = json['quote']?.toString() ?? '';
    final createdAt = DateTime.tryParse(
      json['created_at']?.toString().trim() ?? '',
    );
    if (id.isEmpty ||
        id.length > SavedHighlightsCodec.maxIdLength ||
        sectionKey.isEmpty ||
        sectionKey.length > SavedHighlightsCodec.maxSectionKeyLength ||
        quote.trim().isEmpty ||
        quote.length > SavedHighlightsCodec.maxQuoteLength ||
        createdAt == null) {
      return null;
    }
    return SavedTextHighlight(
      id: id,
      sectionKey: sectionKey,
      quote: quote,
      prefix: _boundedContext(json['prefix']?.toString() ?? '', keepEnd: true),
      suffix: _boundedContext(json['suffix']?.toString() ?? '', keepEnd: false),
      createdAt: createdAt,
    );
  }

  static String _boundedContext(String value, {required bool keepEnd}) {
    if (value.length <= SavedHighlightsCodec.maxContextLength) return value;
    return keepEnd
        ? value.substring(value.length - SavedHighlightsCodec.maxContextLength)
        : value.substring(0, SavedHighlightsCodec.maxContextLength);
  }
}

class SavedHighlightRange {
  const SavedHighlightRange({
    required this.highlight,
    required this.start,
    required this.end,
  });

  final SavedTextHighlight highlight;
  final int start;
  final int end;
}

class SavedHighlightMutation {
  const SavedHighlightMutation({
    required this.highlights,
    required this.changed,
    this.highlight,
  });

  final List<SavedTextHighlight> highlights;
  final bool changed;
  final SavedTextHighlight? highlight;
}

class SavedHighlightsCodec {
  SavedHighlightsCodec._();

  static const int maxHighlightsPerSave = 100;
  static const int maxQuoteLength = 2000;
  static const int maxContextLength = 48;
  static const int maxIdLength = 128;
  static const int maxSectionKeyLength = 160;
  static const int maxPersistedLength = 512 * 1024;

  static List<SavedTextHighlight> decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    if (raw.length > maxPersistedLength) {
      developer.log(
        'Ignoring oversized saved highlight data',
        name: 'SavedHighlights',
      );
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final seenIds = <String>{};
      final highlights = <SavedTextHighlight>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          final highlight = SavedTextHighlight.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (highlight != null && seenIds.add(highlight.id)) {
            highlights.add(highlight);
            if (highlights.length == maxHighlightsPerSave) break;
          }
        } on Object catch (error, stack) {
          developer.log(
            'Ignoring a malformed saved highlight entry',
            name: 'SavedHighlights',
            error: error,
            stackTrace: stack,
          );
        }
      }
      return highlights;
    } on Object catch (error, stack) {
      developer.log(
        'Ignoring malformed saved highlight data',
        name: 'SavedHighlights',
        error: error,
        stackTrace: stack,
      );
      return const [];
    }
  }

  static String? encode(List<SavedTextHighlight> highlights) {
    if (highlights.isEmpty) return null;
    return jsonEncode(
      highlights
          .take(maxHighlightsPerSave)
          .map((item) => item.toJson())
          .toList(),
    );
  }

  static SavedTextHighlight? create({
    required String id,
    required String sectionKey,
    required String sourceText,
    required String selectedText,
    required DateTime createdAt,
    int? selectionStart,
  }) {
    final selection = selectionRange(
      sourceText,
      selectedText,
      startOffset: selectionStart,
    );
    if (selection == null || selection.end - selection.start > maxQuoteLength) {
      return null;
    }
    final prefixStart = (selection.start - maxContextLength).clamp(
      0,
      sourceText.length,
    );
    final suffixEnd = (selection.end + maxContextLength).clamp(
      0,
      sourceText.length,
    );
    return SavedTextHighlight(
      id: id,
      sectionKey: sectionKey,
      quote: sourceText.substring(selection.start, selection.end),
      prefix: sourceText.substring(prefixStart, selection.start),
      suffix: sourceText.substring(selection.end, suffixEnd),
      createdAt: createdAt,
    );
  }

  static ({int start, int end})? selectionRange(
    String sourceText,
    String selectedText, {
    int? startOffset,
  }) {
    final selected = selectedText.trim();
    if (selected.isEmpty || selected.length > maxQuoteLength) return null;
    if (startOffset != null) {
      if (startOffset < 0 ||
          startOffset + selected.length > sourceText.length ||
          !sourceText.startsWith(selected, startOffset)) {
        return null;
      }
      return (start: startOffset, end: startOffset + selected.length);
    }
    final exactStart = sourceText.indexOf(selected);
    if (exactStart >= 0) {
      return (start: exactStart, end: exactStart + selected.length);
    }

    final tokens = selected
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty);
    if (tokens.isEmpty) return null;
    final pattern = tokens.map(RegExp.escape).join(r'\s+');
    final match = RegExp(pattern).firstMatch(sourceText);
    if (match == null) return null;
    return (start: match.start, end: match.end);
  }

  static List<SavedHighlightRange> rangesFor({
    required String sectionKey,
    required String sourceText,
    required List<SavedTextHighlight> highlights,
  }) {
    final ranges =
        highlights
            .where((item) => item.sectionKey == sectionKey)
            .map((item) => _resolveRange(item, sourceText))
            .whereType<SavedHighlightRange>()
            .toList()
          ..sort((left, right) => left.start.compareTo(right.start));

    final nonOverlapping = <SavedHighlightRange>[];
    for (final range in ranges) {
      if (nonOverlapping.isEmpty || range.start >= nonOverlapping.last.end) {
        nonOverlapping.add(range);
      }
    }
    return nonOverlapping;
  }

  static SavedTextHighlight? intersectingHighlight({
    required String sectionKey,
    required String sourceText,
    required String selectedText,
    required List<SavedTextHighlight> highlights,
    int? selectionStart,
  }) {
    final selection = selectionRange(
      sourceText,
      selectedText,
      startOffset: selectionStart,
    );
    if (selection == null) return null;
    for (final range in rangesFor(
      sectionKey: sectionKey,
      sourceText: sourceText,
      highlights: highlights,
    )) {
      if (selection.start < range.end && selection.end > range.start) {
        return range.highlight;
      }
    }
    return null;
  }

  static String? mergeJson(String? local, String? incoming) {
    final merged = <SavedTextHighlight>[];
    final seen = <String>{};
    for (final item in [...decode(local), ...decode(incoming)]) {
      final identity = [
        item.sectionKey,
        item.quote,
        item.prefix,
        item.suffix,
      ].join('\u0000');
      if (seen.add(identity)) merged.add(item);
    }
    merged.sort((left, right) => left.createdAt.compareTo(right.createdAt));
    final firstKept = merged.length > maxHighlightsPerSave
        ? merged.length - maxHighlightsPerSave
        : 0;
    return encode(merged.sublist(firstKept));
  }

  static SavedHighlightRange? _resolveRange(
    SavedTextHighlight highlight,
    String sourceText,
  ) {
    var start = sourceText.indexOf(highlight.quote);
    if (start < 0) return null;

    var bestStart = start;
    var bestScore = -1;
    while (start >= 0) {
      final end = start + highlight.quote.length;
      var score = 0;
      if (highlight.prefix.isNotEmpty &&
          sourceText.substring(0, start).endsWith(highlight.prefix)) {
        score++;
      }
      if (highlight.suffix.isNotEmpty &&
          sourceText.substring(end).startsWith(highlight.suffix)) {
        score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestStart = start;
      }
      start = sourceText.indexOf(highlight.quote, start + 1);
    }
    return SavedHighlightRange(
      highlight: highlight,
      start: bestStart,
      end: bestStart + highlight.quote.length,
    );
  }
}

class SavedHighlightsService {
  const SavedHighlightsService(this._isarService);

  final IsarService _isarService;

  Future<SavedHighlightMutation?> add({
    required int urlId,
    required String sectionKey,
    required String sourceText,
    required String selectedText,
    int? selectionStart,
  }) async {
    SavedHighlightMutation? result;
    final updated = await _isarService.mutateUrl(urlId, (url) {
      final current = SavedHighlightsCodec.decode(url.highlightsJson);
      final overlapping = SavedHighlightsCodec.intersectingHighlight(
        sectionKey: sectionKey,
        sourceText: sourceText,
        selectedText: selectedText,
        highlights: current,
        selectionStart: selectionStart,
      );
      if (overlapping != null) {
        result = SavedHighlightMutation(
          highlights: current,
          changed: false,
          highlight: overlapping,
        );
        return;
      }
      final now = DateTime.now();
      final highlight = SavedHighlightsCodec.create(
        id: '${now.microsecondsSinceEpoch}_${current.length}',
        sectionKey: sectionKey,
        sourceText: sourceText,
        selectedText: selectedText,
        createdAt: now,
        selectionStart: selectionStart,
      );
      if (highlight == null ||
          current.length >= SavedHighlightsCodec.maxHighlightsPerSave) {
        result = SavedHighlightMutation(highlights: current, changed: false);
        return;
      }
      final next = [...current, highlight];
      url.highlightsJson = SavedHighlightsCodec.encode(next);
      result = SavedHighlightMutation(
        highlights: next,
        changed: true,
        highlight: highlight,
      );
    });
    return updated ? result : null;
  }

  Future<SavedHighlightMutation?> remove({
    required int urlId,
    required String highlightId,
  }) async {
    SavedHighlightMutation? result;
    final updated = await _isarService.mutateUrl(urlId, (url) {
      final current = SavedHighlightsCodec.decode(url.highlightsJson);
      final next = current
          .where((item) => item.id != highlightId)
          .toList(growable: false);
      final changed = next.length != current.length;
      if (changed) url.highlightsJson = SavedHighlightsCodec.encode(next);
      result = SavedHighlightMutation(highlights: next, changed: changed);
    });
    return updated ? result : null;
  }
}
