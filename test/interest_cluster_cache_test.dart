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
}
