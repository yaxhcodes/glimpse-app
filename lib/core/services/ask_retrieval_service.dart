import 'dart:math';

import '../models/saved_url.dart';
import 'memory_intent_resolver.dart';

/// Hybrid retrieval tuned for Ask Glimpse.
///
/// Library search can be strict because the user is browsing results. Ask needs
/// recall: a question can mention two different saved things, vague memory words,
/// or a plural/typo. This service keeps lexical matches first and only lets
/// semantic matches in when they clear a relevance floor.
class AskRetrievalService {
  static const double semanticMinScore = 0.52;

  static const _stopwords = <String>{
    'a',
    'an',
    'the',
    'and',
    'or',
    'but',
    'in',
    'on',
    'at',
    'to',
    'for',
    'of',
    'as',
    'by',
    'with',
    'from',
    'is',
    'are',
    'was',
    'were',
    'be',
    'been',
    'being',
    'have',
    'has',
    'had',
    'do',
    'does',
    'did',
    'will',
    'would',
    'could',
    'should',
    'may',
    'might',
    'must',
    'shall',
    'can',
    'this',
    'that',
    'these',
    'those',
    'i',
    'me',
    'my',
    'we',
    'our',
    'you',
    'your',
    'it',
    'its',
    'what',
    'which',
    'who',
    'where',
    'when',
    'why',
    'how',
    'if',
    'than',
    'so',
    'not',
    'no',
    'any',
    'some',
    'about',
    'into',
    'through',
    'during',
    'before',
    'after',
    'above',
    'below',
    'between',
    'under',
    'again',
    'then',
    'once',
    'here',
    'there',
    'all',
    'both',
    'each',
    'few',
    'more',
    'most',
    'other',
    'such',
    'only',
    'same',
    'just',
    'also',
    'very',
    'own',
    'ask',
    'glimpse',
    'please',
    'pls',
    'find',
    'show',
    'tell',
    'give',
    'get',
    'look',
    'looking',
    'remember',
    'remembering',
    'vague',
    'thing',
    'things',
    'stuff',
    'save',
    'saved',
    'saving',
    'link',
    'links',
    'bookmark',
    'bookmarks',
    'url',
    'urls',
    'want',
    'wanted',
    'wants',
    'while',
    'ago',
    'back',
    'earlier',
    'recent',
    'recently',
  };

  static final _tokenSplit = RegExp(r'''[\s\-_/.,;:!?()\[\]{}"'`]+''');

  static List<SavedUrl> retrieve({
    required String query,
    required List<SavedUrl> allUrls,
    List<MapEntry<SavedUrl, double>> semanticScored = const [],
    int limit = 6,
  }) {
    if (allUrls.isEmpty) return const [];
    final intent = _AskQueryIntent.parse(query);
    final effectiveLimit = intent.quantity ?? min(limit, 5);

    final keyword = _keywordSearchScored(
      query: query,
      allUrls: allUrls,
      limit: effectiveLimit * 3,
      intent: intent,
    );

    final byId = <int, _HybridHit>{};
    for (final entry in keyword) {
      byId[entry.key.id] = _HybridHit(url: entry.key, keyword: entry.value);
    }

    for (final entry in semanticScored) {
      if (entry.value < semanticMinScore) continue;
      if (!intent.allows(entry.key)) continue;
      final existing = byId[entry.key.id];
      if (existing == null) {
        byId[entry.key.id] = _HybridHit(url: entry.key, semantic: entry.value);
      } else {
        existing.semantic = max(existing.semantic, entry.value);
      }
    }

    final hits = byId.values.toList()
      ..sort((a, b) {
        final c = b.score.compareTo(a.score);
        if (c != 0) return c;
        return b.url.savedAt.compareTo(a.url.savedAt);
      });

    return hits.take(effectiveLimit).map((h) => h.url).toList();
  }

  static List<MapEntry<SavedUrl, double>> keywordSearchScored({
    required String query,
    required List<SavedUrl> allUrls,
    int limit = 18,
  }) {
    return _keywordSearchScored(
      query: query,
      allUrls: allUrls,
      limit: limit,
      intent: _AskQueryIntent.parse(query),
    );
  }

