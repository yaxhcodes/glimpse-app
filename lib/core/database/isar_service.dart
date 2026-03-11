import 'dart:math';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/saved_url.dart';
import '../services/category_resolver.dart';

/// Service handling all local database operations via Isar.
class IsarService {
  late Future<Isar> _db;

  IsarService() {
    _db = _openDb();
  }

  Future<Isar> _openDb() async {
    final dir = await getApplicationDocumentsDirectory();
    return Isar.open(
      [SavedUrlSchema],
      directory: dir.path,
    );
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

  Future<SavedUrl?> getUrlById(int id) async {
    final isar = await _db;
    return isar.savedUrls.get(id);
  }

  Future<List<SavedUrl>> getUrlsByCategory(String category) async {
    final isar = await _db;
    final allUrls = await isar.savedUrls.where().sortBySavedAtDesc().findAll();
    return allUrls
      .where((url) => url.effectiveCategories.contains(category))
      .toList();
  }

  /// Returns a list of unique categories with their emoji and count.
  Future<List<Map<String, dynamic>>> getCategories() async {
    final isar = await _db;
    final allUrls = await isar.savedUrls.where().findAll();

    final Map<String, Map<String, dynamic>> categoryMap = {};
    for (final url in allUrls) {
      for (final category in url.effectiveCategories) {
        if (categoryMap.containsKey(category)) {
          categoryMap[category]!['count'] =
              (categoryMap[category]!['count'] as int) + 1;
        } else {
          categoryMap[category] = {
            'category': category,
            'emoji': CategoryResolver.emojiForCategory(
              category,
              fallbackEmoji: category == url.category ? url.categoryEmoji : null,
            ),
            'count': 1,
          };
        }
      }
    }
    return categoryMap.values.toList();
  }

  /// Simple keyword search (LIKE-style) for Phase 1.
  /// Searches title, description, tags, categories, domain, rawUrl, and userNotes.
  Future<List<SavedUrl>> searchUrls(String query) async {
    final isar = await _db;
    final lowerQuery = query.toLowerCase();
    return isar.savedUrls
        .filter()
        .titleContains(lowerQuery, caseSensitive: false)
        .or()
        .descriptionContains(lowerQuery, caseSensitive: false)
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
        .sortBySavedAtDesc()
        .findAll();
  }

  /// Check if a URL already exists in the database.
  Future<SavedUrl?> findByRawUrl(String rawUrl) async {
    final isar = await _db;
    return isar.savedUrls.filter().rawUrlEqualTo(rawUrl).findFirst();
  }

  /// Fuzzy search: fetches all URLs and scores them against the query.
  /// Handles typos by checking character-level similarity.
  Future<List<SavedUrl>> fuzzySearchUrls(String query) async {
    final isar = await _db;
    final allUrls = await isar.savedUrls.where().sortBySavedAtDesc().findAll();
    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.isEmpty) return [];

    final queryWords = lowerQuery.split(RegExp(r'\s+'));
    final scored = <MapEntry<SavedUrl, double>>[];

    for (final url in allUrls) {
      // Build searchable text from all fields
      final fields = [
        url.title,
        url.description,
        url.domain,
        url.rawUrl,
        url.category,
        ...url.effectiveCategories,
        url.userNotes ?? '',
        ...url.tags,
      ].join(' ').toLowerCase();

      double bestScore = 0;
      for (final word in queryWords) {
        // Exact substring match = highest score
        if (fields.contains(word)) {
          bestScore += 1.0;
          continue;
        }
        // Fuzzy: check each word in fields for similarity
        final fieldWords = fields.split(RegExp(r'[\s\-_/.,;:!?()\[\]{}]+'));
        double wordBest = 0;
        for (final fw in fieldWords) {
          if (fw.isEmpty) continue;
          final sim = _similarity(word, fw);
          if (sim > wordBest) wordBest = sim;
        }
        bestScore += wordBest;
      }

      final avgScore = bestScore / queryWords.length;
      // Threshold: at least 0.55 similarity
      if (avgScore >= 0.55) {
        scored.add(MapEntry(url, avgScore));
      }
    }

    // Sort by score descending
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
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
  Future<int> countSimilarUrls({
    required List<double> embedding,
    double threshold = 0.88,
  }) async {
    if (embedding.isEmpty) return 0;
    final isar = await _db;
    final allUrls = await isar.savedUrls.where().findAll();
    int count = 0;
    for (final url in allUrls) {
      if (url.embedding.isEmpty) continue;
      final sim = _cosineSimilarity(embedding, url.embedding);
      if (sim >= threshold) count++;
    }
    return count;
  }

  /// Returns saved URLs with embeddings closest to [queryEmbedding].
  Future<List<SavedUrl>> semanticSearchUrls(
    List<double> queryEmbedding, {
    int limit = 20,
  }) async {
    if (queryEmbedding.isEmpty) return [];
    final isar = await _db;
    final allUrls = await isar.savedUrls.where().findAll();

    final scored = <MapEntry<SavedUrl, double>>[];
    for (final url in allUrls) {
      if (url.embedding.isEmpty) continue;
      final sim = _cosineSimilarity(queryEmbedding, url.embedding);
      scored.add(MapEntry(url, sim));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((e) => e.key).toList();
  }

  static double _cosineSimilarity(List<double> a, List<double> b) {
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
      DateTime start, DateTime end) async {
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

  // --------------- DELETE ---------------

  Future<bool> deleteUrl(int id) async {
    final isar = await _db;
    return isar.writeTxn(() => isar.savedUrls.delete(id));
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
          url.categoryEmoji = CategoryResolver.emojiForCategory(remaining.first);
        }
        await isar.savedUrls.put(url);
      }
    });
  }

  Future<void> deleteAll() async {
    final isar = await _db;
    await isar.writeTxn(() => isar.savedUrls.clear());
  }

  // --------------- STREAM ---------------

  Stream<List<SavedUrl>> watchAllUrls() async* {
    final isar = await _db;
    yield* isar.savedUrls
        .where()
        .sortBySavedAtDesc()
        .watch(fireImmediately: true);
  }
}
