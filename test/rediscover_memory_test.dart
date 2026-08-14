import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/url_processing_status.dart';
import 'package:glimpse/core/services/affinity_profile.dart';
import 'package:glimpse/features/mindmap/cluster_theme.dart';
import 'package:glimpse/features/rediscover/journey_visual.dart';
import 'package:glimpse/features/rediscover/rediscover_daily_set.dart';
import 'package:glimpse/features/rediscover/rediscover_journey_provider.dart';
import 'package:glimpse/features/rediscover/rediscover_memory.dart';
import 'package:glimpse/features/rediscover/rediscover_memory_prefs.dart';
import 'package:glimpse/features/rediscover/rediscover_notification_candidate.dart';
import 'package:glimpse/features/rediscover/rediscover_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedUrl _url({
  required int id,
  required String title,
  DateTime? savedAt,
  DateTime? openedAt,
  String? intentStatus,
  String category = 'Food & Cooking',
  List<String> tags = const ['recipe', 'high protein'],
  String? summary,
  String? enrichmentJson,
  List<double>? embedding,
  DateTime? revisitAfter,
  DateTime? rediscoverDismissedAt,
  String processingStatus = UrlProcessingStatus.ready,
  String? thumbnailUrl,
}) {
  return SavedUrl()
    ..id = id
    ..rawUrl = 'https://example.com/$id'
    ..domain = 'example.com'
    ..title = title
    ..description = ''
    ..summary = summary
    ..thumbnailUrl = thumbnailUrl
    ..category = category
    ..categoryEmoji = ''
    ..categories = [category]
    ..tags = tags
    ..savedAt = savedAt ?? DateTime(2026, 6, 1)
    ..openedAt = openedAt
    ..intentStatus = intentStatus
    ..processingStatus = processingStatus
    ..revisitAfter = revisitAfter
    ..rediscoverDismissedAt = rediscoverDismissedAt
    ..embedding = embedding
    ..enrichmentJson = enrichmentJson;
}

String _intentJson({
  required String primaryIntent,
  required String why,
  String? lifeArea,
  String? location,
}) {
  return jsonEncode({
    'memory_intent': {
      'primary_intent': primaryIntent,
      'life_area': lifeArea,
      'location': location,
      'why_saved_hypothesis': why,
    },
  });
}

RediscoveryItem _item(SavedUrl url) {
  return RediscoveryItem(url: url, reason: 'Unopened', timeAgo: '2w ago');
}