  static List<MapEntry<SavedUrl, double>> _keywordSearchScored({
    required String query,
    required List<SavedUrl> allUrls,
    required _AskQueryIntent intent,
    int limit = 18,
  }) {
    final terms = _queryTerms(query, intent: intent);
    if (terms.isEmpty || allUrls.isEmpty) return const [];

    final documentFrequency = <String, int>{};
    for (final term in terms) {
      var count = 0;
      for (final url in allUrls) {
        if (_bestContribution(url, term) >= 0.62) count++;
      }
      documentFrequency[term] = count;
    }

    final total = allUrls.length;
    final scored = <MapEntry<SavedUrl, double>>[];
    for (final url in allUrls) {
      if (!intent.allows(url)) continue;

      double weightedSum = 0;
      double matchedWeight = 0;
      var matched = 0;
      var hasStrongTitleMatch = false;

      for (final term in terms) {
        final contribution = _bestContribution(url, term);
        if (contribution < 0.62) continue;

        final df = documentFrequency[term] ?? total;
        final idf = log(1 + total / (1 + df));
        weightedSum += contribution * idf;
        matchedWeight += idf;
        matched++;
        if (_titleContribution(url, term) >= 0.92) {
          hasStrongTitleMatch = true;
        }
      }

      if (matched == 0 || matchedWeight == 0) continue;

      final avgMatched = weightedSum / matchedWeight;
      final coverage = matched / min(terms.length, 4);
      var score =
          avgMatched * (0.70 + 0.30 * coverage.clamp(0.0, 1.0).toDouble());
      if (hasStrongTitleMatch) score += 0.14;
      if (_phraseMatch(url, query)) score += 0.10;
      score += intent.scoreBoost(url);
      score = score.clamp(0.0, 1.0).toDouble();

      if (score >= 0.42 || hasStrongTitleMatch) {
        scored.add(MapEntry(url, score));
      }
    }

    scored.sort((a, b) {
      final c = b.value.compareTo(a.value);
      if (c != 0) return c;
      return b.key.savedAt.compareTo(a.key.savedAt);
    });
    return scored.take(limit).toList();
  }

  static List<String> _queryTerms(
    String query, {
    required _AskQueryIntent intent,
  }) {
    final seen = <String>{};
    final terms = <String>[];
    for (final raw in query.toLowerCase().split(_tokenSplit)) {
      final token = raw.trim();
      if (token.length < 2 || _stopwords.contains(token)) continue;
      if (intent.isContentTypeTerm(token)) continue;
      if (seen.add(token)) terms.add(token);
    }
    final baseTerms = List<String>.from(terms);
    for (var i = 0; i < baseTerms.length - 1; i++) {
      final left = baseTerms[i];
      final right = baseTerms[i + 1];
      if (left.length < 3 || right.length < 3) continue;
      final compact = '$left$right';
      if (seen.add(compact)) terms.add(compact);
    }
    return terms;
  }

  static bool _phraseMatch(SavedUrl url, String query) {
    final normalized = query.toLowerCase().trim();
    if (normalized.length < 4) return false;
    final compactQuery = _compact(normalized);
    final compactPrimary = _compact(_primaryHaystack(url));
    final compactSecondary = _compact(_secondaryHaystack(url));
    if (compactQuery.length >= 4 &&
        (compactPrimary.contains(compactQuery) ||
            compactSecondary.contains(compactQuery))) {
      return true;
    }
    return _primaryHaystack(url).contains(normalized) ||
        _secondaryHaystack(url).contains(normalized);
  }

  static double _bestContribution(SavedUrl url, String term) {
    final title = url.title.toLowerCase();
    final primary = _primaryHaystack(url);
    final secondary = _secondaryHaystack(url);
    var best = 0.0;
    for (final variant in _variants(term)) {
      if (_wordBoundaryMatch(title, variant)) best = max(best, 1.08);
      if (_wordBoundaryMatch(primary, variant)) best = max(best, 1.0);
      final fuzzyPrimary = _maxFuzzyForWord(variant, primary);
      if (fuzzyPrimary >= 0.72) best = max(best, fuzzyPrimary * 0.92);
      if (_wordBoundaryMatch(secondary, variant)) best = max(best, 0.78);
      final fuzzySecondary = _maxFuzzyForWord(variant, secondary);
      if (fuzzySecondary >= 0.82) best = max(best, fuzzySecondary * 0.70);
    }
    return best.clamp(0.0, 1.08).toDouble();
  }

  static double _titleContribution(SavedUrl url, String term) {
    final title = url.title.toLowerCase();
    var best = 0.0;
    for (final variant in _variants(term)) {
      if (_wordBoundaryMatch(title, variant)) best = max(best, 1.0);
      final fuzzy = _maxFuzzyForWord(variant, title);
      if (fuzzy >= 0.78) best = max(best, fuzzy);
    }
    return best;
  }

