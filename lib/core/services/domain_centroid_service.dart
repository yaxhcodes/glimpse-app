import 'dart:convert';
import 'dart:math';

import '../database/isar_service.dart';
import '../models/saved_url.dart';
import 'category_taxonomy.dart';

class DomainCentroidResult {
  const DomainCentroidResult({
    required this.similarity,
    required this.centroidSampleSize,
    required this.isReliable,
  });

  final double similarity;
  final int centroidSampleSize;
  final bool isReliable;
}

class DomainCentroidService {
  DomainCentroidService(this._isarService);

  final IsarService? _isarService;

  static const minSampleSizeForReliableCentroid = 5;
  static const similarityFloor = 0.5;
  static const highConfidenceFloor = 0.75;

  final Map<String, List<double>> _centroidCache = {};
  final Map<String, int> _sampleSizeCache = {};
  DateTime? _cacheBuiltAt;

  Future<void> rebuildCentroids() async {
    final isarService = _isarService;
    if (isarService == null) {
      throw StateError('IsarService is required to rebuild centroids from DB');
    }
    rebuildCentroidsFromUrls(await isarService.getUrlsWithEmbeddings());
  }

  void rebuildCentroidsFromUrls(Iterable<SavedUrl> urls) {
    _centroidCache.clear();
    _sampleSizeCache.clear();

    final byCategory = <String, List<List<double>>>{};
    for (final url in urls) {
      final embedding = url.embedding;
      if (embedding == null || embedding.isEmpty) continue;
      final category = CategoryTaxonomy.normalize(
        category: url.category,
        tags: url.tags,
      ).name;
      if (category == 'Other') continue;
      if (_categoryConfidence(url) < highConfidenceFloor) continue;
      byCategory.putIfAbsent(category, () => <List<double>>[]).add(embedding);
    }

    for (final entry in byCategory.entries) {
      final embeddings = entry.value.where((item) => item.isNotEmpty).toList();
      if (embeddings.isEmpty) continue;
      final dimension = embeddings.first.length;
      if (dimension == 0) continue;
      final centroid = List<double>.filled(dimension, 0);
      var usable = 0;
      for (final embedding in embeddings) {
        if (embedding.length != dimension) continue;
        usable += 1;
        for (var i = 0; i < dimension; i += 1) {
          centroid[i] += embedding[i];
        }
      }
      if (usable == 0) continue;
      for (var i = 0; i < dimension; i += 1) {
        centroid[i] /= usable;
      }
      _centroidCache[entry.key] = _normalize(centroid);
      _sampleSizeCache[entry.key] = usable;
    }
    _cacheBuiltAt = DateTime.now();
  }

  Future<DomainCentroidResult> validate({
    required String claimedCategory,
    required List<double> saveEmbedding,
  }) async {
    if (_cacheBuiltAt == null) {
      await rebuildCentroids();
    }
    return validateCached(
      claimedCategory: claimedCategory,
      saveEmbedding: saveEmbedding,
    );
  }

  DomainCentroidResult validateCached({
    required String claimedCategory,
    required List<double> saveEmbedding,
  }) {
    final normalizedCategory = CategoryTaxonomy.normalize(
      category: claimedCategory,
    ).name;
    final centroid = _centroidCache[normalizedCategory];
    final sampleSize = _sampleSizeCache[normalizedCategory] ?? 0;
    if (centroid == null || saveEmbedding.isEmpty) {
      return DomainCentroidResult(
        similarity: 0,
        centroidSampleSize: sampleSize,
        isReliable: false,
      );
    }
    if (saveEmbedding.length != centroid.length) {
      return DomainCentroidResult(
        similarity: 0,
        centroidSampleSize: sampleSize,
        isReliable: false,
      );
    }

    final normalizedSave = _normalize(saveEmbedding);
    return DomainCentroidResult(
      similarity: _cosineSimilarity(centroid, normalizedSave),
      centroidSampleSize: sampleSize,
      isReliable: sampleSize >= minSampleSizeForReliableCentroid,
    );
  }

  static double _categoryConfidence(SavedUrl url) {
    final raw = url.enrichmentJson;
    if (raw == null || raw.trim().isEmpty) return 0;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return 0;
      final value =
          decoded['category_confidence'] ??
          decoded['domain_confidence'] ??
          decoded['confidence'];
      if (value is num) return value.toDouble().clamp(0, 1).toDouble();
      if (value is String) {
        return (double.tryParse(value) ?? 0).clamp(0, 1).toDouble();
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  static List<double> _normalize(List<double> vector) {
    final norm = sqrt(vector.fold<double>(0, (sum, x) => sum + x * x));
    if (norm == 0) return List<double>.from(vector);
    return vector.map((x) => x / norm).toList();
  }

  static double _cosineSimilarity(List<double> a, List<double> b) {
    var dot = 0.0;
    for (var i = 0; i < a.length; i += 1) {
      dot += a[i] * b[i];
    }
    return dot;
  }
}