void main() {
  test('journey topics map across the complete artwork library', () {
    const expectations = {
      'AI agents': RediscoverArtworkTheme.software,
      'Botanical ecology': RediscoverArtworkTheme.nature,
      'Weekend travel': RediscoverArtworkTheme.travel,
      'High-protein recipes': RediscoverArtworkTheme.food,
      'Stoic philosophy': RediscoverArtworkTheme.philosophy,
      'Startup marketing': RediscoverArtworkTheme.business,
      'Cell biology': RediscoverArtworkTheme.science,
      'Ancient architecture': RediscoverArtworkTheme.history,
      'Literary essays': RediscoverArtworkTheme.books,
      'Long-term investing': RediscoverArtworkTheme.finance,
      'Portrait photography': RediscoverArtworkTheme.photography,
      'Strength training': RediscoverArtworkTheme.fitness,
      'Music albums': RediscoverArtworkTheme.music,
      'Anime watchlist': RediscoverArtworkTheme.film,
      'Graphic design': RediscoverArtworkTheme.design,
      'Interior decor': RediscoverArtworkTheme.home,
      'Personal fashion': RediscoverArtworkTheme.fashion,
      'Things I like': RediscoverArtworkTheme.general,
    };

    for (final entry in expectations.entries) {
      final journey = RediscoverJourney(
        kind: RediscoverJourneyKind.becauseYouSaved,
        title: entry.key,
        subtitle: 'Test subtitle',
        icon: Icons.bookmark_rounded,
        items: const [],
        signal: 50,
        topicAnchor: entry.key,
      );

      expect(artworkThemeForJourney(journey), entry.value, reason: entry.key);
    }
  });

  test('all Rediscover artwork assets are bundled', () async {
    for (final theme in RediscoverArtworkTheme.values) {
      final data = await rootBundle.load(theme.assetPath);
      expect(data.lengthInBytes, greaterThan(0), reason: theme.name);
    }
  });

  testWidgets('artwork cards fit compact light and dark layouts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 260));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final items = [
      _item(_url(id: 1, title: 'First save', savedAt: DateTime(2025, 12, 1))),
      _item(_url(id: 2, title: 'Second save', savedAt: DateTime(2026, 2, 1))),
      _item(_url(id: 3, title: 'Third save', savedAt: DateTime(2026, 4, 1))),
    ];
    const topics = ['AI agents', 'Weekend travel', 'High-protein recipes'];

    for (final brightness in Brightness.values) {
      for (final textScale in [1.2, 1.6, 2.0]) {
        for (final topic in topics) {
          final journey = RediscoverJourney(
            kind: RediscoverJourneyKind.becauseYouSaved,
            title: 'Building reliable systems for everyday use',
            subtitle: 'A compact set of saves worth returning to',
            icon: Icons.bookmark_rounded,
            items: items,
            signal: 72,
            topicAnchor: topic,
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF6750A4),
                  brightness: brightness,
                ),
              ),
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(360, 260),
                  textScaler: TextScaler.linear(textScale),
                ),
                child: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 296,
                      child: RediscoverArtworkCard(
                        journey: journey,
                        title: journey.title,
                        supportingText: journey.subtitle,
                        metadata: '3 saves · 2 unopened · 4mo ago',
                        height: 196,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          expect(
            tester.takeException(),
            isNull,
            reason:
                '$topic should fit in $brightness mode at ${textScale}x text',
          );
          expect(find.text('A PATTERN IN YOUR SAVES'), findsNothing);
          expect(find.text('WORTH ANOTHER LOOK'), findsNothing);
        }
      }
    }
  });

  testWidgets('compact artwork cards balance titles without orphaned words', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 260));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final journey = RediscoverJourney(
      kind: RediscoverJourneyKind.becauseYouSaved,
      title: 'High-Protein Vegetarian Meals',
      subtitle: 'Ideas on nutrition and fitness.',
      icon: Icons.restaurant_rounded,
      items: const [],
      signal: 70,
      topicAnchor: 'vegetarian meals',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 296,
              child: RediscoverArtworkCard(
                journey: journey,
                title: journey.title,
                supportingText: journey.subtitle,
                metadata: '4 waiting · 1w ago',
                height: 196,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final title = tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && widget.data?.contains('High-Protein') == true,
      ),
    );
    expect(title.data, 'High-Protein\nVegetarian Meals');
    expect(title.style?.fontSize, 23);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == 5,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('RediscoverMemory fully describes a resurfacing candidate', () {
    final first = _url(
      id: 7,
      title: 'High Protein Breakfast',
      tags: const ['recipe', 'high protein', 'breakfast'],
      enrichmentJson: _intentJson(
        primaryIntent: 'cook',
        lifeArea: 'food',
        why: 'The user likely saved this to cook healthier breakfasts.',
      ),
    );
    final second = _url(
      id: 9,
      title: 'Soya Keema Masala',
      openedAt: DateTime(2026, 6, 5),
      intentStatus: 'queued',
      enrichmentJson: _intentJson(
        primaryIntent: 'cook',
        lifeArea: 'food',
        why: 'The user likely saved this for high-protein vegetarian meals.',
      ),
    );
    final journey = RediscoverJourney(
      kind: RediscoverJourneyKind.forgottenGems,
      title: 'Still perfecting your recipes?',
      subtitle: '2 saves you set aside a while ago',
      icon: Icons.dinner_dining_rounded,
      items: [_item(first), _item(second)],
      signal: 72,
      topicAnchor: 'protein recipes',
    );

    final memory = RediscoverMemory.fromJourney(journey);

    expect(memory.id, 'forgottenGems:protein-recipes:7-9');
    expect(memory.topicKey, 'protein recipes');
    expect(memory.topicLabel, 'Protein Recipes');
    expect(memory.what, 'High-Protein Recipes');
    expect(memory.copyIdentity.primary, memory.what);
    expect(
      memory.copyIdentity.secondaryDescription,
      contains('cooking high-protein recipes'),
    );
    expect(
      memory.copyIdentity.reasonForToday,
      contains('collecting high-protein recipes'),
    );
    expect(memory.copyIdentity.suggestedNextStep, contains(first.title));
    expect(memory.semanticIntent.label, 'High-Protein Recipes');
    expect(
      memory.semanticIntent.journeyType,
      RediscoverSemanticJourneyType.cooking,
    );
    expect(memory.semanticIntent.evidencePhrases, contains('high protein'));
    expect(memory.semanticIntent.confidence, greaterThan(0.8));
    expect(memory.emotion, RediscoverMemoryEmotion.recognition);
    expect(memory.personality, RediscoverMemoryPersonality.practical);
    expect(memory.encouragedAction, contains(first.title));

    expect(memory.homeCopy.title, memory.what);
    expect(memory.homeCopy.body, memory.whyNow);
    expect(memory.rediscoverCopy.body, contains(memory.whyItMatters));
    expect(memory.rediscoverCopy.actionLabel, contains(first.title));
    expect(memory.notificationCopy.title, contains('High-Protein Recipes'));
    expect(
      memory.notificationCopy.body,
      contains('collecting high-protein recipes'),
    );
    expect(memory.what, isNot(contains('waiting for you')));
    expect(memory.what, isNot(contains('curiosity')));
    expect(memory.what, isNot(contains('Flavor Pattern')));

    expect(memory.primaryUrl, first);
    expect(memory.supportingUrls, [second]);
    expect(memory.metadata.saveCount, 2);
    expect(memory.metadata.unopenedCount, 1);
    expect(memory.metadata.openedCount, 1);
    expect(memory.metadata.hasQueuedSaves, isTrue);
    expect(memory.metadata.primaryUrlIds, [7]);
    expect(memory.metadata.supportingUrlIds, [9]);
  });

  test('notification candidate scores interruption value separately', () {
    final first = _url(
      id: 1,
      title: 'Protein Dinner',
      savedAt: DateTime(2026, 5, 1),
      intentStatus: 'queued',
    );
    final second = _url(
      id: 2,
      title: 'Breakfast Bowl',
      savedAt: DateTime(2026, 5, 2),
    );
    final third = _url(
      id: 3,
      title: 'High Protein Wrap',
      savedAt: DateTime(2026, 5, 3),
    );
    final memory = RediscoverMemory.fromJourney(
      RediscoverJourney(
        kind: RediscoverJourneyKind.forgottenGems,
        title: 'Still perfecting your recipes?',
        subtitle: '3 saves you set aside a while ago',
        icon: Icons.dinner_dining_rounded,
        items: [_item(first), _item(second), _item(third)],
        signal: 80,
        topicAnchor: 'protein recipes',
      ),
    );

    final candidate = RediscoverNotificationCandidate.scoreMemory(
      memory,
      now: DateTime(2026, 6, 6, 19),
    );

    expect(candidate.shouldNotify, isTrue);
    expect(
      candidate.explanation.map((entry) => entry['code']),
      containsAll(['explicit_revisit', 'long_unopened', 'cooking_evening']),
    );

    final repeated = RediscoverNotificationCandidate.scoreMemory(
      memory,
      now: DateTime(2026, 6, 6, 19),
      recentlyNotified: true,
    );
    expect(repeated.shouldNotify, isFalse);
    expect(
      repeated.explanation.map((entry) => entry['code']),
      contains('recent_repeat'),
    );
  });

  test('copy identities vary by memory personality and story', () {
    final buildMemory = RediscoverMemory.fromJourney(
      RediscoverJourney(
        kind: RediscoverJourneyKind.memoryGoal,
        title: 'Continue building',
        subtitle: '3 saves, including ones you queued',
        icon: Icons.terminal_rounded,
        items: [
          _item(
            _url(
              id: 20,
              title: 'Local First App Architecture',
              category: 'Technology',
              tags: const ['flutter', 'app', 'architecture'],
              intentStatus: 'queued',
            ),
          ),
          _item(
            _url(
              id: 21,
              title: 'Offline Sync Notes',
              category: 'Technology',
              tags: const ['sync', 'api'],
            ),
          ),
          _item(
            _url(
              id: 22,
              title: 'Riverpod Cache Strategy',
              category: 'Technology',
              tags: const ['flutter', 'state management'],
            ),
          ),
        ],
        signal: 92,
        topicAnchor: 'app architecture',
      ),
    );

    final reflectiveMemory = RediscoverMemory.fromJourney(
      RediscoverJourney(
        kind: RediscoverJourneyKind.becauseYouSaved,
        title: 'Time to reflect',
        subtitle: '3 saves worth reopening',
        icon: Icons.psychology_alt_rounded,
        items: [
          _item(
            _url(
              id: 30,
              title: 'Philosophy Perspectives on Free Will',
              category: 'Philosophy',
              tags: const ['philosophy', 'free-will', 'consciousness'],
              enrichmentJson: _intentJson(
                primaryIntent: 'learn',
                lifeArea: 'education',
                why: 'The user saved this to understand free will.',
              ),
            ),
          ),
          _item(
            _url(
              id: 31,
              title: 'Free Will Debate',
              category: 'Philosophy',
              tags: const ['free will', 'determinism', 'agency'],
            ),
          ),
          _item(
            _url(
              id: 32,
              title: 'Consciousness and Agency',
              category: 'Philosophy',
              tags: const ['consciousness', 'agency'],
            ),
          ),
        ],
        signal: 78,
        topicAnchor: 'philosophy',
      ),
    );

    expect(buildMemory.personality, RediscoverMemoryPersonality.ambitious);
    expect(
      reflectiveMemory.personality,
      RediscoverMemoryPersonality.reflective,
    );
    expect(buildMemory.what, 'Flutter Development Notes');
    expect(reflectiveMemory.what, 'Understanding Free Will');
    expect(buildMemory.what, isNot(reflectiveMemory.what));
    expect(
      [buildMemory.what, reflectiveMemory.what].join(' '),
      isNot(contains('waiting for you')),
    );
    expect(
      [buildMemory.what, reflectiveMemory.what].join(' '),
      isNot(contains('A Pattern in What You Build')),
    );
  });

  test('journey builder merges true duplicate clusters by centroid', () {
    final first = [
      for (var i = 0; i < 3; i++)
        _url(
          id: i + 1,
          title: 'Natural Farming ${i + 1}',
          category: 'Nature',
          tags: const ['natural farming', 'soil'],
          embedding: [1, 0.01 * i],
        ),
    ];
    final duplicate = [
      for (var i = 0; i < 3; i++)
        _url(
          id: i + 10,
          title: 'Soil Farming ${i + 1}',
          category: 'Nature',
          tags: const ['natural farming', 'soil'],
          embedding: [0.99, 0.02 * i],
        ),
    ];

    final journeys = buildRediscoverJourneys(
      liveUrls: [...first, ...duplicate],
      clusters: [
        ClusterTheme(
          index: 0,
          label: 'Natural Farming',
          summary: '',
          urls: first,
        ),
        ClusterTheme(
          index: 1,
          label: 'Natural Farming',
          summary: '',
          urls: duplicate,
        ),
      ],
      profile: AffinityProfile.empty,
    );

    expect(journeys, hasLength(1));
    expect(
      journeys.single.items.map((item) => item.url.id).toSet(),
      hasLength(6),
    );
  });

  test('movie journeys exclude film analysis saved for learning', () {
    final analysis = _url(
      id: 41,
      title: 'Bollywood · Demographic Coding and Bias',
      category: 'Society',
      tags: const ['bollywood', 'sociology', 'movie recommendations'],
      enrichmentJson: _intentJson(
        primaryIntent: 'learn',
        why: 'Understand demographic coding and bias in popular cinema.',
      ),
    );
    final movies = List.generate(3, (index) {
      return _url(
        id: 50 + index,
        title: 'Movie Recommendations ${index + 1}',
        category: 'Entertainment',
        tags: const ['films', 'watchlist'],
        enrichmentJson: _intentJson(
          primaryIntent: 'watch_later',
          why: 'Keep these films for a future movie night.',
        ),
      );
    });

    final journeys = buildRediscoverJourneys(
      liveUrls: [analysis, ...movies],
      clusters: [
        ClusterTheme(
          index: 0,
          label: 'Movie Recommendations',
          summary: '',
          urls: [analysis, ...movies],
        ),
      ],
      profile: AffinityProfile.empty,
    );

    expect(journeys, hasLength(1));
    expect(journeys.single.items.map((item) => item.url), movies);
    expect(
      journeys.single.items.map((item) => item.url),
      isNot(contains(analysis)),
    );
  });

  test('keeps only one rediscover journey per resolved movie subject', () {
    List<SavedUrl> movieSet(int start, String genre) {
      return List.generate(3, (index) {
        return _url(
          id: start + index,
          title: '$genre Movie Recommendations ${index + 1}',
          category: 'Entertainment',
          tags: [genre.toLowerCase(), 'films', 'watchlist'],
          enrichmentJson: _intentJson(
            primaryIntent: 'watch_later',
            why: 'Save these films for later.',
          ),
          embedding: [start.toDouble(), index / 100],
        );
      });
    }

    final horror = movieSet(70, 'Horror');
    final drama = movieSet(80, 'Drama');
    final journeys = buildRediscoverJourneys(
      liveUrls: [...horror, ...drama],
      clusters: [
        ClusterTheme(
          index: 0,
          label: 'Horror Films',
          summary: '',
          urls: horror,
        ),
        ClusterTheme(index: 1, label: 'Drama Films', summary: '', urls: drama),
      ],
      profile: AffinityProfile.empty,
    );

    expect(journeys, hasLength(1));
    expect(
      RediscoverMemory.fromJourney(journeys.single).rediscoverCopy.title,
      'Movies To Watch',
    );
  });

  test('film vocabulary alone does not create a movies-to-watch memory', () {
    final analyses = [
      _url(
        id: 91,
        title: 'Bollywood · Demographic Coding and Bias',
        category: 'Society',
        tags: const ['film', 'sociology', 'movie recommendations'],
        enrichmentJson: _intentJson(
          primaryIntent: 'learn',
          why: 'Study demographic coding in cinema.',
        ),
      ),
      _url(
        id: 92,
        title: 'Cinema · Representation and Social Class',
        category: 'Society',
        tags: const ['film', 'media studies', 'movie recommendations'],
        enrichmentJson: _intentJson(
          primaryIntent: 'learn',
          why: 'Understand representation in film.',
        ),
      ),
    ];
    final memory = RediscoverMemory.fromJourney(
      RediscoverJourney(
        kind: RediscoverJourneyKind.continueLearning,
        title: 'Film and Society',
        subtitle: '2 saves',
        icon: Icons.school_rounded,
        items: analyses.map(_item).toList(),
        signal: 70,
      ),
    );

    expect(memory.rediscoverCopy.title, isNot('Movies To Watch'));
  });

  test('country context does not contaminate a travel journey', () {
    final fraud = _url(
      id: 93,
      title: 'Financial Fraud Prevention · Indian Banking Security',
      category: 'Finance',
      tags: const ['banking', 'scam', 'security', 'india'],
      enrichmentJson: _intentJson(
        primaryIntent: 'learn',
        why: 'Understand fraud prevention in Indian banking.',
        location: 'India',
      ),
    );
    final travel = [
      _url(
        id: 94,
        title: 'Hikers Inn Cafe · Georgia',
        category: 'Travel',
        tags: const ['travel', 'destination', 'georgia'],
        enrichmentJson: _intentJson(
          primaryIntent: 'visit',
          why: 'Remember this cafe for a Georgia trip.',
          location: 'Georgia',
        ),
      ),
      _url(
        id: 95,
        title: 'Tuk Tuk Expedition · Kenya Journey',
        category: 'Travel',
        tags: const ['expedition', 'kenya', 'travel'],
        enrichmentJson: _intentJson(
          primaryIntent: 'visit',
          why: 'Consider this Kenya expedition.',
          location: 'Kenya',
        ),
      ),
      _url(
        id: 96,
        title: 'Ancient Temples · Must-Visit Historical Sites',
        category: 'Travel',
        tags: const ['temples', 'india', 'historical sites'],
        enrichmentJson: _intentJson(
          primaryIntent: 'visit',
          why: 'Keep these temples for a future trip.',
          location: 'India',
        ),
      ),
    ];

    final journeys = buildRediscoverJourneys(
      liveUrls: [fraud, ...travel],
      clusters: [
        ClusterTheme(
          index: 0,
          label: 'India',
          summary: '',
          urls: [fraud, ...travel],
        ),
      ],
      profile: AffinityProfile.empty,
    );

    expect(journeys, hasLength(1));
    expect(journeys.single.items.map((item) => item.url), travel);
    expect(
      journeys.single.items.map((item) => item.url),
      isNot(contains(fraud)),
    );
    expect(
      RediscoverMemory.fromJourney(journeys.single).rediscoverCopy.title,
      isNot('India'),
    );
  });

  test('journey titles are unique for adjacent consciousness clusters', () {
    final philosophy = [
      _url(
        id: 101,
        title: 'Free Will and Determinism',
        category: 'Philosophy',
        tags: const ['free will', 'determinism', 'consciousness'],
        embedding: [1, 0],
      ),
      _url(
        id: 102,
        title: 'Agency in Philosophy',
        category: 'Philosophy',
        tags: const ['free will', 'agency'],
        embedding: [0.98, 0.05],
      ),
      _url(
        id: 103,
        title: 'Consciousness and Choice',
        category: 'Philosophy',
        tags: const ['consciousness', 'choice'],
        embedding: [0.96, 0.03],
      ),
    ];
    final ai = [
      _url(
        id: 201,
        title: 'AI Consciousness Research',
        category: 'Technology',
        tags: const ['ai consciousness', 'llm', 'research'],
        embedding: [0, 1],
      ),
      _url(
        id: 202,
        title: 'Machine Consciousness',
        category: 'Technology',
        tags: const ['ai consciousness', 'machine learning'],
        embedding: [0.03, 0.97],
      ),
      _url(
        id: 203,
        title: 'LLMs and Awareness',
        category: 'Technology',
        tags: const ['ai consciousness', 'llm'],
        embedding: [0.02, 0.98],
      ),
    ];

    final journeys = buildRediscoverJourneys(
      liveUrls: [...philosophy, ...ai],
      clusters: [
        ClusterTheme(
          index: 0,
          label: 'Understanding Consciousness',
          summary: '',
          urls: philosophy,
        ),
        ClusterTheme(
          index: 1,
          label: 'Understanding Consciousness',
          summary: '',
          urls: ai,
        ),
      ],
      profile: AffinityProfile.empty,
    );

    final titles = journeys.map((journey) => journey.title).toSet();
    expect(journeys, hasLength(2));
    expect(titles, hasLength(2));
    expect(titles, contains('Understanding Free Will'));
    expect(titles, contains('AI & Consciousness'));
    for (final journey in journeys) {
      final hook = journey.hookLine ?? '';
      expect(hook, isNotEmpty);
      expect(hook.toLowerCase(), isNot(contains('unopened')));
      expect(RegExp(r'^\d+\s').hasMatch(hook), isFalse);
    }
  });

  test('journey detail narrative summarizes contents without pasting summaries', () {
    final urls = [
      _url(
        id: 701,
        title: 'Try Optimizing Seed Nutrition • Health & Wellness',
        tags: const ['nutrition', 'seeds', 'recipe'],
        summary:
            'Learn how to properly prepare common seeds to maximize nutrient absorption and avoid digestive issues. This guide provides specific preparation methods for flax, chia, pumpkin, sesame, and sabja seeds.',
      ),
      _url(
        id: 702,
        title: 'Choosing Better Chocolate in India',
        tags: const ['nutrition', 'chocolate', 'health'],
        summary:
            'An oncologist breaks down how to select healthier chocolate options in the Indian market by prioritizing high cacao content and clean ingredients.',
      ),
      _url(
        id: 703,
        title: 'Indian Flatbreads for Fitness Goals',
        tags: const ['nutrition', 'flatbread', 'health'],
        summary:
            'This guide breaks down the specific health benefits of various Indian flatbreads to help you align your diet with your fitness goals.',
      ),
    ];

    final journeys = buildRediscoverJourneys(
      liveUrls: urls,
      clusters: [
        ClusterTheme(index: 0, label: 'Nutrition', summary: '', urls: urls),
      ],
      profile: AffinityProfile.empty,
    );

    final narrative = journeys.single.narrative;

    expect(
      narrative,
      'Inside: Optimizing Seed Nutrition, Choosing Better Chocolate in India, and Indian Flatbreads for Fitness Goals.',
    );
    expect(narrative, isNot(contains('This guide provides')));
    expect(narrative, isNot(contains('An oncologist breaks down')));
    expect(
      narrative,
      isNot(contains('without collapsing into a generic pile')),
    );
  });

  test('dinner debate wording does not make philosophy copy into recipes', () {
    final first = _url(
      id: 301,
      title: 'Rhetoric Books for Dinner Debates',
      category: 'Philosophy',
      tags: const ['rhetoric', 'debate', 'books'],
      summary: 'A reading list for argumentation and critical thinking.',
    );
    final second = _url(
      id: 302,
      title: 'Logical Fallacies Reading List',
      category: 'Philosophy',
      tags: const ['rhetoric', 'fallacies', 'books'],
    );
    final journey = RediscoverJourney(
      kind: RediscoverJourneyKind.becauseYouSaved,
      title: 'Rhetoric & Debate',
      subtitle: '2 saves worth reopening',
      icon: Icons.menu_book_rounded,
      items: [_item(first), _item(second)],
      signal: 70,
      topicAnchor: 'rhetoric',
    );

    final memory = RediscoverMemory.fromJourney(journey);

    expect(
      memory.semanticIntent.journeyType,
      isNot(RediscoverSemanticJourneyType.cooking),
    );
    expect(
      memory.copyIdentity.secondaryDescription.toLowerCase(),
      isNot(contains('recipe')),
    );
    expect(
      memory.copyIdentity.secondaryDescription.toLowerCase(),
      isNot(contains('cook')),
    );
    expect(memory.homeCopy.subtitle.toLowerCase(), isNot(contains('recipe')));
  });

  test('reading recommendations use natural noun order', () {
    final journey = RediscoverJourney(
      kind: RediscoverJourneyKind.becauseYouSaved,
      title: 'Recommendation Reading',
      subtitle: '3 saves worth reopening',
      icon: Icons.menu_book_rounded,
      items: [
        _item(
          _url(
            id: 801,
            title: 'Modern Fiction Recommendations',
            category: 'Books & Literature',
            tags: const ['reading', 'recommendation', 'modern fiction'],
          ),
        ),
        _item(
          _url(
            id: 802,
            title: 'Books Worth Reading This Year',
            category: 'Books & Literature',
            tags: const ['reading', 'recommendations', 'literary fiction'],
          ),
        ),
        _item(
          _url(
            id: 803,
            title: 'A Thoughtful Reading List',
            category: 'Books & Literature',
            tags: const ['reading list', 'recommendation', 'essays'],
          ),
        ),
      ],
      signal: 74,
      topicAnchor: 'recommendation reading',
    );

    final memory = RediscoverMemory.fromJourney(journey);

    expect(memory.homeCopy.title, 'Reading Recommendations');
    expect(memory.homeCopy.title, isNot('Recommendation Reading'));
    expect(
      memory.semanticIntent.journeyType,
      RediscoverSemanticJourneyType.collecting,
    );
    expect(memory.homeCopy.subtitle, startsWith('Reading picks'));
  });

  test('cooking identity completes adjective-only topics', () {
    final journey = RediscoverJourney(
      kind: RediscoverJourneyKind.continueLearning,
      title: 'Vegetarian',
      subtitle: '3 saves you recently added to',
      icon: Icons.restaurant_rounded,
      items: [
        _item(
          _url(
            id: 811,
            title: 'Weeknight Chickpea Curry',
            tags: const ['vegetarian', 'recipe', 'weeknight'],
          ),
        ),
        _item(
          _url(
            id: 812,
            title: 'Quick Paneer Dinner',
            tags: const ['vegetarian', 'recipe', 'weeknight'],
          ),
        ),
        _item(
          _url(
            id: 813,
            title: 'Lentil Meals for Busy Days',
            tags: const ['vegetarian', 'recipe', 'meal prep'],
          ),
        ),
      ],
      signal: 82,
      topicAnchor: 'vegetarian',
    );

    final memory = RediscoverMemory.fromJourney(journey);

    expect(memory.homeCopy.title, 'Vegetarian Recipes');
    expect(memory.homeCopy.title, isNot('Vegetarian'));
    expect(memory.homeCopy.subtitle, startsWith('Recipes'));
    expect(
      memory.homeCopy.subtitle.toLowerCase(),
      isNot(contains('recipes on')),
    );
  });

  test(
    'philosophy cards use supporting concepts instead of content formats',
    () {
      final journey = RediscoverJourney(
        kind: RediscoverJourneyKind.forgottenGems,
        title: 'Free Will',
        subtitle: '3 saves you set aside a while ago',
        icon: Icons.psychology_alt_rounded,
        items: [
          _item(
            _url(
              id: 821,
              title: 'Free Will and Determinism',
              category: 'Philosophy',
              tags: const ['free will', 'determinism', 'mindset'],
            ),
          ),
          _item(
            _url(
              id: 822,
              title: 'Agency and Moral Choice',
              category: 'Philosophy',
              tags: const ['agency', 'determinism', 'mindset'],
            ),
          ),
          _item(
            _url(
              id: 823,
              title: 'A Recipe for Thinking About Choice',
              category: 'Philosophy',
              tags: const ['free will', 'agency', 'mindset', 'recipe'],
            ),
          ),
        ],
        signal: 76,
        topicAnchor: 'mindset',
      );

      final memory = RediscoverMemory.fromJourney(journey);

      expect(memory.homeCopy.title, 'Understanding Free Will');
      expect(memory.homeCopy.subtitle, 'Ideas on mindset and determinism.');
      expect(memory.homeCopy.subtitle.toLowerCase(), isNot(contains('recipe')));
    },
  );

  test('recap builder creates daily, weekly and monthly memory recaps', () {
    final now = DateTime(2026, 7, 7, 10);
    final urls = [
      _url(
        id: 401,
        title: 'Riverpod Cache Notes',
        category: 'Technology',
        tags: const ['flutter', 'architecture'],
        savedAt: DateTime(2026, 7, 6),
        openedAt: DateTime(2026, 7, 6, 18),
      ),
      _url(
        id: 402,
        title: 'Offline Sync Patterns',
        category: 'Technology',
        tags: const ['flutter', 'sync'],
        savedAt: DateTime(2026, 7, 3),
      ),
      _url(
        id: 403,
        title: 'Local First Databases',
        category: 'Technology',
        tags: const ['database', 'sync'],
        savedAt: DateTime(2026, 6, 24),
      ),
      _url(
        id: 404,
        title: 'Old Architecture Talk',
        category: 'Technology',
        tags: const ['architecture'],
        savedAt: DateTime(2026, 5, 20),
        summary: 'A useful older talk about app architecture.',
      ),
    ];

    final recaps = buildRediscoverRecaps(urls, now: now);
    final cadences = recaps.map((recap) => recap.cadence).toSet();

    expect(cadences, contains(RediscoverRecapCadence.daily));
    expect(cadences, contains(RediscoverRecapCadence.weekly));
    expect(cadences, contains(RediscoverRecapCadence.monthly));
    expect(
      recaps
          .firstWhere((recap) => recap.cadence == RediscoverRecapCadence.weekly)
          .title,
      'Your week in saves',
    );
    expect(
      recaps
          .firstWhere(
            (recap) => recap.cadence == RediscoverRecapCadence.monthly,
          )
          .title,
      contains('Technology'),
    );
  });

  test('daily set prioritizes due intent and deduplicates every save', () {
    final now = DateTime(2026, 8, 14, 10);
    final due = _url(
      id: 901,
      title: 'Queued architecture note',
      intentStatus: 'queued',
      revisitAfter: now.subtract(const Duration(hours: 2)),
      tags: const ['flutter', 'architecture'],
    );
    final shared = _url(
      id: 902,
      title: 'Shared state patterns',
      tags: const ['flutter', 'architecture'],
    );
    final firstOnly = _url(
      id: 903,
      title: 'Riverpod lifecycle',
      tags: const ['flutter', 'architecture'],
    );
    final secondOnly = _url(
      id: 904,
      title: 'Offline sync',
      tags: const ['offline', 'sync'],
    );
    final secondTail = _url(
      id: 905,
      title: 'Conflict resolution',
      tags: const ['offline', 'sync'],
    );
    final third = [
      _url(
        id: 906,
        title: 'Strength plan',
        tags: const ['strength', 'fitness'],
      ),
      _url(
        id: 907,
        title: 'Recovery plan',
        tags: const ['strength', 'fitness'],
      ),
      _url(
        id: 908,
        title: 'Mobility plan',
        tags: const ['strength', 'fitness'],
      ),
    ];
    final journeys = [
      RediscoverJourney(
        kind: RediscoverJourneyKind.continueLearning,
        title: 'Flutter architecture',
        subtitle: '3 saves',
        icon: Icons.code_rounded,
        items: [due, shared, firstOnly].map(_item).toList(),
        signal: 50,
        topicAnchor: 'flutter architecture',
      ),
      RediscoverJourney(
        kind: RediscoverJourneyKind.becauseYouSaved,
        title: 'Offline systems',
        subtitle: '3 saves',
        icon: Icons.sync_rounded,
        items: [shared, secondOnly, secondTail].map(_item).toList(),
        signal: 90,
        topicAnchor: 'offline systems',
      ),
      RediscoverJourney(
        kind: RediscoverJourneyKind.becauseYouSaved,
        title: 'Strength training',
        subtitle: '3 saves',
        icon: Icons.fitness_center_rounded,
        items: third.map(_item).toList(),
        signal: 80,
        topicAnchor: 'strength training',
      ),
    ];

    final daily = buildRediscoverDailyMemories(
      journeys: journeys,
      liveUrls: [due, shared, firstOnly, secondOnly, secondTail, ...third],
      now: now,
    );
    final ids = daily
        .expand((memory) => memory.journey.items)
        .map((item) => item.url.id)
        .toList();

    expect(daily, hasLength(3));
    expect(daily.first.journey.items.map((item) => item.url.id), contains(901));
    expect(ids.toSet(), hasLength(ids.length));
  });

  test(
    'daily set permits a due single but chooses silence for weak singles',
    () {
      final now = DateTime(2026, 8, 14, 10);
      final due = _url(
        id: 920,
        title: 'Read this today',
        intentStatus: 'queued',
        revisitAfter: now.subtract(const Duration(minutes: 5)),
      );
      final weak = _url(
        id: 921,
        title: 'Unenriched old save',
        savedAt: now.subtract(const Duration(days: 80)),
        summary: null,
        enrichmentJson: null,
      );

      final dueSet = buildRediscoverDailyMemories(
        journeys: const [],
        liveUrls: [due, weak],
        now: now,
      );
      final quietSet = buildRediscoverDailyMemories(
        journeys: const [],
        liveUrls: [weak],
        now: now,
      );

      expect(dueSet, hasLength(1));
      expect(dueSet.single.primaryUrl?.id, 920);
      expect(quietSet, isEmpty);
    },
  );

  test('daily lifecycle prefs honor exact and topic cooldowns', () async {
    final now = DateTime(2026, 8, 14, 10);
    SharedPreferences.setMockInitialValues({});

    await RediscoverMemoryPrefs.snoozeMemory(
      'memory-1',
      until: now.add(const Duration(days: 7)),
    );
    await RediscoverMemoryPrefs.suppressTopic(
      'Flutter Architecture',
      until: now.add(const Duration(days: 14)),
    );

    expect(
      await RediscoverMemoryPrefs.isMemorySnoozed('memory-1', now: now),
      isTrue,
    );
    expect(
      await RediscoverMemoryPrefs.isMemorySnoozed(
        'memory-1',
        now: now.add(const Duration(days: 8)),
      ),
      isFalse,
    );
    expect(
      await RediscoverMemoryPrefs.isTopicSuppressed(
        ' flutter   architecture ',
        now: now,
      ),
      isTrue,
    );
    expect(
      await RediscoverMemoryPrefs.markMemoryShownOnce(
        memoryId: 'memory-1',
        dateKey: '2026-08-14',
      ),
      isTrue,
    );
    expect(
      await RediscoverMemoryPrefs.markMemoryShownOnce(
        memoryId: 'memory-1',
        dateKey: '2026-08-14',
      ),
      isFalse,
    );
  });

  test('daily set persistence preserves order per local date', () async {
    SharedPreferences.setMockInitialValues({});
    const dateKey = '2026-08-14';
    await RediscoverMemoryPrefs.saveDailySet(dateKey, const [
      {
        'id': 'first',
        'itemIds': [3, 1],
      },
      {
        'id': 'second',
        'itemIds': [8, 5],
      },
    ]);

    final restored = await RediscoverMemoryPrefs.loadDailySet(dateKey);

    expect(await RediscoverMemoryPrefs.hasDailySet(dateKey), isTrue);
    expect(await RediscoverMemoryPrefs.hasDailySet('2026-08-15'), isFalse);
    expect(restored.map((entry) => entry['id']), ['first', 'second']);
    expect(restored.first['itemIds'], [3, 1]);
  });

  test('recap seen-state suppresses unchanged recaps only', () async {
    SharedPreferences.setMockInitialValues({});

    expect(
      await RediscoverMemoryPrefs.canShowRecap(
        cadence: 'weekly',
        itemIds: [3, 1, 2],
      ),
      isTrue,
    );

    await RediscoverMemoryPrefs.markRecapSeen(
      cadence: 'weekly',
      itemIds: [1, 2, 3],
    );

    expect(
      await RediscoverMemoryPrefs.canShowRecap(
        cadence: 'weekly',
        itemIds: [3, 2, 1],
      ),
      isFalse,
    );
    expect(
      await RediscoverMemoryPrefs.canShowRecap(
        cadence: 'weekly',
        itemIds: [1, 2, 4],
      ),
      isTrue,
    );
  });

  test('related-save prefs cool down repeated pairs', () async {
    SharedPreferences.setMockInitialValues({});

    await RediscoverMemoryPrefs.saveRelatedSaves(
      sourceId: 20,
      relatedIds: [7, 8],
    );
    expect(await RediscoverMemoryPrefs.relatedSavesFor(20), [7, 8]);

    await RediscoverMemoryPrefs.saveRelatedSaves(sourceId: 20, relatedIds: [7]);
    expect(await RediscoverMemoryPrefs.relatedSavesFor(20), [7, 8]);
  });
}
