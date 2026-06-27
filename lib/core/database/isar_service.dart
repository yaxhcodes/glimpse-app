import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_url.dart';
import '../services/link_preview_service.dart';
import '../models/user_collection.dart';
import '../services/category_resolver.dart';
import '../services/category_taxonomy.dart';
import '../services/session_tracking_service.dart';
import '../services/memory_intent_resolver.dart';
import '../services/source_membership.dart';

/// Service handling all local database operations via Isar.
class IsarService {
  late Future<Isar> _db;

  IsarService() {
    _db = _openDb();
  }

  Future<Isar> _openDb() async {
    final existing = Isar.getInstance();
    if (existing != null && existing.isOpen) return existing;
    final dir = await getApplicationDocumentsDirectory();
    return Isar.open([
      SavedUrlSchema,
      UserCollectionSchema,
    ], directory: dir.path);
  }

  /// Await the database so it's ready before the first frame.
  Future<void> ensureInitialized() => _db;

  // --------------- CREATE ---------------

  Future<int> saveUrl(SavedUrl url) async {
    final isar = await _db;
    return isar.writeTxn(() => isar.savedUrls.put(url));
  }

  // --------------- READ ---------------

  Future<List<SavedUrl>> getAllUrls() async {
    final isar = await _db;
    return isar.savedUrls.where().sortBySavedAtDesc().findAll();
  }

  /// Most recently saved URLs first (for Ask personal suggestions, etc.).
  Future<List<SavedUrl>> getRecentUrls({int limit = 15}) async {
    final isar = await _db;
    final all = await isar.savedUrls.where().sortBySavedAtDesc().findAll();
    if (all.length <= limit) return all;
    return all.take(limit).toList();
  }

  /// URLs that have a non-empty embedding (for semantic clustering / mind map).
  Future<List<SavedUrl>> getUrlsWithEmbeddings() async {
    final all = await getAllUrls();
    return all
        .where((u) => u.embedding != null && u.embedding!.isNotEmpty)
        .toList();
  }

  /// URLs with null or empty embedding (candidates for Voyage backfill).
  Future<List<SavedUrl>> getUrlsWithoutEmbedding() async {
    final isar = await _db;
    final nullEmb = await isar.savedUrls.filter().embeddingIsNull().findAll();
    final emptyEmb = await isar.savedUrls
        .filter()
        .embeddingIsNotNull()
        .embeddingIsEmpty()
        .findAll();
    final byId = {for (final u in nullEmb) u.id: u};
    for (final u in emptyEmb) {
      byId[u.id] = u;
    }
    final combined = byId.values.toList();
    combined.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return combined;
  }

  /// Persists only the embedding vector for an existing URL.
  Future<void> updateEmbedding({
    required int id,
    required List<double> embedding,
  }) async {
    if (embedding.isEmpty) return;
    final isar = await _db;
    await isar.writeTxn(() async {
      final url = await isar.savedUrls.get(id);
      if (url != null) {
        url.embedding = embedding;
        await isar.savedUrls.put(url);
      }
    });
  }

  Future<SavedUrl?> getUrlById(int id) async {
    final isar = await _db;
    return isar.savedUrls.get(id);
  }

  /// Loads [SavedUrl]s for [ids]; missing ids are omitted. Order is not preserved.
  Future<Map<int, SavedUrl>> getUrlsByIds(Set<int> ids) async {
    if (ids.isEmpty) return {};
    final isar = await _db;
    final list = ids.toList();
    final rows = await isar.savedUrls.getAll(list);
    final out = <int, SavedUrl>{};
    for (var i = 0; i < list.length; i++) {
      final u = rows[i];
      if (u != null) out[list[i]] = u;
    }
    return out;
  }

  Future<List<SavedUrl>> getUrlsByIdsOrdered(List<int> ids) async {
    if (ids.isEmpty) return [];
    final map = await getUrlsByIds(ids.toSet());
    return ids.map((id) => map[id]).whereType<SavedUrl>().toList();
  }

  Future<List<SavedUrl>> getUrlsByCategory(String category) async {
    final isar = await _db;
    final allUrls = await isar.savedUrls.where().sortBySavedAtDesc().findAll();
    // "Done" saves are archived — excluded from the main library views.
    return allUrls
        .where((url) => !url.isDone && SourceMembership.contains(url, category))
        .toList();
  }

