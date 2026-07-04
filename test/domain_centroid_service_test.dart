import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/domain_centroid_service.dart';

void main() {
  SavedUrl url({
    required int id,
    required String category,
    required List<double> embedding,
    double confidence = 0.9,
  }) {
    return SavedUrl()
      ..id = id
      ..rawUrl = 'https://example.com/$id'
      ..domain = 'example.com'
      ..title = 'Saved item $id'
      ..description = ''
      ..category = category
      ..categoryEmoji = ''
      ..categories = [category]
      ..tags = const []
      ..savedAt = DateTime(2026)
      ..embedding = embedding
      ..enrichmentJson = jsonEncode({
        'category': category,
        'category_confidence': confidence,
      });
  }

  test('rejects lexical-bleed category when centroid evidence disagrees', () {
    final service = DomainCentroidService(null);
    service.rebuildCentroidsFromUrls([
      for (var i = 0; i < 5; i += 1)
        url(id: i, category: 'Food', embedding: [1, 0.04 * i]),
      for (var i = 0; i < 5; i += 1)
        url(id: 10 + i, category: 'Philosophy', embedding: [0.04 * i, 1]),
    ]);

    final dinnerDebateBooks = [0.2, 1.0];
    final food = service.validateCached(
      claimedCategory: 'Food',
      saveEmbedding: dinnerDebateBooks,
    );
    final philosophy = service.validateCached(
      claimedCategory: 'Philosophy',
      saveEmbedding: dinnerDebateBooks,
    );

    expect(food.isReliable, isTrue);
    expect(food.similarity, lessThan(DomainCentroidService.similarityFloor));
    expect(philosophy.isReliable, isTrue);
    expect(
      philosophy.similarity,
      greaterThan(DomainCentroidService.similarityFloor),
    );
  });

  test('does not validate against cold-start centroids', () {
    final service = DomainCentroidService(null);
    service.rebuildCentroidsFromUrls([
      for (var i = 0; i < 2; i += 1)
        url(id: i, category: 'Food', embedding: [1, 0]),
    ]);

    final result = service.validateCached(
      claimedCategory: 'Food',
      saveEmbedding: [0, 1],
    );

    expect(result.isReliable, isFalse);
    expect(result.centroidSampleSize, 2);
  });

  test('ignores low-confidence labels while building centroids', () {
    final service = DomainCentroidService(null);
    service.rebuildCentroidsFromUrls([
      for (var i = 0; i < 5; i += 1)
        url(id: i, category: 'Food', embedding: [1, 0], confidence: 0.4),
    ]);

    final result = service.validateCached(
      claimedCategory: 'Food',
      saveEmbedding: [1, 0],
    );

    expect(result.isReliable, isFalse);
    expect(result.centroidSampleSize, 0);
  });
}
