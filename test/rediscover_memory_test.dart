import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/url_processing_status.dart';
import 'package:glimpse/core/services/affinity_profile.dart';
import 'package:glimpse/features/mindmap/cluster_theme.dart';
import 'package:glimpse/features/rediscover/rediscover_journey_provider.dart';
import 'package:glimpse/features/rediscover/rediscover_memory.dart';
import 'package:glimpse/features/rediscover/rediscover_notification_candidate.dart';
import 'package:glimpse/features/rediscover/rediscover_provider.dart';

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
}) {
  return SavedUrl()
    ..id = id
    ..rawUrl = 'https://example.com/$id'
    ..domain = 'example.com'
    ..title = title
    ..description = ''
    ..summary = summary
    ..category = category
    ..categoryEmoji = ''
    ..categories = [category]
    ..tags = tags
    ..savedAt = savedAt ?? DateTime(2026, 6, 1)
    ..openedAt = openedAt
    ..intentStatus = intentStatus
    ..processingStatus = UrlProcessingStatus.ready
    ..embedding = embedding
    ..enrichmentJson = enrichmentJson;
}

String _intentJson({
  required String primaryIntent,
  required String why,
  String? lifeArea,
}) {
  return jsonEncode({
    'memory_intent': {
      'primary_intent': primaryIntent,
      'life_area': lifeArea,
      'why_saved_hypothesis': why,
    },
  });
}

RediscoveryItem _item(SavedUrl url) {
  return RediscoveryItem(url: url, reason: 'Unopened', timeAgo: '2w ago');
}

void main() {
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
    expect(memory.what, 'High-Protein Breakfasts');
    expect(memory.copyIdentity.primary, memory.what);
    expect(
      memory.copyIdentity.secondaryDescription,
      contains('cook high-protein breakfasts'),
    );
    expect(memory.copyIdentity.reasonForToday, contains('collecting recipes'));
    expect(memory.copyIdentity.suggestedNextStep, contains(first.title));
    expect(memory.semanticIntent.label, 'High-Protein Breakfasts');
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
    expect(memory.notificationCopy.title, contains('High-Protein Breakfasts'));
    expect(memory.notificationCopy.body, contains('collecting recipes'));
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
    expect(titles, contains('Free Will'));
    expect(titles, contains('AI & Consciousness'));
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
  });
}