  /// Returns a list of unique categories with their emoji and count.
  Future<List<Map<String, dynamic>>> getCategories() async {
    final isar = await _db;
    final allUrls = await isar.savedUrls.where().findAll();

    final Map<String, Map<String, dynamic>> categoryMap = {};
    for (final url in allUrls) {
      if (url.isDone) continue; // archived saves don't count toward categories
      for (final category in url.effectiveCategories) {
        final interest = CategoryTaxonomy.normalize(
          category: category,
          tags: url.tags,
        );
        final name = interest.name;
        if (categoryMap.containsKey(name)) {
          categoryMap[name]!['count'] =
              (categoryMap[name]!['count'] as int) + 1;
        } else {
          categoryMap[name] = {
            'category': name,
            'emoji': interest.emoji,
            'count': 1,
          };
        }
      }
    }
    return categoryMap.values.toList();
  }

  /// Local keyword / fuzzy search (fallback when semantic search is unavailable).
  Future<List<SavedUrl>> keywordSearch(String query) async {
    final scored = await keywordSearchWithScores(query);
    return scored.map((e) => e.key).toList();
  }

  /// Same as [keywordSearch] but with relevance scores in ~0–1 for ranking UI.
  Future<List<MapEntry<SavedUrl, double>>> keywordSearchWithScores(
    String query,
  ) => _rankedKeywordSearch(query, naturalLanguage: false);

  static const _nlStopwords = <String>{
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
    'whom',
    'whose',
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
    'further',
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
    'own',
    'same',
    'just',
    'also',
    'very',
    'save',
    'saved',
    'saving',
    'want',
    'wanted',
    'wants',
    'link',
    'links',
    'bookmark',
    'bookmarks',
    'url',
    'urls',
  };

  static final _tokenSplit = RegExp(r'[\s\-_/.,;:!?()\[\]{}]+');

  static bool _wordBoundaryMatch(String haystack, String word) {
    if (word.isEmpty || word.length > 64) return false;
    final esc = RegExp.escape(word);
    return RegExp(
      r'(?:^|[^a-zA-Z0-9])' + esc + r'(?:[^a-zA-Z0-9]|$)',
      caseSensitive: false,
    ).hasMatch(haystack);
  }

  static List<String> _tokens(String text) =>
      text.toLowerCase().split(_tokenSplit).where((t) => t.isNotEmpty).toList();

  static double _maxFuzzyForWord(
    String word,
    String haystackLower, {
    bool requireSameFirstChar = false,
  }) {
    if (word.length < 2) return 0;
    double best = 0;
    for (final fw in _tokens(haystackLower)) {
      if (fw.isEmpty) continue;
      if (requireSameFirstChar &&
          word.isNotEmpty &&
          fw.isNotEmpty &&
          word[0].toLowerCase() != fw[0].toLowerCase()) {
        continue;
      }
      final sim = _similarity(word, fw);
      if (sim > best) best = sim;
    }
    return best;
  }

  /// Primary text: where a match should mean the hit is about the query.
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

