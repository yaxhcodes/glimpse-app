import 'dart:math';
import '../models/saved_url.dart';

/// Service for semantic search using cosine similarity over embeddings.
class SearchService {
  /// Computes cosine similarity between two vectors.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0.0;

    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denominator = sqrt(normA) * sqrt(normB);
    if (denominator == 0) return 0.0;

    return dot / denominator;
  }

  /// Runs semantic search over all saved URLs.
  ///
  /// Returns the top [limit] results sorted by cosine similarity
  /// to the [queryEmbedding].
  static List<SavedUrl> semanticSearch({
    required List<double> queryEmbedding,
    required List<SavedUrl> allUrls,
    int limit = 10,
  }) {
    if (queryEmbedding.isEmpty) return [];

    final scored = <MapEntry<SavedUrl, double>>[];

    for (final url in allUrls) {
      if (url.embedding.isEmpty) continue;
      final similarity = cosineSimilarity(queryEmbedding, url.embedding);
      scored.add(MapEntry(url, similarity));
    }

    // Sort descending by similarity
    scored.sort((a, b) => b.value.compareTo(a.value));

    return scored.take(limit).map((e) => e.key).toList();
  }
}
