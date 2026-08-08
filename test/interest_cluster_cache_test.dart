import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/features/mindmap/cluster_theme.dart';
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
  String? enrichmentJson,
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
    ..enrichmentJson = enrichmentJson
    ..savedAt = DateTime(2026, 7, 7)
    ..embedding = [1, id / 100];
}

void main() {
  group('interest cluster cache', () {
    test('rebuilds on small-library embedded count changes', () async {
      SharedPreferences.setMockInitialValues({
        kInterestClusterUrlCountKey: 3,
        kInterestClustersJsonKey: jsonEncode({
          'version': 11,
          'themes': [
            {
              'label': 'Health',
              'summary': '3 saves',
              'urls': [
                'https://example.com/1',
                'https://example.com/2',
                'https://example.com/3',
              ],
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

    test('hydrates small additions without dropping them', () async {
      final cachedUrls = List.generate(20, (index) => _url(index + 1));
      final currentUrls = List.generate(23, (index) => _url(index + 1));
      SharedPreferences.setMockInitialValues({
        kInterestClusterUrlCountKey: 20,
        kInterestClustersJsonKey: jsonEncode({
          'version': 11,
          'themes': [
            {
              'label': 'Health',
              'summary': '20 saves',
              'urls': cachedUrls.map((url) => url.rawUrl).toList(),
              'subClusters': [],
            },
          ],
        }),
      });

      final prefs = await SharedPreferences.getInstance();
      final result = await tryHydrateClustersFromPrefs(
        prefs: prefs,
        embeddedUrls: currentUrls,
        currentEmbeddedCount: 23,
      );

      expect(result, isNotNull);
      expect(
        result!.expand((theme) => theme.urls).map((url) => url.rawUrl).toSet(),
        currentUrls.map((url) => url.rawUrl).toSet(),
      );
    });

    test(
      'rejects a same-count cache that covers only part of the library',
      () async {
        final currentUrls = List.generate(97, (index) => _url(index + 1));
        SharedPreferences.setMockInitialValues({
          kInterestClusterUrlCountKey: 97,
          kInterestClustersJsonKey: jsonEncode({
            'version': 11,
            'themes': [
              {
                'label': 'Partial map',
                'summary': '39 saves',
                'urls': currentUrls.take(39).map((url) => url.rawUrl).toList(),
                'subClusters': [],
              },
            ],
          }),
        });

        final prefs = await SharedPreferences.getInstance();
        final result = await tryHydrateClustersFromPrefs(
          prefs: prefs,
          embeddedUrls: currentUrls,
          currentEmbeddedCount: currentUrls.length,
        );

        expect(result, isNull);
      },
    );

    test('hydrates by stable URL identity after database IDs change', () async {
      SharedPreferences.setMockInitialValues({
        kInterestClusterUrlCountKey: 3,
        kInterestClustersJsonKey: jsonEncode({
          'version': 11,
          'themes': [
            {
              'label': 'Health',
              'summary': '3 saves',
              'urls': [
                'https://example.com/1',
                'https://example.com/2',
                'https://example.com/3',
              ],
              'subClusters': [],
            },
          ],
        }),
      });
      final restoredUrls = [
        _url(1)..id = 101,
        _url(2)..id = 102,
        _url(3)..id = 103,
      ];

      final prefs = await SharedPreferences.getInstance();
      final result = await tryHydrateClustersFromPrefs(
        prefs: prefs,
        embeddedUrls: restoredUrls,
        currentEmbeddedCount: restoredUrls.length,
      );

      expect(result, isNotNull);
      expect(result!.single.urls.map((url) => url.id), [101, 102, 103]);
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

    test(
      'requires rule-based labels to represent the cluster, not a minority',
      () {
        final urls = List.generate(10, (index) {
          return _interestUrl(
            id: 250 + index,
            title: index < 3
                ? 'Money and founder lesson $index'
                : 'Personal reflection $index',
            category: 'Health',
            tags: [
              'mindset',
              if (index < 3) 'startup',
              if (index >= 3) 'self-improvement',
            ],
          );
        });

        expect(debugHeuristicLabelForInterest(urls), 'Mindset');
      },
    );

    test('does not confuse personal growth with website growth', () {
      final urls = List.generate(4, (index) {
        return _interestUrl(
          id: 280 + index,
          title: 'Personal growth reflection $index',
          category: 'Health',
          tags: const ['mindset'],
        );
      });

      expect(debugHeuristicLabelForInterest(urls), 'Mindset');
    });

    test('does not name a singleton from one incidental keyword', () {
      final url = _interestUrl(
        id: 290,
        title: 'Knot theory and protein folding',
        category: 'Science',
        tags: const ['topology', 'mathematics'],
      );

      expect(
        debugHeuristicLabelForInterest([url]),
        isNot('Nutrition & Wellness'),
      );
    });

    test('preserves a strong semantic label after finalization', () {
      final urls = [
        _interestUrl(
          id: 301,
          title: 'Founder habits and startup discipline',
          category: 'Health',
          tags: const ['self-improvement'],
        ),
        _interestUrl(
          id: 302,
          title: 'Personal agency and healthier boundaries',
          category: 'Health',
          tags: const ['personal growth'],
        ),
        _interestUrl(
          id: 303,
          title: 'Life philosophy and financial wisdom',
          category: 'Health',
          tags: const ['mindset'],
        ),
      ];

      final result = debugFinalizeInterestThemes([
        ClusterTheme(
          index: 0,
          label: 'Personal Growth',
          summary: 'A generated semantic name.',
          urls: urls,
        ),
      ]);

      expect(result.single.label, 'Personal Growth');
    });

    test('does not merge identical labels across unrelated broad topics', () {
      final entertainment = _interestUrl(
        id: 401,
        title: 'Indonesian horror recommendations',
        category: 'Entertainment',
        tags: const ['movies', 'horror'],
      );
      final health = _interestUrl(
        id: 402,
        title: 'Personal growth and discipline',
        category: 'Health',
        tags: const ['nutrition', 'discipline'],
      );

      final result = debugFinalizeInterestThemes([
        ClusterTheme(
          index: 0,
          label: 'Movie Recommendations',
          summary: '',
          urls: [entertainment],
        ),
        ClusterTheme(
          index: 1,
          label: 'Movie Recommendations',
          summary: '',
          urls: [health],
        ),
      ]);

      expect(result, hasLength(2));
      expect(
        result.expand((theme) => theme.urls),
        containsAll([entertainment, health]),
      );
    });

    test(
      'reassembles repeated structured subjects across embedding fragments',
      () {
        final calisthenics = _interestUrl(
          id: 501,
          title: 'Calisthenics · Beginner Skill Progression',
          category: 'Health',
          tags: const ['calisthenics', 'bodyweight'],
        );
        final creatine = _interestUrl(
          id: 502,
          title: 'Creatine Supplementation · Scientific Overview',
          category: 'Science',
          tags: const ['creatine', 'fitness'],
        );
        final nutrition = _interestUrl(
          id: 503,
          title: 'Vegetarian Protein Sources · Nutritional Ranking',
          category: 'Other',
          tags: const ['protein sources', 'nutrition'],
        );

        final result = debugFinalizeInterestThemes([
          ClusterTheme(
            index: 0,
            label: 'Bodyweight Training',
            summary: '',
            urls: [calisthenics],
          ),
          ClusterTheme(
            index: 1,
            label: 'Sports Science',
            summary: '',
            urls: [creatine],
          ),
          ClusterTheme(
            index: 2,
            label: 'Nutrition',
            summary: '',
            urls: [nutrition],
          ),
        ]);

        expect(result, hasLength(1));
        expect(result.single.label, 'Health & Fitness');
        expect(
          result.single.urls,
          containsAll([calisthenics, creatine, nutrition]),
        );
      },
    );

    test('keeps film analysis out of the movie watchlist subject', () {
      final analysis = _interestUrl(
        id: 601,
        title: 'Bollywood · Demographic Coding and Bias',
        category: 'Other',
        tags: const ['bollywood', 'sociology', 'movie recommendations'],
        enrichmentJson: jsonEncode({
          'memory_intent': {'primary_intent': 'learn'},
          'mentions': [
            {'type': 'movie', 'title': 'Example'},
          ],
        }),
      );
      final movies = List.generate(3, (index) {
        return _interestUrl(
          id: 610 + index,
          title: 'Movie Recommendations ${index + 1}',
          category: 'Other',
          tags: const ['films', 'watchlist'],
          enrichmentJson: jsonEncode({
            'memory_intent': {'primary_intent': 'watch_later'},
            'mentions': [
              {'type': 'movie', 'title': 'Film'},
            ],
          }),
        );
      });

      final result = debugFinalizeInterestThemes([
        ClusterTheme(
          index: 0,
          label: 'Movie Recommendations',
          summary: '',
          urls: [analysis, ...movies],
        ),
      ]);
      final watchlist = result.singleWhere(
        (theme) => theme.label == 'Movies To Watch',
      );

      expect(watchlist.urls, movies);
      expect(watchlist.urls, isNot(contains(analysis)));
      expect(result.expand((theme) => theme.urls), contains(analysis));
    });

    test('does not treat a contextual country as travel intent', () {
      final fraud = _interestUrl(
        id: 701,
        title: 'Financial Fraud Prevention · Indian Banking Security',
        category: 'Finance',
        tags: const ['banking', 'scam', 'security', 'india'],
        enrichmentJson: jsonEncode({
          'memory_intent': {'primary_intent': 'learn', 'location': 'India'},
        }),
      );
      final travel = [
        _interestUrl(
          id: 702,
          title: 'Hikers Inn Cafe · Georgia',
          category: 'Travel',
          tags: const ['travel', 'destination', 'georgia'],
          enrichmentJson: jsonEncode({
            'memory_intent': {'primary_intent': 'visit', 'location': 'Georgia'},
          }),
        ),
        _interestUrl(
          id: 703,
          title: 'Tuk Tuk Expedition · Kenya Journey',
          category: 'Travel',
          tags: const ['expedition', 'kenya'],
          enrichmentJson: jsonEncode({
            'memory_intent': {'primary_intent': 'visit', 'location': 'Kenya'},
          }),
        ),
        _interestUrl(
          id: 704,
          title: 'Ancient Temples · Must-Visit Historical Sites',
          category: 'Travel',
          tags: const ['temples', 'india', 'historical sites'],
          enrichmentJson: jsonEncode({
            'memory_intent': {'primary_intent': 'visit', 'location': 'India'},
          }),
        ),
      ];

      final result = debugFinalizeInterestThemes([
        ClusterTheme(
          index: 0,
          label: 'India',
          summary: '',
          urls: [fraud, ...travel],
        ),
      ]);
      final travelTheme = result.singleWhere(
        (theme) => theme.label == 'Travel & Places',
      );

      expect(travelTheme.urls, travel);
      expect(travelTheme.urls, isNot(contains(fraud)));
      expect(result.expand((theme) => theme.urls), contains(fraud));
    });
  });
}