  /// Returns null if the URL should not appear in results.
  static double? _relevanceScore(
    SavedUrl url,
    List<String> queryWords, {
    required bool naturalLanguage,
  }) {
    if (queryWords.isEmpty) return null;

    final primary = _primaryHaystack(url);
    final secondary = _secondaryHaystack(url);
    final combined = '$primary $secondary';

    const strictFuzzy = 0.64;
    const nlFuzzyPrimary = 0.58;
    const nlFuzzySecondary = 0.62;
    const minAvgStrict = 0.52;
    const minAvgNl = 0.48;

    double wordContribution(String word) {
      final boundaryPrimary = _wordBoundaryMatch(primary, word);
      final boundarySecondary = _wordBoundaryMatch(secondary, word);
      final fuzzyP = _maxFuzzyForWord(
        word,
        primary,
        requireSameFirstChar: true,
      );
      final fuzzyS = _maxFuzzyForWord(
        word,
        secondary,
        requireSameFirstChar: true,
      );
      final fuzzyC = _maxFuzzyForWord(
        word,
        combined,
        requireSameFirstChar: true,
      );

      if (naturalLanguage) {
        if (boundaryPrimary) return 1.0;
        if (fuzzyP >= nlFuzzyPrimary) return fuzzyP;
        if (boundarySecondary) return 0.82;
        if (fuzzyS >= nlFuzzySecondary) return fuzzyS * 0.9;
        return fuzzyC * 0.75;
      }

      // Library search: avoid weak fuzzy-only matches (e.g. voice vs invoice).
      if (boundaryPrimary) return 1.0;
      if (fuzzyP >= strictFuzzy) return fuzzyP * 0.92;
      if (boundarySecondary) return 0.72;
      if (fuzzyS >= 0.78) return fuzzyS * 0.65;
      return 0;
    }

    double sum = 0;
    for (final w in queryWords) {
      final c = wordContribution(w);
      if (c <= 0) return null;
      sum += c;
    }

    final avg = sum / queryWords.length;
    final minAvg = naturalLanguage ? minAvgNl : minAvgStrict;
    if (avg < minAvg) return null;

    // Extra filter: for strict mode, require a real signal on primary text
    // unless every word matched with strong fuzzy on primary.
    if (!naturalLanguage) {
      var anyPrimary = false;
      var allStrongPrimaryFuzzy = true;
      for (final w in queryWords) {
        final bp = _wordBoundaryMatch(primary, w);
        final fp = _maxFuzzyForWord(w, primary, requireSameFirstChar: true);
        if (bp || fp >= 0.78) anyPrimary = true;
        if (!(bp || fp >= strictFuzzy)) allStrongPrimaryFuzzy = false;
      }
      if (!anyPrimary && !allStrongPrimaryFuzzy) return null;
    }

    return avg.clamp(0.0, 1.0);
  }