  static Iterable<String> _variants(String term) sync* {
    yield term;
    if (term.length > 4 && term.endsWith('s')) {
      yield term.substring(0, term.length - 1);
    }
    if (term.length > 4 && term.endsWith('ies')) {
      yield '${term.substring(0, term.length - 3)}y';
    }
  }

  static String _primaryHaystack(SavedUrl url) {
    return [
      url.title,
      url.description,
      url.summary ?? '',
      MemoryIntentResolver.searchableText(url),
      ...url.tags,
    ].join(' ').toLowerCase();
  }

  static String _secondaryHaystack(SavedUrl url) {
    return [
      url.domain,
      url.rawUrl,
      url.category,
      ...url.effectiveCategories,
      url.userNotes ?? '',
    ].join(' ').toLowerCase();
  }

  static bool _wordBoundaryMatch(String haystack, String word) {
    if (word.isEmpty || word.length > 64) return false;
    final escaped = RegExp.escape(word);
    return RegExp(
      r'(?:^|[^a-zA-Z0-9])' + escaped + r'(?:[^a-zA-Z0-9]|$)',
      caseSensitive: false,
    ).hasMatch(haystack);
  }

  static double _maxFuzzyForWord(String word, String haystackLower) {
    if (word.length < 2) return 0;
    double best = 0;
    for (final candidate in haystackLower.split(_tokenSplit)) {
      if (candidate.isEmpty) continue;
      if (word[0] != candidate[0]) continue;
      final sim = _similarity(word, candidate);
      if (sim > best) best = sim;
    }
    return best;
  }

