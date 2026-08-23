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
    bool centroidValidated = false,
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
        if (centroidValidated)
          'category_validation': {
            'method': 'embedding_centroid',
            'suggested_category': category,
          },
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
    expect(food.suggestedCategory, 'Philosophy');
    expect(food.suggestedSimilarity, philosophy.similarity);
    expect(philosophy.isReliable, isTrue);
    expect(
      philosophy.similarity,
      greaterThan(DomainCentroidService.similarityFloor),
    );
  });

  test(
    'suggests stronger category even when claimed category is plausible',
    () {
      final service = DomainCentroidService(null);
      service.rebuildCentroidsFromUrls([
        for (var i = 0; i < 5; i += 1)
          url(id: i, category: 'Education', embedding: [0.72, 0.18 + 0.01 * i]),
        for (var i = 0; i < 5; i += 1)
          url(
            id: 10 + i,
            category: 'Philosophy',
            embedding: [0.18, 0.72 + 0.01 * i],
          ),
      ]);

      final result = service.validateCached(
        claimedCategory: 'Education',
        saveEmbedding: [0.34, 0.9],
      );

      expect(result.isReliable, isTrue);
      expect(
        result.similarity,
        greaterThan(DomainCentroidService.similarityFloor),
      );
      expect(result.suggestedCategory, 'Philosophy');
      expect(
        result.suggestedSimilarity,
        greaterThan(result.similarity + DomainCentroidService.correctionMargin),
      );
    },
  );

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

  test('does not train on categories assigned by centroid correction', () {
    final service = DomainCentroidService(null);
    service.rebuildCentroidsFromUrls([
      for (var i = 0; i < 5; i += 1)
        url(
          id: i,
          category: 'Health',
          embedding: [1, 0],
          centroidValidated: true,
        ),
    ]);

    final result = service.validateCached(
      claimedCategory: 'Health',
      saveEmbedding: [1, 0],
    );

    expect(result.isReliable, isFalse);
    expect(result.centroidSampleSize, 0);
  });

  test('does not let an established category capture a cold category', () {
    final service = DomainCentroidService(null);
    service.rebuildCentroidsFromUrls([
      for (var i = 0; i < 5; i += 1)
        url(id: i, category: 'Health', embedding: [1, 0]),
      url(id: 10, category: 'Education', embedding: [0, 1]),
    ]);

    final result = service.validateCached(
      claimedCategory: 'Education',
      saveEmbedding: [1, 0],
    );

    expect(result.isReliable, isFalse);
    expect(result.suggestedCategory, isNull);
  });

  test('does not auto-correct from a moderate semantic match', () {
    final service = DomainCentroidService(null);
    service.rebuildCentroidsFromUrls([
      for (var i = 0; i < 5; i += 1)
        url(id: i, category: 'Health', embedding: [1, 0, 0]),
      for (var i = 0; i < 5; i += 1)
        url(id: 10 + i, category: 'Education', embedding: [0, 1, 0]),
    ]);

    final result = service.validateCached(
      claimedCategory: 'Education',
      saveEmbedding: [0.70, 0.50, 0.509901951],
    );

    expect(result.isReliable, isTrue);
    expect(result.suggestedCategory, isNull);
  });

  test('retains a high-confidence canonical claim without a better match', () {
    final service = DomainCentroidService(null);
    service.rebuildCentroidsFromUrls([
      for (var i = 0; i < 5; i += 1)
        url(id: i, category: 'Philosophy', embedding: [1, 0.02 * i]),
    ]);

    final result = service.validateCached(
      claimedCategory: 'Philosophy',
      saveEmbedding: [0, 1],
    );

    expect(result.isReliable, isTrue);
    expect(result.similarity, lessThan(DomainCentroidService.similarityFloor));
    expect(result.suggestedCategory, isNull);
    expect(
      DomainCentroidService.shouldRetainHighConfidenceClaim(
        claimedCategory: 'Philosophy',
        claimedConfidence: 0.9,
        validation: result,
      ),
      isTrue,
    );
    expect(
      DomainCentroidService.shouldRetainHighConfidenceClaim(
        claimedCategory: 'Philosophy',
        claimedConfidence: 0.6,
        validation: result,
      ),
      isFalse,
    );
  });
}