  static List<String> _queryWordsForMode(String query, bool naturalLanguage) {
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) return [];
    var words = lower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (naturalLanguage) {
      words = words
          .where((w) => w.length >= 2 && !_nlStopwords.contains(w))
          .toList();
      if (words.isEmpty) {
        words = lower
            .split(RegExp(r'\s+'))
            .where((w) => w.length >= 3)
            .toList();
      }
    } else {
      words = words.where((w) => w.length >= 2).toList();
    }
    return words;
  }

  Future<Set<int>> _candidateUrlIds(String query, List<String> words) async {
    final isar = await _db;
    final queries = <String>{query.trim().toLowerCase()};
    for (final w in words) {
      if (w.length >= 3) queries.add(w);
    }
    final lists = await Future.wait(queries.map(searchUrls));
    final ids = <int>{};
    for (final list in lists) {
      for (final u in list) {
        ids.add(u.id);
      }
    }

    // If the substring-based Isar filter matches almost everything, scan in-memory instead.
    final total = await isar.savedUrls.where().count();
    if (total > 0 && ids.length > total * 0.85) {
      return {};
    }
    return ids;
  }

  Future<List<SavedUrl>> _loadUrlsForSearch(
    Isar isar,
    Set<int> candidateIds,
  ) async {
    if (candidateIds.isEmpty) {
      return isar.savedUrls.where().findAll();
    }
    final ordered = candidateIds.toList()..sort();
    final rows = await isar.savedUrls.getAll(ordered);
    return rows.whereType<SavedUrl>().toList();
  }

  Future<List<MapEntry<SavedUrl, double>>> _rankedKeywordSearch(
    String query, {
    required bool naturalLanguage,
  }) async {
    final isar = await _db;
    final words = _queryWordsForMode(query, naturalLanguage);
    if (words.isEmpty) return [];

    final candidateIds = await _candidateUrlIds(
      query.toLowerCase().trim(),
      words,
    );
    var urls = await _loadUrlsForSearch(isar, candidateIds);

    if (urls.isEmpty && candidateIds.isNotEmpty) {
      urls = await isar.savedUrls.where().findAll();
    }

    List<MapEntry<SavedUrl, double>> scoreBatch(List<SavedUrl> list) {
      final out = <MapEntry<SavedUrl, double>>[];
      for (final url in list) {
        final s = _relevanceScore(url, words, naturalLanguage: naturalLanguage);
        if (s != null) out.add(MapEntry(url, s));
      }
      return out;
    }

    var scored = scoreBatch(urls);
    if (scored.isEmpty && candidateIds.isNotEmpty) {
      urls = await isar.savedUrls.where().findAll();
      scored = scoreBatch(urls);
    }

    scored.sort((a, b) {
      final c = b.value.compareTo(a.value);
      if (c != 0) return c;
      return b.key.savedAt.compareTo(a.key.savedAt);
    });
    return scored;
  }

  /// Simple keyword search (LIKE-style) for Phase 1.
  /// Searches title, description, summary, tags, categories, domain, rawUrl, and userNotes.
  Future<List<SavedUrl>> searchUrls(String query) async {
    final isar = await _db;
    final lowerQuery = query.toLowerCase();
    return isar.savedUrls
        .filter()
        .titleContains(lowerQuery, caseSensitive: false)
        .or()
        .descriptionContains(lowerQuery, caseSensitive: false)
        .or()
        .summaryContains(lowerQuery, caseSensitive: false)
        .or()
        .tagsElementContains(lowerQuery, caseSensitive: false)
        .or()
        .categoriesElementContains(lowerQuery, caseSensitive: false)
        .or()
        .categoryContains(lowerQuery, caseSensitive: false)
        .or()
        .rawUrlContains(lowerQuery, caseSensitive: false)
        .or()
        .domainContains(lowerQuery, caseSensitive: false)
        .or()
        .userNotesContains(lowerQuery, caseSensitive: false)
        .or()
        .enrichmentJsonContains(lowerQuery, caseSensitive: false)
        .sortBySavedAtDesc()
        .findAll();
  }

  /// Check if a URL already exists in the database.
  Future<SavedUrl?> findByRawUrl(String rawUrl) async {
    final isar = await _db;
    final exact = await isar.savedUrls
        .filter()
        .rawUrlEqualTo(rawUrl)
        .findFirst();
    if (exact != null) return exact;

    final canonical = LinkPreviewService.canonicalizeUrl(rawUrl);
    if (canonical != rawUrl) {
      final canonicalExact = await isar.savedUrls
          .filter()
          .rawUrlEqualTo(canonical)
          .findFirst();
      if (canonicalExact != null) return canonicalExact;
    }

    final all = await isar.savedUrls.where().findAll();
    for (final saved in all) {
      if (LinkPreviewService.canonicalizeUrl(saved.rawUrl) == canonical) {
        return saved;
      }
    }
    return null;
  }

  /// Fuzzy / keyword retrieval for natural-language questions (e.g. Ask).
  /// Uses stopword filtering and slightly looser thresholds than library search.
  Future<List<SavedUrl>> fuzzySearchUrls(String query) async {
    final ranked = await _rankedKeywordSearch(query, naturalLanguage: true);
    return ranked.map((e) => e.key).toList();
  }

  /// Computes similarity between two strings (0.0 – 1.0) using
  /// bigram overlap (Dice coefficient) — fast and typo-tolerant.
  static double _similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.length < 2 || b.length < 2) {
      // For very short strings, use prefix match
      if (a.length <= 2 && b.startsWith(a)) return 0.8;
      if (b.length <= 2 && a.startsWith(b)) return 0.8;
      return 0.0;
    }
    final aBigrams = <String>{};
    for (int i = 0; i < a.length - 1; i++) {
      aBigrams.add(a.substring(i, i + 2));
    }
    final bBigrams = <String>{};
    for (int i = 0; i < b.length - 1; i++) {
      bBigrams.add(b.substring(i, i + 2));
    }
    final intersection = aBigrams.intersection(bBigrams).length;
    return (2 * intersection) / (aBigrams.length + bBigrams.length);
  }

  // --------------- UPDATE ---------------

  /// Returns the number of saved URLs that are semantically similar
  /// to the given [embedding] above [threshold] cosine similarity.
  /// Computation runs off the UI isolate.
  Future<int> countSimilarUrls({
    required List<double> embedding,
    double threshold = 0.88,
  }) async {
    if (embedding.isEmpty) return 0;
    final isar = await _db;
    final all = await isar.savedUrls.where().findAll();

    final embeddings = <List<double>>[];
    for (final u in all) {
      final e = u.embedding;
      if (e == null || e.isEmpty) continue;
      embeddings.add(e);
    }
    if (embeddings.isEmpty) return 0;

    return compute(
      _countAboveThresholdIsolate,
      _CosineCountPayload(
        query: embedding,
        embeddings: embeddings,
        threshold: threshold,
      ),
    );
  }

  /// Returns saved URLs with embeddings closest to [queryEmbedding].
  /// Cosine scoring runs off the UI isolate for libraries of any size.
  Future<List<SavedUrl>> semanticSearchUrls(
    List<double> queryEmbedding, {
    int limit = 20,
  }) async {
    final scored = await semanticSearchScored(queryEmbedding, limit: limit);
    return scored.map((e) => e.key).toList();
  }

  /// Returns saved URLs + cosine score pairs (descending). Runs scoring
  /// off the UI isolate.
  Future<List<MapEntry<SavedUrl, double>>> semanticSearchScored(
    List<double> queryEmbedding, {
    int limit = 20,
    double minScore = 0.0,
  }) async {
    if (queryEmbedding.isEmpty) return const [];
    final isar = await _db;
    final all = await isar.savedUrls.where().findAll();

    final ids = <int>[];
    final embeddings = <List<double>>[];
    for (final u in all) {
      final e = u.embedding;
      if (e == null || e.isEmpty) continue;
      ids.add(u.id);
      embeddings.add(e);
    }
    if (ids.isEmpty) return const [];

    final topIds = await compute(
      _topKCosineIsolate,
      _CosineTopKPayload(
        query: queryEmbedding,
        ids: ids,
        embeddings: embeddings,
        limit: limit,
        minScore: minScore,
      ),
    );
    if (topIds.isEmpty) return const [];

    final byId = {for (final u in all) u.id: u};
    final out = <MapEntry<SavedUrl, double>>[];
    for (final row in topIds) {
      final u = byId[row.id];
      if (u != null) out.add(MapEntry(u, row.score));
    }
    return out;
  }

  /// Cosine similarity in [0.0, 1.0] for equal-length embedding vectors.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA) * sqrt(normB);
    return denom == 0 ? 0.0 : dot / denom;
  }

  /// Returns URLs saved between [start] and [end] (inclusive), newest first.
  Future<List<SavedUrl>> getUrlsInDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final isar = await _db;
    return isar.savedUrls
        .filter()
        .savedAtBetween(start, end)
        .sortBySavedAtDesc()
        .findAll();
  }

  Future<void> updateUrl(SavedUrl url) async {
    final isar = await _db;
    await isar.writeTxn(() => isar.savedUrls.put(url));
  }

  Future<void> updateOpenedAt(int urlId, DateTime when) async {
    final isar = await _db;
    await isar.writeTxn(() async {
      final url = await isar.savedUrls.get(urlId);
      if (url != null) {
        url.openedAt = when;
        await isar.savedUrls.put(url);
      }
    });
  }

  /// Mark a link unread (e.g. toggling from the home card).
  Future<void> clearOpenedAt(int urlId) async {
    final isar = await _db;
    await isar.writeTxn(() async {
      final url = await isar.savedUrls.get(urlId);
      if (url != null) {
        url.openedAt = null;
        await isar.savedUrls.put(url);
      }
    });
  }

  Future<void> updateResurfacedAt(int urlId, DateTime when) async {
    final isar = await _db;
    await isar.writeTxn(() async {
      final url = await isar.savedUrls.get(urlId);
      if (url != null) {
        url.resurfacedAt = when;
        await isar.savedUrls.put(url);
      }
    });
  }

  /// Dismiss ([when] non-null) or restore ([when] null) a link from
  /// Rediscovery. Dismissed links are excluded from all resurfacing.
  Future<void> updateRediscoverDismissedAt(int urlId, DateTime? when) async {
    final isar = await _db;
    await isar.writeTxn(() async {
      final url = await isar.savedUrls.get(urlId);
      if (url != null) {
        url.rediscoverDismissedAt = when;
        await isar.savedUrls.put(url);
      }
    });
  }

  /// Set the on-device intent for a save (from a suggested-action chip).
  ///
  /// [status] is 'queued' or 'done'. For 'done' we also stamp [openedAt] when
  /// it was never opened, so completed items count as consumed everywhere that
  /// keys off [openedAt].
  Future<void> updateIntent(
    int urlId, {
    required String status,
    String? action,
    DateTime? revisitAfter,
  }) async {
    final isar = await _db;
    await isar.writeTxn(() async {
      final url = await isar.savedUrls.get(urlId);
      if (url == null) return;
      url.intentStatus = status;
      url.intentAction = action;
      url.intentSetAt = DateTime.now();
      url.revisitAfter = status == 'queued' ? revisitAfter : null;
      if (status == 'done' && url.openedAt == null) {
        url.openedAt = DateTime.now();
      }
      await isar.savedUrls.put(url);
    });
  }

  /// Clear any intent (toggle a chip back off).
  Future<void> clearIntent(int urlId) async {
    final isar = await _db;
    await isar.writeTxn(() async {
      final url = await isar.savedUrls.get(urlId);
      if (url == null) return;
      url.intentStatus = null;
      url.intentAction = null;
      url.intentSetAt = null;
      url.revisitAfter = null;
      await isar.savedUrls.put(url);
    });
  }

  /// Archived ("done") links, newest-first — backs the Done/Archive view.
  Future<List<SavedUrl>> getArchivedUrls() async {
    final isar = await _db;
    return isar.savedUrls
        .filter()
        .intentStatusEqualTo('done')
        .sortBySavedAtDesc()
        .findAll();
  }

  /// Unread links: [openedAt] is null, optional filters for rediscovery/digest.
  Future<List<SavedUrl>> getUnreadLinks({
    DateTime? savedBefore,
    DateTime? notResurfacedSince,
    int limit = 3,
  }) async {
    final isar = await _db;
    final all = await isar.savedUrls.where().sortBySavedAt().findAll();
    final out = <SavedUrl>[];
    for (final u in all) {
      if (u.openedAt != null) continue;
      if (savedBefore != null && !u.savedAt.isBefore(savedBefore)) continue;
      if (notResurfacedSince != null) {
        final r = u.resurfacedAt;
        if (r != null && r.isAfter(notResurfacedSince)) continue;
      }
      out.add(u);
      if (out.length >= limit) break;
    }
    return out;
  }

  // --------------- NOTIFICATION QUERIES ---------------

  /// Number of unread links per primary category.
  Future<Map<String, int>> getUnreadCountByCategory() async {
    final isar = await _db;
    final all = await isar.savedUrls.where().findAll();
    final counts = <String, int>{};
    for (final u in all) {
      if (u.openedAt != null) continue;
      final cat = u.effectiveCategories.firstOrNull ?? 'Other';
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    return counts;
  }

  /// Links from the last 7 days grouped by category with read status.
  Future<Map<String, List<SavedUrl>>> getWeeklyDigestData() async {
    final isar = await _db;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final all = await isar.savedUrls.where().sortBySavedAtDesc().findAll();
    final grouped = <String, List<SavedUrl>>{};
    for (final u in all) {
      if (u.savedAt.isBefore(cutoff)) continue;
      final cat = u.effectiveCategories.firstOrNull ?? 'Other';
      (grouped[cat] ??= []).add(u);
    }
    return grouped;
  }

  /// Single oldest unread link saved more than [minAge] ago.
  Future<SavedUrl?> getOldestUnreadLink({
    Duration minAge = const Duration(days: 14),
  }) async {
    final isar = await _db;
    final cutoff = DateTime.now().subtract(minAge);
    final all = await isar.savedUrls.where().sortBySavedAt().findAll();
    for (final u in all) {
      if (u.openedAt != null) continue;
      if (u.savedAt.isBefore(cutoff)) return u;
    }
    return null;
  }

  /// Number of consecutive recent days on which the user saved at least one link.
  Future<int> getSavingStreakDays() async {
    final isar = await _db;
    final all = await isar.savedUrls.where().sortBySavedAtDesc().findAll();
    if (all.isEmpty) return 0;

    final daysWithSaves = <int>{};
    final now = DateTime.now();
    for (final u in all) {
      daysWithSaves.add(
        DateTime(
          u.savedAt.year,
          u.savedAt.month,
          u.savedAt.day,
        ).difference(DateTime(now.year, now.month, now.day)).inDays,
      );
    }

    var streak = 0;
    for (var d = 0; d <= 365; d++) {
      if (daysWithSaves.contains(-d)) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// True if the user has opened zero links in the last [days] days.
  Future<bool> hasOpenedNothingRecently({int days = 7}) async {
    final isar = await _db;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final all = await isar.savedUrls.where().findAll();
    for (final u in all) {
      final o = u.openedAt;
      if (o != null && o.isAfter(cutoff)) return false;
    }
    return true;
  }

  /// Count of all unread links.
  Future<int> getTotalUnreadCount() async {
    final isar = await _db;
    final all = await isar.savedUrls.where().findAll();
    return all.where((u) => u.openedAt == null).length;
  }

  /// Count of links saved in the last [days] days.
  Future<int> getRecentSaveCount({int days = 7}) async {
    final isar = await _db;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final all = await isar.savedUrls.where().findAll();
    return all.where((u) => u.savedAt.isAfter(cutoff)).length;
  }

  /// Mark all unread links in [category] as read.
  Future<void> markCategoryRead(String category) async {
    final isar = await _db;
    final all = await isar.savedUrls.where().findAll();
    await isar.writeTxn(() async {
      for (final u in all) {
        if (u.openedAt != null) continue;
        if (!u.effectiveCategories.contains(category)) continue;
        u.openedAt = DateTime.now();
        await isar.savedUrls.put(u);
      }
    });
  }

  // --------------- COLLECTIONS ---------------

  Future<List<UserCollection>> getAllCollections() async {
    final isar = await _db;
    return isar.userCollections.where().sortByCreatedAtDesc().findAll();
  }

  Future<UserCollection?> getCollectionById(int id) async {
    final isar = await _db;
    return isar.userCollections.get(id);
  }

  Future<UserCollection> createCollection({
    required String name,
    required String emoji,
    String? description,
  }) async {
    final isar = await _db;
    final c = UserCollection()
      ..name = name
      ..emoji = emoji
      ..description = description
      ..createdAt = DateTime.now()
      ..urlIds = []
      ..urlAddedAts = [];
    await isar.writeTxn(() async {
      await isar.userCollections.put(c);
    });
    return c;
  }

  Future<void> addUrlToCollection({
    required int collectionId,
    required int urlId,
  }) async {
    final isar = await _db;
    var added = false;
    await isar.writeTxn(() async {
      final c = await isar.userCollections.get(collectionId);
      if (c == null) return;
      if (!c.urlIds.contains(urlId)) {
        c.urlIds = [...c.urlIds, urlId];
        await isar.userCollections.put(c);
        added = true;
      }
    });
    if (added) {
      await _setCollectionAddedAt(collectionId, urlId, DateTime.now());
    }
  }

  Future<void> addUrlsToCollection({
    required int collectionId,
    required List<int> urlIds,
  }) async {
    final isar = await _db;
    final addedIds = <int>[];
    await isar.writeTxn(() async {
      final c = await isar.userCollections.get(collectionId);
      if (c == null) return;
      final updated = <int>[...c.urlIds];
      for (final id in urlIds) {
        if (!updated.contains(id)) {
          updated.add(id);
          addedIds.add(id);
        }
      }
      c.urlIds = updated;
      await isar.userCollections.put(c);
    });
    if (addedIds.isNotEmpty) {
      final now = DateTime.now();
      for (final id in addedIds) {
        await _setCollectionAddedAt(collectionId, id, now);
      }
    }
  }

  Future<void> removeUrlFromCollection({
    required int collectionId,
    required int urlId,
  }) async {
    final isar = await _db;
    var removed = false;
    await isar.writeTxn(() async {
      final c = await isar.userCollections.get(collectionId);
      if (c == null) return;
      removed = c.urlIds.contains(urlId);
      c.urlIds = c.urlIds.where((id) => id != urlId).toList();
      await isar.userCollections.put(c);
    });
    if (removed) {
      await _removeCollectionAddedAt(collectionId, urlId);
    }
  }

  Future<void> deleteCollection(int id) async {
    final isar = await _db;
    await isar.writeTxn(() => isar.userCollections.delete(id));
    await _removeCollectionAddedAtPrefix(id);
  }

  Future<void> updateCollection(UserCollection collection) async {
    final isar = await _db;
    await isar.writeTxn(() => isar.userCollections.put(collection));
  }

  Future<List<SavedUrl>> getUrlsInCollection(int collectionId) async {
    final isar = await _db;
    final c = await isar.userCollections.get(collectionId);
    if (c == null) return [];
    final out = <SavedUrl>[];
    for (final id in c.urlIds) {
      final u = await isar.savedUrls.get(id);
      if (u != null) out.add(u);
    }
    out.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return out;
  }

  // --------------- DELETE ---------------

  Future<bool> deleteUrl(int id) async {
    final isar = await _db;
    final removedFromCollections = <int>[];
    final ok = await isar.writeTxn(() async {
      final ok = await isar.savedUrls.delete(id);
      if (ok) {
        final collections = await isar.userCollections.where().findAll();
        for (final col in collections) {
          if (col.urlIds.contains(id)) {
            col.urlIds = col.urlIds.where((x) => x != id).toList();
            await isar.userCollections.put(col);
            removedFromCollections.add(col.id);
          }
        }
      }
      return ok;
    });
    if (ok) {
      for (final collectionId in removedFromCollections) {
        await _removeCollectionAddedAt(collectionId, id);
      }
    }
    return ok;
  }

  Future<DateTime?> getLatestCollectionAddedAt(
    UserCollection collection,
  ) async {
    DateTime? latest;
    for (final urlId in collection.urlIds) {
      final value = await _getCollectionAddedAt(collection.id, urlId);
      if (value != null && (latest == null || value.isAfter(latest))) {
        latest = value;
      }
    }
    return latest;
  }

  Future<void> _setCollectionAddedAt(
    int collectionId,
    int urlId,
    DateTime value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _collectionAddedAtKey(collectionId, urlId),
      value.toIso8601String(),
    );
  }

  Future<DateTime?> _getCollectionAddedAt(int collectionId, int urlId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_collectionAddedAtKey(collectionId, urlId));
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _removeCollectionAddedAt(int collectionId, int urlId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_collectionAddedAtKey(collectionId, urlId));
  }

  Future<void> _removeCollectionAddedAtPrefix(int collectionId) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'collection_added_at_${collectionId}_';
    for (final key in prefs.getKeys()) {
      if (key.startsWith(prefix)) {
        await prefs.remove(key);
      }
    }
  }

  String _collectionAddedAtKey(int collectionId, int urlId) {
    return 'collection_added_at_${collectionId}_$urlId';
  }

  Future<void> deleteUrlsByCategory(String category) async {
    final isar = await _db;
    final allUrls = await isar.savedUrls.where().findAll();
    await isar.writeTxn(() async {
      for (final url in allUrls) {
        if (!url.effectiveCategories.contains(category)) continue;

        final remaining = url.effectiveCategories
            .where((item) => item != category)
            .toList();

        if (remaining.isEmpty) {
          await isar.savedUrls.delete(url.id);
          continue;
        }

        url.categories = remaining;
        if (url.category == category) {
          url.category = remaining.first;
          url.categoryEmoji = CategoryResolver.emojiForCategory(
            remaining.first,
          );
        }
        await isar.savedUrls.put(url);
      }
    });
  }

  Future<void> deleteAll() async {
    final isar = await _db;
    await isar.writeTxn(() async {
      await isar.savedUrls.clear();
      await isar.userCollections.clear();
    });
    await SessionTrackingService().clear();
  }

  // --------------- STREAM ---------------

  Stream<List<SavedUrl>> watchAllUrls() async* {
    final isar = await _db;
    yield* isar.savedUrls.where().sortBySavedAtDesc().watch(
      fireImmediately: true,
    );
  }
}

