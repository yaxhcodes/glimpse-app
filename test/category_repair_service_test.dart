import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/category_repair_service.dart';

void main() {
  SavedUrl correctedUrl({
    String currentCategory = 'Health',
    String storedCategory = 'Health',
    String originalCategory = 'Education',
    int claimedSampleSize = 1,
    double suggestedSimilarity = 0.57,
  }) {
    return SavedUrl()
      ..id = 1
      ..rawUrl = 'https://example.com/save'
      ..domain = 'example.com'
      ..title = 'Japanese language learning resources'
      ..description = ''
      ..category = currentCategory
      ..categoryEmoji = '❤️'
      ..categories = [currentCategory, 'Business']
      ..tags = const ['education', 'language learning']
      ..savedAt = DateTime(2026)
      ..enrichmentJson = jsonEncode({
        'category': storedCategory,
        'category_confidence': 0.9,
        'original_gemini_category': originalCategory,
        'category_validation': {
          'method': 'embedding_centroid',
          'centroid_sample_size': claimedSampleSize,
          'suggested_category': storedCategory,
          'suggested_similarity': suggestedSimilarity,
        },
      });
  }

  test('restores a category captured from a cold centroid', () {
    final url = correctedUrl();

    final changed = CategoryRepairService.repairUnsafeCentroidCategory(url);

    expect(changed, isTrue);
    expect(url.category, 'Education');
    expect(url.categoryEmoji, '📘');
    expect(url.categories, ['Education', 'Business']);

    final enrichment = jsonDecode(url.enrichmentJson!) as Map<String, dynamic>;
    expect(enrichment['category'], 'Education');
    expect(enrichment['category_validation'], isA<Map>());
    expect(
      enrichment['category_repair']['method'],
      'restore_unsafe_centroid_correction',
    );
  });

  test('restores a correction whose winning similarity was too weak', () {
    final url = correctedUrl(
      originalCategory: 'Finance',
      claimedSampleSize: 8,
      suggestedSimilarity: 0.69,
    );

    final changed = CategoryRepairService.repairUnsafeCentroidCategory(url);

    expect(changed, isTrue);
    expect(url.category, 'Finance');
  });

  test('keeps a strong correction between established categories', () {
    final url = correctedUrl(claimedSampleSize: 8, suggestedSimilarity: 0.82);

    final changed = CategoryRepairService.repairUnsafeCentroidCategory(url);

    expect(changed, isFalse);
    expect(url.category, 'Health');
  });

  test('does not overwrite a category changed after centroid validation', () {
    final url = correctedUrl(currentCategory: 'Business');

    final changed = CategoryRepairService.repairUnsafeCentroidCategory(url);

    expect(changed, isFalse);
    expect(url.category, 'Business');
  });
}
