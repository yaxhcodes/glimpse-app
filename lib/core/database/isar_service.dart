import 'dart:math';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/saved_url.dart';
import '../models/user_collection.dart';
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
      [SavedUrlSchema, UserCollectionSchema],
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

  /// Local keyword / fuzzy search (fallback when semantic search is unavailable).
  Future<List<SavedUrl>> keywordSearch(String query) => fuzzySearchUrls(query);

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
      final emb = url.embedding;
      if (emb == null || emb.isEmpty) continue;
      final sim = cosineSimilarity(embedding, emb);
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
      final emb = url.embedding;
      if (emb == null || emb.isEmpty) continue;
      final sim = cosineSimilarity(queryEmbedding, emb);
      scored.add(MapEntry(url, sim));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((e) => e.key).toList();
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
      ..urlIds = [];
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
    await isar.writeTxn(() async {
      final c = await isar.userCollections.get(collectionId);
      if (c == null) return;
      if (!c.urlIds.contains(urlId)) {
        c.urlIds = [...c.urlIds, urlId];
        await isar.userCollections.put(c);
      }
    });
  }

  Future<void> removeUrlFromCollection({
    required int collectionId,
    required int urlId,
  }) async {
    final isar = await _db;
    await isar.writeTxn(() async {
      final c = await isar.userCollections.get(collectionId);
      if (c == null) return;
      c.urlIds = c.urlIds.where((id) => id != urlId).toList();
      await isar.userCollections.put(c);
    });
  }

  Future<void> deleteCollection(int id) async {
    final isar = await _db;
    await isar.writeTxn(() => isar.userCollections.delete(id));
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
    return isar.writeTxn(() async {
      final ok = await isar.savedUrls.delete(id);
      if (ok) {
        final collections = await isar.userCollections.where().findAll();
        for (final col in collections) {
          if (col.urlIds.contains(id)) {
            col.urlIds = col.urlIds.where((x) => x != id).toList();
            await isar.userCollections.put(col);
          }
        }
      }
      return ok;
    });
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
    await isar.writeTxn(() async {
      await isar.savedUrls.clear();
      await isar.userCollections.clear();
    });
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