// ─── Isolate payloads + entry points ─────────────────────────────────────────

class _CosineTopKPayload {
  const _CosineTopKPayload({
    required this.query,
    required this.ids,
    required this.embeddings,
    required this.limit,
    required this.minScore,
  });

  final List<double> query;
  final List<int> ids;
  final List<List<double>> embeddings;
  final int limit;
  final double minScore;
}

class _CosineCountPayload {
  const _CosineCountPayload({
    required this.query,
    required this.embeddings,
    required this.threshold,
  });

  final List<double> query;
  final List<List<double>> embeddings;
  final double threshold;
}

class ScoredUrlId {
  const ScoredUrlId(this.id, this.score);
  final int id;
  final double score;
}

double _cosine(List<double> a, List<double> b) {
  if (a.length != b.length) return 0.0;
  double dot = 0, normA = 0, normB = 0;
  for (int i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  final denom = sqrt(normA) * sqrt(normB);
  return denom == 0 ? 0.0 : dot / denom;
}

List<ScoredUrlId> _topKCosineIsolate(_CosineTopKPayload p) {
  final scored = <ScoredUrlId>[];
  for (var i = 0; i < p.ids.length; i++) {
    final s = _cosine(p.query, p.embeddings[i]);
    if (s > p.minScore) scored.add(ScoredUrlId(p.ids[i], s));
  }
  scored.sort((a, b) => b.score.compareTo(a.score));
  if (scored.length <= p.limit) return scored;
  return scored.sublist(0, p.limit);
}

int _countAboveThresholdIsolate(_CosineCountPayload p) {
  var count = 0;
  for (final emb in p.embeddings) {
    if (_cosine(p.query, emb) >= p.threshold) count++;
  }
  return count;
}
