import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/url_processing_status.dart';
import 'package:glimpse/features/rediscover/rediscover_daily_set.dart';
import 'package:glimpse/features/rediscover/rediscover_journey_provider.dart';
import 'package:glimpse/features/rediscover/rediscover_memory.dart';
import 'package:glimpse/features/rediscover/rediscover_memory_prefs.dart';
import 'package:glimpse/features/rediscover/rediscover_provider.dart';
import 'package:glimpse/features/rediscover/rediscover_topic_pulse.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedUrl _url({
  required int id,
  required String title,
  required DateTime savedAt,
  required List<String> tags,
  List<double>? embedding,
  String category = 'Technology',
  String? enrichmentJson,
  String? intentStatus,
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
    ..savedAt = savedAt
    ..processingStatus = UrlProcessingStatus.ready
    ..embedding = embedding
    ..enrichmentJson = enrichmentJson
    ..intentStatus = intentStatus;
}

List<double> _vector(double cosine) => [cosine, math.sqrt(1 - cosine * cosine)];

String _enrichment({
  required List<String> topics,
  List<Map<String, String>> mentions = const [],
}) {
  return jsonEncode({
    'topics': topics,
    'mentions': mentions,
    'memory_intent': {'primary_intent': 'reference', 'life_area': 'technology'},
  });
}

