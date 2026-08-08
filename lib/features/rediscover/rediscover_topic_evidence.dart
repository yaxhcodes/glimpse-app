import '../../core/models/saved_url.dart';
import '../../core/services/memory_intent_resolver.dart';

abstract final class RediscoverTopicEvidence {
  static bool hasSharedTerms(Iterable<SavedUrl> urls, Iterable<String> terms) {
    final needles = terms
        .map((term) => term.trim().toLowerCase())
        .where((term) => term.isNotEmpty)
        .toList();
    if (needles.isEmpty) return false;
    return hasSharedMatch(urls, (text) => needles.any(text.contains));
  }

  static bool hasSharedMatch(
    Iterable<SavedUrl> urls,
    bool Function(String text) matches,
  ) {
    final candidates = urls.toList();
    if (candidates.isEmpty) return false;
    final matchCount = candidates.map(searchableText).where(matches).length;
    return matchCount >= (candidates.length == 1 ? 1 : 2);
  }

  static String searchableText(SavedUrl url) {
    return [
      url.title,
      url.description,
      url.summary ?? '',
      url.category,
      url.categories.join(' '),
      url.tags.join(' '),
      MemoryIntentResolver.searchableText(url),
    ].join(' ').toLowerCase();
  }
}
