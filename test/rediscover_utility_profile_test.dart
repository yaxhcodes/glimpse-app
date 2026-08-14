import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/engagement_event.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/backup/backup_models.dart';
import 'package:glimpse/core/services/rediscover_utility_profile.dart';
import 'package:glimpse/features/rediscover/rediscover_journey_provider.dart';
import 'package:glimpse/features/rediscover/rediscover_memory.dart';
import 'package:glimpse/features/rediscover/rediscover_memory_prefs.dart';
import 'package:glimpse/features/rediscover/rediscover_open_context.dart';
import 'package:glimpse/features/rediscover/rediscover_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Rediscover utility learning', () {
    test(
      'cold utility is neutral and ignored impressions only add fatigue',
      () {
        final start = DateTime(2026, 8, 1, 9);
        var profile = _profile();
        for (var day = 0; day < 3; day++) {
          profile = profile.record(
            _event(
              EngagementEventType.cardShown,
              start.add(Duration(days: day)),
            ),
          );
        }

        final topic = profile.topics[_topic]!;
        expect(topic.attributedOutcomeCount, 0);
        expect(
          topic.utilityMultiplier(now: start.add(const Duration(days: 3))),
          1,
        );
        expect(topic.fatigueMultiplier, closeTo(0.98, 0.0001));
        expect(profile.topicMultiplier(_topic), closeTo(0.98, 0.0001));
      },
    );

    test('five attributed positive outcomes raise utility within bounds', () {
      final at = DateTime(2026, 8, 1);
      var profile = _profile();
      for (var i = 0; i < 5; i++) {
        profile = profile.record(
          _event(EngagementEventType.cardOpened, at.add(Duration(hours: i))),
        );
      }

      final multiplier = profile.topicMultiplier(_topic, now: at);
      expect(multiplier, greaterThan(1));
      expect(multiplier, inInclusiveRange(0.75, 1.25));
    });

    test(
      'Not now remains exact-memory feedback and Less like this recovers',
      () {
        final at = DateTime(2026, 8, 1);
        var snoozed = _profile();
        var dismissed = _profile();
        for (var i = 0; i < 5; i++) {
          snoozed = snoozed.record(
            _event(EngagementEventType.cardSnoozed, at.add(Duration(hours: i))),
          );
          dismissed = dismissed.record(
            _event(
              EngagementEventType.cardDismissed,
              at.add(Duration(hours: i)),
            ),
          );
        }

        expect(snoozed.topicMultiplier(_topic, now: at), 1);
        expect(
          dismissed.topicMultiplier(_topic, now: at),
          inInclusiveRange(0.75, 0.9),
        );
        expect(
          dismissed.topicMultiplier(
            _topic,
            now: at.add(const Duration(days: 900)),
          ),
          closeTo(1, 0.02),
        );
      },
    );

    test('reason-code outcomes are retained as derived aggregates', () {
      final at = DateTime(2026, 8, 1);
      var profile = _profile();
      profile = profile.record(_event(EngagementEventType.cardShown, at));
      profile = profile.record(
        _event(EngagementEventType.rediscoverCompleted, at),
      );

      final reason = profile.reasonUtilities['strongTopicReturn']!;
      expect(reason.impressionCount, 1);
      expect(reason.outcomeCount, 1);
      expect(reason.positiveScore, 5);
    });

    test(
      'same-origin restore keeps newest revision and different origins merge',
      () {
        final at = DateTime(2026, 8, 1);
        final older = _profile(
          origin: 'device-a',
        ).record(_event(EngagementEventType.cardOpened, at));
        final newer = older.record(
          _event(EngagementEventType.rediscoverCompleted, at),
        );
        expect(
          RediscoverUtilityProfile.merge(newer, older).revision,
          newer.revision,
        );

        final other = _profile(
          origin: 'device-b',
        ).record(_event(EngagementEventType.cardOpened, at));
        final merged = RediscoverUtilityProfile.merge(newer, other);
        expect(merged.topics[_topic]!.contentOpenCount, 2);
        expect(merged.topics[_topic]!.completedCount, 1);
      },
    );

    test('backup profile contains no raw content or navigation history', () {
      final profile = _profile().record(
        _event(EngagementEventType.cardOpened, DateTime(2026, 8, 1)),
      );
      final encoded = jsonEncode(profile.toBackupJson());

      expect(encoded, isNot(contains('https://')));
      expect(encoded, isNot(contains('private title')));
      expect(encoded, isNot(contains('exposureId')));
      expect(encoded, isNot(contains('query')));
      expect(encoded, isNot(contains('embedding')));
    });

    test(
      'profile origin and lifetime aggregates persist without raw events',
      () async {
        SharedPreferences.setMockInitialValues({});
        final initial = await RediscoverUtilityProfileStore.load();
        await RediscoverUtilityProfileStore.record(
          _event(EngagementEventType.rediscoverCompleted, DateTime(2026, 8, 1)),
        );
        final restored = await RediscoverUtilityProfileStore.load();

        expect(restored.originId, initial.originId);
        expect(restored.topics[_topic]!.completedCount, 1);
        expect(restored.revision, 1);
      },
    );

    test('optional backup profile round-trips as a versioned section', () {
      final profile = _profile().record(
        _event(EngagementEventType.cardOpened, DateTime(2026, 8, 1)),
      );
      final backup = BackupData(
        createdAt: '2026-08-01T00:00:00.000',
        appVersion: '1.0.0',
        links: const [],
        collections: const [],
        saveSessions: const [],
        settings: SettingsBackup(),
        rediscoverProfile: profile.toBackupJson(),
      );

      final restored = BackupData.fromJson(backup.toJson());
      final restoredProfile = RediscoverUtilityProfile.fromBackupJson(
        restored.rediscoverProfile,
      );
      expect(restoredProfile?.originId, profile.originId);
      expect(restoredProfile?.revision, profile.revision);
      expect(restoredProfile?.topics[_topic]?.contentOpenCount, 1);
    });

    test('legacy and malformed backup profiles remain optional', () {
      final legacy = BackupData.fromJson({
        'version': BackupData.currentVersion,
        'createdAt': '2026-08-01T00:00:00.000',
        'appVersion': '1.0.0',
        'links': <Object>[],
        'collections': <Object>[],
        'saveSessions': <Object>[],
        'settings': <String, Object?>{},
      });
      final malformed = BackupData.fromJson({
        ...legacy.toJson(),
        'rediscoverProfile': <Object>['not', 'a', 'profile'],
      });

      expect(legacy.rediscoverProfile, isNull);
      expect(malformed.rediscoverProfile, isNull);
      expect(
        RediscoverUtilityProfile.fromBackupJson({'schemaVersion': 999}),
        isNull,
      );
    });
  });

  test(
    'exposure identity is shared by surface and changes on date rollover',
    () {
      final memory = _memory();
      final day = DateTime(2026, 8, 14, 8);
      final home = RediscoverOpenContext.forMemory(
        memory,
        surface: RediscoverSurface.home,
        position: 0,
        now: day,
      );
      final rediscover = RediscoverOpenContext.forMemory(
        memory,
        surface: RediscoverSurface.rediscover,
        position: 0,
        now: day.add(const Duration(hours: 4)),
      );
      final tomorrow = RediscoverOpenContext.forMemory(
        memory,
        surface: RediscoverSurface.home,
        position: 0,
        now: day.add(const Duration(days: 1)),
      );

      expect(home.exposureId, rediscover.exposureId);
      expect(home.exposureId, isNot(tomorrow.exposureId));
      expect(home.reasonCode, RediscoverReasonCode.strongTopicReturn);
      expect(home.isValidAt(day.add(const Duration(hours: 6))), isTrue);
      expect(home.isValidAt(day.add(const Duration(hours: 7))), isFalse);
    },
  );

  test(
    'the shared Home and Rediscover exposure records once per day',
    () async {
      SharedPreferences.setMockInitialValues({});
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
      expect(
        await RediscoverMemoryPrefs.markMemoryShownOnce(
          memoryId: 'memory-1',
          dateKey: '2026-08-15',
        ),
        isTrue,
      );
    },
  );
}

