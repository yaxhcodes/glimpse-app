import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
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
}) {
  return SavedUrl()
    ..id = id
    ..rawUrl = 'https://example.com/$id'
    ..domain = 'example.com'
    ..title = title
    ..description = ''
    ..category = category
    ..categoryEmoji = ''
    ..categories = [category]
    ..tags = tags
    ..savedAt = savedAt ?? DateTime(2026, 6, 1)
    ..openedAt = openedAt
    ..intentStatus = intentStatus;
}

RediscoveryItem _item(SavedUrl url) {
  return RediscoveryItem(
    url: url,
    reason: 'Unopened',
    timeAgo: '2w ago',
  );
}

void main() {
  test('RediscoverMemory fully describes a resurfacing candidate', () {
    final first = _url(id: 7, title: 'High Protein Breakfast');
    final second = _url(
      id: 9,
      title: 'Soya Keema Masala',
      openedAt: DateTime(2026, 6, 5),
      intentStatus: 'queued',
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
    expect(memory.what, 'A Better Breakfast');
    expect(memory.copyIdentity.primary, memory.what);
    expect(memory.copyIdentity.secondaryDescription, contains('recipes'));
    expect(memory.copyIdentity.reasonForToday, contains('intent'));
    expect(memory.copyIdentity.suggestedNextStep, contains(first.title));
    expect(memory.emotion, RediscoverMemoryEmotion.recognition);
    expect(memory.personality, RediscoverMemoryPersonality.practical);
    expect(memory.encouragedAction, contains(first.title));

    expect(memory.homeCopy.title, memory.what);
    expect(memory.homeCopy.body, memory.whyNow);
    expect(memory.rediscoverCopy.body, contains(memory.whyItMatters));
    expect(memory.rediscoverCopy.actionLabel, contains(first.title));
    expect(memory.notificationCopy.title, contains('A Better Breakfast'));
    expect(memory.notificationCopy.body, contains('intent'));
    expect(memory.what, isNot(contains('waiting for you')));
    expect(memory.what, isNot(contains('curiosity')));

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
    expect(candidate.explanation.map((entry) => entry['code']), containsAll([
      'explicit_revisit',
      'long_unopened',
      'cooking_evening',
    ]));

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
              title: 'Notes on Attention',
              category: 'Philosophy',
              tags: const ['philosophy', 'attention'],
            ),
          ),
          _item(
            _url(
              id: 31,
              title: 'A Question About Desire',
              category: 'Philosophy',
              tags: const ['question', 'wisdom'],
            ),
          ),
          _item(
            _url(
              id: 32,
              title: 'The Habit of Reflection',
              category: 'Philosophy',
              tags: const ['reflection', 'stoicism'],
            ),
          ),
        ],
        signal: 78,
        topicAnchor: 'philosophy',
      ),
    );

    expect(buildMemory.personality, RediscoverMemoryPersonality.ambitious);
    expect(reflectiveMemory.personality, RediscoverMemoryPersonality.reflective);
    expect(buildMemory.what, isNot(reflectiveMemory.what));
    expect(buildMemory.what.toLowerCase(), isNot(contains('app architecture')));
    expect(reflectiveMemory.what.toLowerCase(), isNot(contains('philosophy')));
    expect(
      [buildMemory.what, reflectiveMemory.what].join(' '),
      isNot(contains('waiting for you')),
    );
  });
}
