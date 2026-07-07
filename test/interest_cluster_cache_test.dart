import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/features/mindmap/interest_cluster_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedUrl _url(int id) {
  return SavedUrl()
    ..id = id
    ..rawUrl = 'https://example.com/$id'
    ..domain = 'example.com'
    ..title = 'Save $id'
    ..description = ''
    ..category = 'Health'
    ..categoryEmoji = ''
    ..categories = ['Health']
    ..tags = ['health']
    ..savedAt = DateTime(2026, 7, 7)
    ..embedding = [1, id / 100];
}

SavedUrl _interestUrl({
  required int id,
  required String title,
  required String category,
  required List<String> tags,
}) {
  return SavedUrl()
    ..id = id
    ..rawUrl = 'https://instagram.com/reel/$id'
    ..domain = 'instagram.com'
    ..title = title
    ..description = ''
    ..category = category
    ..categoryEmoji = ''
    ..categories = [category]
    ..tags = tags
    ..savedAt = DateTime(2026, 7, 7)
    ..embedding = [1, id / 100];
}

void main() {
  group('interest cluster cache', () {
    test('rebuilds on small-library embedded count changes', () async {
      SharedPreferences.setMockInitialValues({
        kInterestClusterUrlCountKey: 3,
        kInterestClustersJsonKey: jsonEncode({
          'version': 9,
          'themes': [
            {
              'label': 'Health',
              'summary': '3 saves',
              'ids': [1, 2, 3],
              'subClusters': [],
            },
          ],
        }),
      });

      final prefs = await SharedPreferences.getInstance();
      final result = await tryHydrateClustersFromPrefs(
        prefs: prefs,
        embeddedUrls: [_url(1), _url(2), _url(3), _url(4)],
        currentEmbeddedCount: 4,
      );

      expect(result, isNull);
    });

    test('keeps mature-library cache within rebuild threshold', () async {
      SharedPreferences.setMockInitialValues({
        kInterestClusterUrlCountKey: 20,
        kInterestClustersJsonKey: jsonEncode({
          'version': 9,
          'themes': [
            {
              'label': 'Health',
              'summary': '20 saves',
              'ids': [1, 2, 3],
              'subClusters': [],
            },
          ],
        }),
      });

      final prefs = await SharedPreferences.getInstance();
      final result = await tryHydrateClustersFromPrefs(
        prefs: prefs,
        embeddedUrls: [_url(1), _url(2), _url(3)],
        currentEmbeddedCount: 23,
      );

      expect(result, isNotNull);
      expect(result!.single.label, 'Health');
    });
  });

  group('interest cluster labeling', () {
    test(
      'buckets nutrition saves as Health even when stored category is wrong',
      () {
        final url = _interestUrl(
          id: 101,
          title: 'Nutritional Benefits of Indian Flatbreads',
          category: 'Technology',
          tags: const ['nutrition', 'flatbread', 'health'],
        );

        expect(debugBroadCategoryBucketForInterest(url), 'Health');
      },
    );

    test(
      'does not let minority security saves label nutrition cluster as dev tools',
      () {
        final urls = [
          _interestUrl(
            id: 201,
            title: 'Ranking Popular Indian Biscuits for Fat Loss',
            category: 'Technology',
            tags: const ['fat loss', 'nutrition'],
          ),
          _interestUrl(
            id: 202,
            title: 'Nutritional Benefits of Indian Flatbreads',
            category: 'Technology',
            tags: const ['nutrition', 'health'],
          ),
          _interestUrl(
            id: 203,
            title: 'Healthier Chocolate Choices',
            category: 'Technology',
            tags: const ['nutrition', 'healthy'],
          ),
          _interestUrl(
            id: 204,
            title: 'Chia vs Sabja Seeds',
            category: 'Technology',
            tags: const ['chia', 'sabja', 'nutrition'],
          ),
          _interestUrl(
            id: 205,
            title: 'Optimizing Seed Nutrition',
            category: 'Technology',
            tags: const ['nutrition', 'wellness'],
          ),
          _interestUrl(
            id: 206,
            title: 'Phone Security Checking Call Forwarding',
            category: 'Technology',
            tags: const ['security'],
          ),
          _interestUrl(
            id: 207,
            title: 'Cybersecurity SIM Swap Scam Prevention',
            category: 'Technology',
            tags: const ['cybersecurity'],
          ),
        ];

        expect(debugHeuristicLabelForInterest(urls), 'Nutrition & Wellness');
      },
    );
  });
}