const _topic = 'movies_watchlist:psychological-thrillers';

RediscoverUtilityProfile _profile({String origin = 'device-a'}) {
  return RediscoverUtilityProfile(
    originId: origin,
    revision: 0,
    topics: const {},
  );
}

EngagementEvent _event(EngagementEventType type, DateTime at) {
  return EngagementEvent()
    ..type = type
    ..at = at
    ..hourLocal = at.hour
    ..topicKey = _topic
    ..memoryId = 'memory-1'
    ..reasonCode = 'strongTopicReturn'
    ..confidenceTier = 'strong';
}

RediscoverMemory _memory() {
  final url = SavedUrl()
    ..id = 1
    ..rawUrl = 'https://example.com/1'
    ..domain = 'example.com'
    ..title = 'Private title'
    ..description = ''
    ..category = 'Movies'
    ..categoryEmoji = ''
    ..categories = ['Movies']
    ..tags = ['psychological thrillers']
    ..savedAt = DateTime(2026, 1, 1);
  return RediscoverMemory.fromJourney(
    RediscoverJourney(
      kind: RediscoverJourneyKind.returningTopic,
      title: 'Psychological thrillers',
      subtitle: 'Back in view',
      icon: Icons.movie_outlined,
      items: [
        RediscoveryItem(url: url, reason: 'Forgotten gem', timeAgo: '7mo'),
      ],
      signal: 1,
      stableTopicKey: _topic,
      topicPulseConfidence: 'strong',
      triggerSaveId: 2,
    ),
  );
}
