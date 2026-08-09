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
    this.suggestedCategory,
    this.suggestedSimilarity = 0,
    this.suggestedSampleSize = 0,
  });

  final double similarity;
  final int centroidSampleSize;
  final bool isReliable;
  final String? suggestedCategory;
  final double suggestedSimilarity;
  final int suggestedSampleSize;

  bool get hasCorrectionSuggestion => suggestedCategory != null;
}

class DomainCentroidService {
  DomainCentroidService(this._isarService);

  final IsarService? _isarService;

  static const minSampleSizeForReliableCentroid = 5;
  static const similarityFloor = 0.5;
  static const highConfidenceFloor = 0.75;
  static const correctionSimilarityFloor = 0.75;
  static const correctionMargin = 0.08;

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
      if (!_isEligibleCentroidSeed(url)) continue;
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
    if (saveEmbedding.isEmpty) {
      return DomainCentroidResult(
        similarity: 0,
        centroidSampleSize: sampleSize,
        isReliable: false,
      );
    }

    final normalizedSave = _normalize(saveEmbedding);
    final isReliable = sampleSize >= minSampleSizeForReliableCentroid;
    final claimedSimilarity =
        centroid == null || saveEmbedding.length != centroid.length
        ? 0.0
        : _cosineSimilarity(centroid, normalizedSave);
    final suggested = isReliable
        ? _bestCorrectionCandidate(
            normalizedSave,
            claimedCategory: normalizedCategory,
            claimedSimilarity: claimedSimilarity,
          )
        : null;

    return DomainCentroidResult(
      similarity: claimedSimilarity,
      centroidSampleSize: sampleSize,
      isReliable: isReliable,
      suggestedCategory: suggested?.category,
      suggestedSimilarity: suggested?.similarity ?? 0,
      suggestedSampleSize: suggested?.sampleSize ?? 0,
    );
  }

  _CorrectionCandidate? _bestCorrectionCandidate(
    List<double> normalizedSave, {
    required String claimedCategory,
    required double claimedSimilarity,
  }) {
    _CorrectionCandidate? best;
    for (final entry in _centroidCache.entries) {
      final category = entry.key;
      if (category == claimedCategory) continue;
      final sampleSize = _sampleSizeCache[category] ?? 0;
      if (sampleSize < minSampleSizeForReliableCentroid) continue;
      final centroid = entry.value;
      if (centroid.length != normalizedSave.length) continue;
      final similarity = _cosineSimilarity(centroid, normalizedSave);
      if (similarity < correctionSimilarityFloor) continue;
      if (similarity < claimedSimilarity + correctionMargin) continue;
      if (best == null || similarity > best.similarity) {
        best = _CorrectionCandidate(
          category: category,
          similarity: similarity,
          sampleSize: sampleSize,
        );
      }
    }
    return best;
  }

  static bool _isEligibleCentroidSeed(SavedUrl url) {
    final raw = url.enrichmentJson;
    if (raw == null || raw.trim().isEmpty) return false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      if (decoded['category_validation'] is Map) return false;
      final value =
          decoded['category_confidence'] ??
          decoded['domain_confidence'] ??
          decoded['confidence'];
      if (value is num) {
        return value.toDouble().clamp(0, 1).toDouble() >= highConfidenceFloor;
      }
      if (value is String) {
        return (double.tryParse(value) ?? 0).clamp(0, 1).toDouble() >=
            highConfidenceFloor;
      }
      return false;
    } catch (_) {
      return false;
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

class _CorrectionCandidate {
  const _CorrectionCandidate({
    required this.category,
    required this.similarity,
    required this.sampleSize,
  });

  final String category;
  final double similarity;
  final int sampleSize;
}