void main() {
  const service = RediscoverTopicPulseService();
  final now = DateTime(2026, 8, 14, 12);

  test(
    'a real-world 0.60 match forms a strong pulse below the old 0.72 gate',
    () {
      final source = _url(
        id: 10,
        title: 'Useful GitHub tools for software teams',
        savedAt: DateTime(2026, 8, 13),
        tags: const ['github', 'software development'],
        embedding: const [1, 0],
      );
      final archive = _url(
        id: 1,
        title: 'GitHub coding agent reference',
        savedAt: DateTime(2026, 7, 10),
        tags: const ['github', 'coding agent'],
        embedding: _vector(0.60),
      );

      final pulse = service.detectForSave(
        source: source,
        library: [source, archive],
        now: now,
      );

      expect(pulse, isNotNull);
      expect(pulse!.confidence, RediscoverTopicPulseConfidence.strong);
      expect(pulse.archiveSaveIds, [archive.id]);
      expect(pulse.evidence, contains('similarity:0.600'));
    },
  );

  test('supported 0.45 matches require at least two older saves', () {
    final source = _url(
      id: 10,
      title: 'GitHub software references',
      savedAt: DateTime(2026, 8, 13),
      tags: const ['github', 'software development'],
      embedding: const [1, 0],
    );
    final first = _url(
      id: 1,
      title: 'GitHub architecture notes',
      savedAt: DateTime(2026, 7, 10),
      tags: const ['github', 'software architecture'],
      embedding: _vector(0.50),
    );
    final second = _url(
      id: 2,
      title: 'GitHub development workflow',
      savedAt: DateTime(2026, 7, 12),
      tags: const ['github', 'development workflow'],
      embedding: _vector(0.48),
    );

    expect(
      service.detectForSave(source: source, library: [source, first], now: now),
      isNull,
    );
    final pulse = service.detectForSave(
      source: source,
      library: [source, first, second],
      now: now,
    );
    expect(pulse, isNotNull);
    expect(pulse!.confidence, RediscoverTopicPulseConfidence.supported);
    expect(pulse.archiveSaveIds, hasLength(2));
  });

  test('subject conflicts reject even very high embedding similarity', () {
    final source = _url(
      id: 10,
      title: 'GitHub software architecture',
      savedAt: DateTime(2026, 8, 13),
      tags: const ['github', 'software'],
      embedding: const [1, 0],
    );
    final recipe = _url(
      id: 1,
      title: 'High protein dinner recipe',
      savedAt: DateTime(2026, 7, 1),
      tags: const ['recipe', 'cooking'],
      category: 'Food & Cooking',
      embedding: _vector(0.90),
    );

    expect(
      service.detectForSave(
        source: source,
        library: [source, recipe],
        now: now,
      ),
      isNull,
    );
  });

  test('generic overlap cannot support a medium-confidence pulse', () {
    final source = _url(
      id: 10,
      title: 'Movie recommendations for later',
      savedAt: DateTime(2026, 8, 13),
      tags: const ['movie recommendations', 'movies'],
      embedding: const [1, 0],
      intentStatus: 'queued',
    );
    final archive = _url(
      id: 1,
      title: 'More movie recommendations',
      savedAt: DateTime(2026, 7, 1),
      tags: const ['movie recommendations', 'movies'],
      embedding: _vector(0.50),
      intentStatus: 'queued',
    );

    expect(
      service.detectForSave(
        source: source,
        library: [source, archive],
        now: now,
      ),
      isNull,
    );
  });

  test('missing embeddings need two independent structured evidence types', () {
    final source = _url(
      id: 10,
      title: 'GitHub coding agents',
      savedAt: DateTime(2026, 8, 13),
      tags: const ['coding agents'],
      enrichmentJson: _enrichment(
        topics: const ['AI coding agents'],
        mentions: const [
          {'type': 'tool', 'name': 'Open Interpreter'},
        ],
      ),
    );
    SavedUrl archive(int id) => _url(
      id: id,
      title: 'Open Interpreter agent reference $id',
      savedAt: DateTime(2026, 7, id),
      tags: const ['coding agents'],
      enrichmentJson: _enrichment(
        topics: const ['AI coding agents'],
        mentions: const [
          {'type': 'tool', 'name': 'Open Interpreter'},
        ],
      ),
    );

    final pulse = service.detectForSave(
      source: source,
      library: [source, archive(1), archive(2)],
      now: now,
    );
    expect(pulse, isNotNull);
    expect(pulse!.confidence, RediscoverTopicPulseConfidence.supported);
  });

  test('daily memory features only older saves and reserves the trigger', () {
    final source = _url(
      id: 10,
      title: 'New GitHub reference',
      savedAt: DateTime(2026, 8, 13),
      tags: const ['github', 'software'],
      embedding: const [1, 0],
    );
    final archive = _url(
      id: 1,
      title: 'Older GitHub reference',
      savedAt: DateTime(2026, 7, 1),
      tags: const ['github', 'software'],
      embedding: _vector(0.60),
    );
    final pulse = service.detectForSave(
      source: source,
      library: [source, archive],
      now: now,
    )!;

    final memories = buildRediscoverDailyMemories(
      pulses: [pulse],
      liveUrls: [source, archive],
      now: now,
    );

    expect(memories, hasLength(1));
    final memory = memories.single;
    expect(memory.journey.kind, RediscoverJourneyKind.returningTopic);
    expect(memory.primaryUrl?.id, archive.id);
    expect(
      memory.journey.items.map((item) => item.url.id),
      isNot(contains(10)),
    );
    expect(memory.journey.triggerSaveId, source.id);
    expect(memory.whyNow, contains('New GitHub reference'));
  });

  test('due saves outrank returning-topic pulses', () {
    final source = _url(
      id: 10,
      title: 'New GitHub reference',
      savedAt: DateTime(2026, 8, 13),
      tags: const ['github', 'software'],
      embedding: const [1, 0],
    );
    final archive = _url(
      id: 1,
      title: 'Older GitHub reference',
      savedAt: DateTime(2026, 7, 1),
      tags: const ['github', 'software'],
      embedding: _vector(0.60),
    );
    final due = _url(
      id: 20,
      title: 'Read this now',
      savedAt: DateTime(2026, 8, 1),
      tags: const ['reading'],
      intentStatus: 'queued',
    );
    final pulse = service.detectForSave(
      source: source,
      library: [source, archive],
      now: now,
    )!;

    final memories = buildRediscoverDailyMemories(
      pulses: [pulse],
      liveUrls: [source, archive, due],
      now: now,
    );

    expect(memories.first.primaryUrl?.id, due.id);
    expect(memories[1].journey.kind, RediscoverJourneyKind.returningTopic);
  });

  test('new pulse replaces only the weakest untouched daily slot', () {
    RediscoverMemory regular(int id) {
      final url = _url(
        id: id,
        title: 'Existing memory $id',
        savedAt: DateTime(2026, 7, id),
        tags: ['topic-$id'],
      );
      return RediscoverMemory.fromJourney(
        RediscoverJourney(
          kind: RediscoverJourneyKind.becauseYouSaved,
          title: 'Topic $id',
          subtitle: 'Existing',
          icon: const IconData(0xe000),
          items: [
            RediscoveryItem(url: url, reason: 'Saved', timeAgo: '1mo ago'),
          ],
          signal: 70 - id.toDouble(),
          topicAnchor: 'Topic $id',
        ),
      );
    }

    final trigger = _url(
      id: 50,
      title: 'New signal',
      savedAt: DateTime(2026, 8, 14),
      tags: const ['github'],
    );
    final archive = _url(
      id: 51,
      title: 'Old reference',
      savedAt: DateTime(2026, 7, 1),
      tags: const ['github'],
    );
    final pulse = RediscoverMemory.fromJourney(
      RediscoverJourney(
        kind: RediscoverJourneyKind.returningTopic,
        title: 'GitHub',
        subtitle: 'Active again',
        icon: const IconData(0xe001),
        items: [
          RediscoveryItem(
            url: archive,
            reason: 'Forgotten gem',
            timeAgo: '1mo ago',
          ),
        ],
        signal: 95,
        topicAnchor: 'GitHub',
        stableTopicKey: 'software_ai:github',
        triggerSaveId: trigger.id,
        triggerTitle: trigger.title,
        topicPulseConfidence: RediscoverTopicPulseConfidence.strong.name,
        topicPulseDetectedAt: DateTime(2026, 8, 14, 11),
      ),
    );
    final existing = [regular(1), regular(2), regular(3)];

    final untouched = insertNewTopicPulseForDailySet(
      restored: existing,
      candidates: [pulse],
      generatedAt: DateTime(2026, 8, 14, 10),
      hasInteraction: false,
    );
    final interacted = insertNewTopicPulseForDailySet(
      restored: existing,
      candidates: [pulse],
      generatedAt: DateTime(2026, 8, 14, 10),
      hasInteraction: true,
    );

    expect(untouched.take(2).map((memory) => memory.id), [
      existing[0].id,
      existing[1].id,
    ]);
    expect(untouched.last.id, pulse.id);
    expect(interacted.map((memory) => memory.id), existing.map((m) => m.id));
  });

  test(
    'pulse and daily interaction state survive preference round trips',
    () async {
      SharedPreferences.setMockInitialValues({});
      final pulse = RediscoverTopicPulse(
        id: 'pulse:software_ai:github:10',
        topicKey: 'software_ai:github',
        topicLabel: 'GitHub',
        triggerSaveId: 10,
        archiveSaveIds: const [1, 2],
        confidence: RediscoverTopicPulseConfidence.supported,
        detectedAt: DateTime(2026, 8, 14, 11),
        evidence: const ['shared:github'],
        rankScore: 88,
      );

      await RediscoverMemoryPrefs.upsertTopicPulse(pulse.toJson());
      await RediscoverMemoryPrefs.saveDailySet(
        '2026-08-14',
        const [],
        generatedAt: DateTime(2026, 8, 14, 10),
      );
      await RediscoverMemoryPrefs.markDailySetInteracted('2026-08-14');

      final restored = (await RediscoverMemoryPrefs.loadTopicPulses())
          .map(RediscoverTopicPulse.fromJson)
          .whereType<RediscoverTopicPulse>()
          .single;
      expect(restored.id, pulse.id);
      expect(restored.archiveSaveIds, [1, 2]);
      expect(
        await RediscoverMemoryPrefs.dailySetGeneratedAt('2026-08-14'),
        DateTime(2026, 8, 14, 10),
      );
      expect(
        await RediscoverMemoryPrefs.hasDailySetInteraction('2026-08-14'),
        isTrue,
      );
    },
  );

  test('malformed pulse preferences degrade to an empty local cache', () async {
    SharedPreferences.setMockInitialValues({
      'rediscover_topic_pulses_v1': '{not-json',
    });

    expect(await RediscoverMemoryPrefs.loadTopicPulses(), isEmpty);
  });

  test(
    'topic fatigue blocks three days then recovers through day fourteen',
    () async {
      SharedPreferences.setMockInitialValues({});
      final markedAt = DateTime.now();
      await RediscoverMemoryPrefs.markTopicShown('software_ai:github');

      expect(
        await RediscoverMemoryPrefs.topicFatigueMultiplier(
          'software_ai:github',
          now: markedAt.add(const Duration(days: 1)),
        ),
        0,
      );
      final recovering = await RediscoverMemoryPrefs.topicFatigueMultiplier(
        'software_ai:github',
        now: markedAt.add(const Duration(days: 8)),
      );
      expect(recovering, inInclusiveRange(0.45, 0.99));
      expect(
        await RediscoverMemoryPrefs.topicFatigueMultiplier(
          'software_ai:github',
          now: markedAt.add(const Duration(days: 15)),
        ),
        1,
      );
    },
  );
}