  static double _similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.length < 2 || b.length < 2) {
      if (a.length <= 2 && b.startsWith(a)) return 0.8;
      if (b.length <= 2 && a.startsWith(b)) return 0.8;
      return 0.0;
    }
    final aBigrams = <String>{};
    for (var i = 0; i < a.length - 1; i++) {
      aBigrams.add(a.substring(i, i + 2));
    }
    final bBigrams = <String>{};
    for (var i = 0; i < b.length - 1; i++) {
      bBigrams.add(b.substring(i, i + 2));
    }
    final intersection = aBigrams.intersection(bBigrams).length;
    return (2 * intersection) / (aBigrams.length + bBigrams.length);
  }

  static String _compact(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

class _AskQueryIntent {
  const _AskQueryIntent({this.contentType, this.quantity});

  final String? contentType;
  final int? quantity;

  static _AskQueryIntent parse(String query) {
    final lower = query.toLowerCase();
    return _AskQueryIntent(
      contentType: _parseContentType(lower),
      quantity: _parseQuantity(lower),
    );
  }

  static String? _parseContentType(String lower) {
    if (_containsAny(lower, const ['documentary', 'documentaries', 'docu'])) {
      return 'documentary';
    }
    if (_containsAny(lower, const [
      'article',
      'articles',
      'essay',
      'essays',
      'blog',
      'blogs',
      'post',
      'posts',
      'read',
    ])) {
      return 'article';
    }
    if (_containsAny(lower, const [
      'repo',
      'repos',
      'repository',
      'repositories',
      'github',
      'code',
      'library',
      'package',
    ])) {
      return 'repo';
    }
    if (_containsAny(lower, const ['recipe', 'recipes'])) {
      return 'recipe';
    }
    if (_containsAny(lower, const ['inspiration', 'inspo', 'ideas'])) {
      return 'inspiration';
    }
    return null;
  }

  static int? _parseQuantity(String lower) {
    final digit = RegExp(r'\b([1-9]|10)\b').firstMatch(lower);
    if (digit != null) return int.tryParse(digit.group(1)!);

    const words = {
      'one': 1,
      'two': 2,
      'both': 2,
      'three': 3,
      'four': 4,
      'five': 5,
      'six': 6,
      'seven': 7,
      'eight': 8,
      'nine': 9,
      'ten': 10,
    };
    for (final entry in words.entries) {
      if (RegExp(r'\b' + entry.key + r'\b').hasMatch(lower)) {
        return entry.value;
      }
    }
    if (RegExp(r'\ba couple\b').hasMatch(lower)) return 2;
    return null;
  }

  bool isContentTypeTerm(String term) {
    final type = contentType;
    if (type == null) return false;
    return switch (type) {
      'documentary' => const {
        'documentary',
        'documentaries',
        'docu',
        'film',
        'films',
        'video',
        'videos',
      }.contains(term),
      'article' => const {
        'article',
        'articles',
        'essay',
        'essays',
        'blog',
        'blogs',
        'post',
        'posts',
        'read',
      }.contains(term),
      'repo' => const {
        'repo',
        'repos',
        'repository',
        'repositories',
        'github',
        'code',
        'library',
        'package',
      }.contains(term),
      'recipe' => const {'recipe', 'recipes'}.contains(term),
      'inspiration' => const {'inspiration', 'inspo', 'ideas'}.contains(term),
      _ => false,
    };
  }

  bool allows(SavedUrl url) {
    if (contentType == null) return true;
    final fitness = _platformFitness(url);
    final explicit = _explicitContentTypeMatch(url);
    if (contentType == 'documentary' && fitness >= 0.8) {
      return explicit || _looksLikeLongFormVideo(url);
    }
    if (fitness >= 0.35) return true;
    return explicit;
  }

  double scoreBoost(SavedUrl url) {
    if (contentType == null) return 0;
    final fitness = _platformFitness(url);
    final explicit = _explicitContentTypeMatch(url);
    var boost = 0.0;
    if (fitness >= 0.8) boost += 0.16;
    if (fitness >= 0.5) boost += 0.06;
    if (explicit) boost += 0.18;
    return boost;
  }

  double _platformFitness(SavedUrl url) {
    final source = [
      url.domain,
      url.rawUrl,
      url.category,
      ...url.effectiveCategories,
      ...url.tags,
    ].join(' ').toLowerCase();

    bool hasAny(List<String> needles) =>
        needles.any((needle) => source.contains(needle));

    return switch (contentType) {
      'documentary' =>
        hasAny(['youtube', 'youtu.be', 'vimeo'])
            ? 1.0
            : hasAny(['github', 'gitlab', 'x.com', 'twitter', 'instagram'])
            ? 0.0
            : 0.45,
      'article' =>
        hasAny(['youtube', 'youtu.be', 'instagram', 'tiktok'])
            ? 0.15
            : hasAny(['substack', 'medium', 'dev.to', 'blog'])
            ? 1.0
            : 0.65,
      'repo' =>
        hasAny(['github', 'gitlab', 'npm', 'pub.dev', 'crates.io'])
            ? 1.0
            : hasAny(['youtube', 'youtu.be', 'instagram', 'x.com', 'twitter'])
            ? 0.15
            : 0.45,
      'inspiration' =>
        hasAny(['instagram', 'x.com', 'twitter', 'pinterest'])
            ? 1.0
            : hasAny(['github', 'gitlab'])
            ? 0.1
            : 0.55,
      _ => 0.55,
    };
  }

  bool _explicitContentTypeMatch(SavedUrl url) {
    final type = contentType;
    if (type == null) return true;
    final text = [
      url.title,
      url.description,
      url.summary ?? '',
      MemoryIntentResolver.searchableText(url),
      ...url.tags,
    ].join(' ').toLowerCase();
    return switch (type) {
      'documentary' => _containsAny(text, const [
        'documentary',
        'documentaries',
        'film',
        'full episode',
        'feature length',
      ]),
      'article' => _containsAny(text, const [
        'article',
        'essay',
        'blog post',
        'guide',
      ]),
      'repo' => _containsAny(text, const [
        'repository',
        'repo',
        'github',
        'open source',
        'package',
        'library',
      ]),
      'recipe' => _containsAny(text, const ['recipe', 'ingredients']),
      'inspiration' => _containsAny(text, const ['inspiration', 'ideas']),
      _ => false,
    };
  }

  bool _looksLikeLongFormVideo(SavedUrl url) {
    final text = [
      url.title,
      url.description,
      url.summary ?? '',
      MemoryIntentResolver.searchableText(url),
      ...url.tags,
    ].join(' ').toLowerCase();
    return _containsAny(text, const [
      'documentary',
      'film',
      'feature-length',
      'feature length',
      'directed by',
      'full movie',
      'full episode',
      'episode',
    ]);
  }

  static bool _containsAny(String value, List<String> needles) =>
      needles.any((needle) => value.contains(needle));
}

class _HybridHit {
  _HybridHit({required this.url, this.keyword = 0, this.semantic = 0});

  final SavedUrl url;
  double keyword;
  double semantic;

  double get score {
    final semanticNormalized = semantic <= 0
        ? 0.0
        : ((semantic - AskRetrievalService.semanticMinScore) /
                  (1 - AskRetrievalService.semanticMinScore))
              .clamp(0.0, 1.0)
              .toDouble();
    return keyword > 0
        ? (keyword * 0.82) + (semanticNormalized * 0.18)
        : semanticNormalized * 0.72;
  }
}
