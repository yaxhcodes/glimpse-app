import 'text_cleaner.dart';

/// Platform / generic tags that add no value on cards or in LLM prompts.
class TagNoiseFilter {
  TagNoiseFilter._();

  static const noiseTags = {
    'instagram',
    'youtube',
    'twitter',
    'x',
    'tiktok',
    'facebook',
    'threads',
    'reddit',
    'linkedin',
    'pinterest',
    'snapchat',
    'web',
    'article',
    'post',
    'reel',
    'video',
    'link',
    'url',
    'technology',
  };

  static bool isNoiseTag(String tag) {
    final cleaned = cleanTag(tag);
    if (cleaned.isEmpty) return true;
    if (cleaned.startsWith('@')) return true;
    if (noiseTags.contains(cleaned)) return true;
    if (RegExp(r'^x[0-9a-f]{2,}$').hasMatch(cleaned)) return true;
    if (RegExp(r'\bx[0-9a-f]{2,}\b').hasMatch(cleaned)) return true;
    if (RegExp(r'^(x[0-9a-f]{2,}\s*)+$').hasMatch(cleaned)) return true;
    if (RegExp(r'^\d+(?:\.\d+)?[kmb]?$').hasMatch(cleaned)) return true;
    if (RegExp(r'^\d+$').hasMatch(cleaned)) return true;
    if (cleaned.contains('&#x') || cleaned.contains('&amp')) return true;
    if (RegExp(r'\b(like|likes|comment|comments|views)\b').hasMatch(cleaned)) {
      return true;
    }
    if (RegExp(r'\b(instagram|twitter|facebook|youtube|tiktok|threads)\b')
        .hasMatch(cleaned)) {
      return true;
    }
    if (cleaned.endsWith('.com') || cleaned.endsWith('.in')) return true;
    return false;
  }

  static List<String> filterTags(List<String> tags) {
    final seen = <String>{};
    final out = <String>[];
    for (final tag in tags) {
      final cleaned = cleanTag(tag);
      if (cleaned.isEmpty || isNoiseTag(cleaned) || seen.contains(cleaned)) {
        continue;
      }
      seen.add(cleaned);
      out.add(cleaned);
    }
    return out;
  }

  static String cleanTag(String tag) {
    return TextCleaner.cleanLoose(tag)
        .replaceAll(RegExp(r'https?://\S+'), '')
        .replaceAll(RegExp(r'[#,"\.;:()\[\]{}]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  /// Rarest first (lowest [occurrences] count). Unknown tags count as 0 (most specific).
  static List<String> orderByRarity(
    List<String> tags,
    Map<String, int> occurrences,
  ) {
    final copy = List<String>.from(tags);
    int rank(String t) => occurrences[t.toLowerCase().trim()] ?? 0;
    copy.sort((a, b) {
      final c = rank(a).compareTo(rank(b));
      if (c != 0) return c;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return copy;
  }

  /// Up to [maxVisible] tags for chips; remainder as overflow count.
  static ({List<String> visible, int overflow}) visibleTags(
    List<String> tags,
    Map<String, int> occurrences, {
    int maxVisible = 4,
  }) {
    final filtered = filterTags(tags);
    final ordered = occurrences.isEmpty
        ? (List<String>.from(filtered)
          ..sort((a, b) => b.length.compareTo(a.length)))
        : orderByRarity(filtered, occurrences);
    if (ordered.length <= maxVisible) {
      return (visible: ordered, overflow: 0);
    }
    return (
      visible: ordered.take(maxVisible).toList(),
      overflow: ordered.length - maxVisible,
    );
  }

  /// Noise-filtered tags that fit in ~one row (~30 char budget incl. chip padding).
  static List<String> selectVisibleTags(List<String> tags) {
    return _tagsWithinCharBudget(filterTags(tags));
  }

  static List<String> _tagsWithinCharBudget(List<String> ordered) {
    if (ordered.isEmpty) return [];
    var budget = 30;
    var count = 0;
    for (final tag in ordered) {
      if (tag.length + 2 > budget) break;
      budget -= tag.length + 2;
      count++;
    }
    return ordered.take(count.clamp(1, ordered.length)).toList();
  }

  /// Like [selectVisibleTags] but uses rarity / length ordering (same as [visibleTags]).
  static ({List<String> visible, int overflow}) visibleTagsForCard(
    List<String> tags,
    Map<String, int> occurrences,
  ) {
    final filtered = filterTags(tags);
    if (filtered.isEmpty) return (visible: <String>[], overflow: 0);
    final ordered = occurrences.isEmpty
        ? (List<String>.from(filtered)
          ..sort((a, b) => b.length.compareTo(a.length)))
        : orderByRarity(filtered, occurrences);
    final visible = _tagsWithinCharBudget(ordered);
    final overflow = ordered.length - visible.length;
    return (visible: visible, overflow: overflow > 0 ? overflow : 0);
  }
}
