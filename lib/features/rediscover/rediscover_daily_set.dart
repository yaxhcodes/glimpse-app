import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/engagement_event.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/affinity_profile.dart';
import '../../core/services/memory_intent_resolver.dart';
import '../../core/services/rediscover_utility_profile.dart';
import '../../core/services/tag_analyzer.dart';
import '../../core/services/title_resolver.dart';
import '../home/home_provider.dart';
import 'rediscover_journey_provider.dart';
import 'rediscover_memory.dart';
import 'rediscover_memory_prefs.dart';
import 'rediscover_open_context.dart';
import 'rediscover_provider.dart';
import 'rediscover_topic_pulse.dart';
import 'rediscover_topic_pulse_provider.dart';

class RediscoverDailySet {
  const RediscoverDailySet({
    required this.localDate,
    required this.memories,
    this.generatedAt,
  });

  final DateTime localDate;
  final List<RediscoverMemory> memories;
  final DateTime? generatedAt;

  RediscoverDailySet copyWith({List<RediscoverMemory>? memories}) {
    return RediscoverDailySet(
      localDate: localDate,
      memories: memories ?? this.memories,
      generatedAt: generatedAt,
    );
  }
}

final rediscoverDailySetProvider = FutureProvider<RediscoverDailySet>((
  ref,
) async {
  ref.watch(
    urlStreamProvider.select(
      (async) => async.whenOrNull(data: (urls) => urls.length),
    ),
  );
  final now = DateTime.now();
  final dateKey = rediscoverDateKey(now);
  final allUrlsFuture = ref.read(isarServiceProvider).getAllUrls();
  final pulsesFuture = ref.watch(rediscoverTopicPulsesProvider.future);
  final profileFuture = ref.watch(affinityProfileProvider.future);
  final utilityFuture = ref.watch(rediscoverUtilityProfileProvider.future);
  final pulses = await pulsesFuture;
  final profile = await profileFuture;
  final utilityProfile = await utilityFuture;
  final allUrls = await allUrlsFuture;
  final liveUrls = allUrls.where(_isEligible).toList();
  final candidates = buildRediscoverDailyMemories(
    pulses: pulses,
    profile: profile,
    utilityProfile: utilityProfile,
    liveUrls: liveUrls,
    now: now,
    limit: 8,
  );
  final visibleCandidates = (await _withoutLifecycleSuppression(
    candidates,
    now: now,
  )).take(3).toList();

  final hasPersistedSet = await RediscoverMemoryPrefs.hasDailySet(dateKey);
  if (!hasPersistedSet) {
    await RediscoverMemoryPrefs.saveDailySet(
      dateKey,
      visibleCandidates.map(_recordFor).toList(),
      generatedAt: now,
    );
    return RediscoverDailySet(
      localDate: DateTime(now.year, now.month, now.day),
      memories: visibleCandidates,
      generatedAt: now,
    );
  }

  final records = await RediscoverMemoryPrefs.loadDailySet(dateKey);
  final generatedAt = await RediscoverMemoryPrefs.dailySetGeneratedAt(dateKey);
  final restored = <RediscoverMemory>[];
  for (final record in records) {
    final memory = _memoryFromRecord(record, liveUrls);
    if (memory == null) continue;
    if (await RediscoverMemoryPrefs.isMemorySnoozed(memory.id, now: now)) {
      continue;
    }
    if (await RediscoverMemoryPrefs.isTopicSuppressed(
      memory.topicKey,
      now: now,
    )) {
      continue;
    }
    restored.add(memory);
  }

  final stableRestored = _dedupeRestoredMemories(restored);
  final withDueException = _insertNewlyDueMemory(
    restored: stableRestored,
    candidates: visibleCandidates,
    liveUrls: liveUrls,
  );
  final hasInteraction = await RediscoverMemoryPrefs.hasDailySetInteraction(
    dateKey,
  );
  final withPulseException = insertNewTopicPulseForDailySet(
    restored: withDueException,
    candidates: visibleCandidates,
    generatedAt: generatedAt,
    hasInteraction: hasInteraction,
  );
  if (!_sameMemoryOrder(restored, withPulseException)) {
    await RediscoverMemoryPrefs.saveDailySet(
      dateKey,
      withPulseException.map(_recordFor).toList(),
      generatedAt: generatedAt,
    );
  }
  return RediscoverDailySet(
    localDate: DateTime(now.year, now.month, now.day),
    memories: withPulseException,
    generatedAt: generatedAt,
  );
});

final rediscoverDailySetControllerProvider = Provider((ref) {
  return RediscoverDailySetController(ref);
});

class RediscoverDailySetController {
  RediscoverDailySetController(this._ref);

  final Ref _ref;
  final Set<String> _shownThisRun = {};

  Future<void> markShown(RediscoverMemory memory) =>
      markShownWithContext(memory);

  Future<void> markShownWithContext(
    RediscoverMemory memory, {
    RediscoverSurface surface = RediscoverSurface.rediscover,
    int position = 0,
  }) async {
    if (!_shownThisRun.add(memory.id)) return;
    final didRecord = await RediscoverMemoryPrefs.markMemoryShownOnce(
      memoryId: memory.id,
      dateKey: rediscoverDateKey(DateTime.now()),
    );
    if (!didRecord) return;
    final context = RediscoverOpenContext.forMemory(
      memory,
      surface: surface,
      position: position,
    );
    await RediscoverMemoryPrefs.markTopicShown(memory.topicKey);
    await _ref
        .read(isarServiceProvider)
        .logEvent(
          type: EngagementEventType.cardShown,
          url: memory.primaryUrl,
          clusterLabel: memory.topicKey,
          memoryId: context.memoryId,
          topicKey: context.topicKey,
          surface: context.surface.name,
          position: context.position,
          reasonCode: context.reasonCode.name,
          confidenceTier: context.confidenceTier,
          algorithmVersion: context.algorithmVersion,
          exposureId: context.exposureId,
        );
    _ref.invalidate(rediscoverUtilityProfileProvider);
  }

  Future<void> markOpened(RediscoverMemory memory) => markOpenedWithContext(
    memory,
    openContext: RediscoverOpenContext.forMemory(
      memory,
      surface: RediscoverSurface.rediscover,
      position: 0,
    ),
  );

  Future<void> markOpenedWithContext(
    RediscoverMemory memory, {
    required RediscoverOpenContext openContext,
  }) async {
    final context = openContext;
    await RediscoverMemoryPrefs.markMemoryOpened(memory.id);
    await RediscoverMemoryPrefs.markDailySetInteracted(
      rediscoverDateKey(DateTime.now()),
    );
    await _ref
        .read(isarServiceProvider)
        .logEvent(
          type: EngagementEventType.clusterVisit,
          url: memory.primaryUrl,
          clusterLabel: memory.topicKey,
          memoryId: context.memoryId,
          topicKey: context.topicKey,
          surface: context.surface.name,
          position: context.position,
          reasonCode: context.reasonCode.name,
          confidenceTier: context.confidenceTier,
          algorithmVersion: context.algorithmVersion,
          exposureId: context.exposureId,
        );
    _ref.invalidate(rediscoverUtilityProfileProvider);
  }

  Future<void> snooze(RediscoverMemory memory) => snoozeWithContext(
    memory,
    openContext: RediscoverOpenContext.forMemory(
      memory,
      surface: RediscoverSurface.rediscover,
      position: 0,
    ),
  );

  Future<void> snoozeWithContext(
    RediscoverMemory memory, {
    required RediscoverOpenContext openContext,
  }) async {
    final context = openContext;
    await RediscoverMemoryPrefs.snoozeMemory(memory.id);
    await RediscoverMemoryPrefs.markDailySetInteracted(
      rediscoverDateKey(DateTime.now()),
    );
    await _ref
        .read(isarServiceProvider)
        .logEvent(
          type: EngagementEventType.cardSnoozed,
          url: memory.primaryUrl,
          clusterLabel: memory.topicKey,
          memoryId: context.memoryId,
          topicKey: context.topicKey,
          surface: context.surface.name,
          position: context.position,
          reasonCode: context.reasonCode.name,
          confidenceTier: context.confidenceTier,
          algorithmVersion: context.algorithmVersion,
          exposureId: context.exposureId,
        );
    _ref.invalidate(rediscoverUtilityProfileProvider);
    _ref.invalidate(rediscoverDailySetProvider);
  }

  Future<void> lessLikeThis(RediscoverMemory memory) => lessLikeThisWithContext(
    memory,
    openContext: RediscoverOpenContext.forMemory(
      memory,
      surface: RediscoverSurface.rediscover,
      position: 0,
    ),
  );

  Future<void> lessLikeThisWithContext(
    RediscoverMemory memory, {
    required RediscoverOpenContext openContext,
  }) async {
    final context = openContext;
    await RediscoverMemoryPrefs.suppressTopic(memory.topicKey);
    await RediscoverMemoryPrefs.markDailySetInteracted(
      rediscoverDateKey(DateTime.now()),
    );
    await _ref
        .read(isarServiceProvider)
        .logEvent(
          type: EngagementEventType.cardDismissed,
          url: memory.primaryUrl,
          clusterLabel: memory.topicKey,
          memoryId: context.memoryId,
          topicKey: context.topicKey,
          surface: context.surface.name,
          position: context.position,
          reasonCode: context.reasonCode.name,
          confidenceTier: context.confidenceTier,
          algorithmVersion: context.algorithmVersion,
          exposureId: context.exposureId,
        );
    _ref.invalidate(rediscoverUtilityProfileProvider);
    _ref.invalidate(rediscoverDailySetProvider);
  }
}

Future<void> markRediscoverMemoryShown(
  RediscoverDailySetController controller,
  RediscoverMemory memory, {
  required RediscoverSurface surface,
  required int position,
}) {
  return controller.markShownWithContext(
    memory,
    surface: surface,
    position: position,
  );
}

Future<void> markRediscoverMemoryOpened(
  RediscoverDailySetController controller,
  RediscoverMemory memory, {
  required RediscoverOpenContext openContext,
}) {
  return controller.markOpenedWithContext(memory, openContext: openContext);
}

Future<void> snoozeRediscoverMemory(
  RediscoverDailySetController controller,
  RediscoverMemory memory, {
  required RediscoverOpenContext openContext,
}) {
  return controller.snoozeWithContext(memory, openContext: openContext);
}

Future<void> suppressRediscoverTopic(
  RediscoverDailySetController controller,
  RediscoverMemory memory, {
  required RediscoverOpenContext openContext,
}) {
  return controller.lessLikeThisWithContext(memory, openContext: openContext);
}

List<RediscoverMemory> _dedupeRestoredMemories(
  List<RediscoverMemory> memories,
) {
  final kept = <RediscoverMemory>[];
  final usedIds = <int>{};
  final usedTopics = <String>{};
  final usedIdentities = <String>{};
  for (final memory in memories) {
    final ids = _reservedIds(memory.journey);
    final topic = _normalizeTopic(memory.topicKey);
    final identity = _normalizeTopic(memory.rediscoverCopy.title);
    if (ids.any(usedIds.contains) ||
        !usedTopics.add(topic) ||
        !usedIdentities.add(identity)) {
      continue;
    }
    kept.add(memory);
    usedIds.addAll(ids);
  }
  return kept;
}

List<RediscoverMemory> buildRediscoverDailyMemories({
  List<RediscoverJourney> journeys = const [],
  List<RediscoverTopicPulse> pulses = const [],
  AffinityProfile profile = AffinityProfile.empty,
  RediscoverUtilityProfile utilityProfile = RediscoverUtilityProfile.empty,
  required List<SavedUrl> liveUrls,
  required DateTime now,
  int limit = 3,
}) {
  if (limit <= 0) return const [];
  final eligibleById = {
    for (final url in liveUrls.where(_isEligible)) url.id: url,
  };
  if (eligibleById.isEmpty) return const [];

  final candidates = <_DailyCandidate>[];
  final journeySaveIds = <int>{};
  for (final pulse in pulses) {
    final trigger = eligibleById[pulse.triggerSaveId];
    if (trigger == null) continue;
    final archive = <SavedUrl>[];
    for (final id in pulse.archiveSaveIds) {
      final url = eligibleById[id];
      if (url != null && archive.every((item) => item.id != id)) {
        archive.add(url);
      }
    }
    final minimumItems =
        pulse.confidence == RediscoverTopicPulseConfidence.strong ? 1 : 2;
    if (archive.length < minimumItems) continue;
    final signal =
        pulse.rankScore *
        profile.clusterMultiplier(pulse.topicKey) *
        utilityProfile.topicMultiplier(pulse.topicKey, now: now);
    final journey = RediscoverJourney(
      kind: RediscoverJourneyKind.returningTopic,
      title: pulse.topicLabel,
      subtitle:
          'You’ve started saving about ${pulse.topicLabel.toLowerCase()} again',
      icon: Icons.history_toggle_off_rounded,
      items: archive
          .map(
            (url) => RediscoveryItem(
              url: url,
              reason: _itemReason(url),
              timeAgo: _timeAgo(url.savedAt, now),
            ),
          )
          .toList(),
      signal: signal,
      recommendedFirstSaveId: archive.first.id,
      topicAnchor: pulse.topicLabel,
      stableTopicKey: pulse.topicKey,
      triggerSaveId: pulse.triggerSaveId,
      triggerTitle: TitleResolver.resolveDetailTitle(trigger),
      topicPulseConfidence: pulse.confidence.name,
      topicPulseDetectedAt: pulse.detectedAt,
    );
    candidates.add(
      _DailyCandidate(
        journey: journey,
        explicitPriority: 1,
        score: signal + _enrichmentQualityScore(journey),
      ),
    );
    journeySaveIds.addAll(_reservedIds(journey));
  }
  for (final journey in journeys) {
    final sanitized = _sanitizedJourney(journey, eligibleById);
    if (sanitized == null) continue;
    final hasDue = sanitized.items.any((item) => item.url.isRevisitDue);
    journeySaveIds.addAll(_reservedIds(sanitized));
    candidates.add(
      _DailyCandidate(
        journey: sanitized,
        explicitPriority: hasDue ? 2 : 0,
        score:
            (sanitized.signal + _enrichmentQualityScore(sanitized)) *
            utilityProfile.topicMultiplier(_topicKey(sanitized), now: now),
      ),
    );
  }

  final due =
      eligibleById.values
          .where((url) => url.isRevisitDue && !journeySaveIds.contains(url.id))
          .toList()
        ..sort((a, b) {
          final aDue = a.revisitAfter ?? a.savedAt;
          final bDue = b.revisitAfter ?? b.savedAt;
          return aDue.compareTo(bDue);
        });
  for (final url in due) {
    candidates.add(
      _DailyCandidate(
        journey: _singleJourney(
          url,
          kind: RediscoverJourneyKind.continueLearning,
          reason: 'You chose to revisit this',
          signal: 120,
        ),
        explicitPriority: 3,
        score: 120,
      ),
    );
  }

  final alreadyGrouped = {
    for (final candidate in candidates) ..._reservedIds(candidate.journey),
  };
  final seasonal =
      eligibleById.values
          .where(
            (url) =>
                !alreadyGrouped.contains(url.id) &&
                _seasonalReason(url.savedAt, now) != null,
          )
          .toList()
        ..sort((a, b) => a.savedAt.compareTo(b.savedAt));
  if (seasonal.isNotEmpty) {
    final url = seasonal.first;
    candidates.add(
      _DailyCandidate(
        journey: _singleJourney(
          url,
          kind: RediscoverJourneyKind.onThisDay,
          reason: _seasonalReason(url.savedAt, now)!,
          signal: 72,
        ),
        explicitPriority: 0,
        score: 72,
      ),
    );
    alreadyGrouped.add(url.id);
  }

  final gems =
      eligibleById.values
          .where(
            (url) =>
                !alreadyGrouped.contains(url.id) &&
                url.openedAt == null &&
                now.difference(url.savedAt).inDays >= 30 &&
                url.hasPresentableEnrichment &&
                _isExceptionalGem(url) &&
                ((url.thumbnailUrl ?? '').trim().isNotEmpty ||
                    (url.summary ?? '').trim().isNotEmpty),
          )
          .toList()
        ..sort((a, b) => a.savedAt.compareTo(b.savedAt));
  if (gems.isNotEmpty) {
    candidates.add(
      _DailyCandidate(
        journey: _singleJourney(
          gems.first,
          kind: RediscoverJourneyKind.forgottenGems,
          reason: 'Forgotten gem',
          signal: 68,
        ),
        explicitPriority: 0,
        score: 68,
      ),
    );
  }

  candidates.sort((a, b) {
    final byIntent = b.explicitPriority.compareTo(a.explicitPriority);
    if (byIntent != 0) return byIntent;
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return _topicKey(a.journey).compareTo(_topicKey(b.journey));
  });

  final selected = <RediscoverMemory>[];
  final usedIds = <int>{};
  final usedTopics = <String>{};
  final usedIdentities = <String>{};
  for (final candidate in candidates) {
    if (selected.length >= limit) break;
    final topic = _normalizeTopic(_topicKey(candidate.journey));
    if (!usedTopics.add(topic)) continue;
    final triggerId = candidate.journey.triggerSaveId;
    if (triggerId != null && usedIds.contains(triggerId)) continue;
    final remaining = candidate.journey.items
        .where((item) => !usedIds.contains(item.url.id))
        .toList();
    final minimumItems = candidate.journey.items.length == 1 ? 1 : 2;
    if (remaining.length < minimumItems) continue;
    final journey = _copyJourney(candidate.journey, items: remaining);
    final memory = RediscoverMemory.fromJourney(journey);
    final identity = _normalizeTopic(memory.rediscoverCopy.title);
    if (!usedIdentities.add(identity)) continue;
    selected.add(memory);
    usedIds.addAll(remaining.map((item) => item.url.id));
    if (triggerId != null) usedIds.add(triggerId);
  }
  return selected;
}

Future<List<RediscoverMemory>> _withoutLifecycleSuppression(
  List<RediscoverMemory> memories, {
  required DateTime now,
}) async {
  final visible = <RediscoverMemory>[];
  for (final memory in memories) {
    final hasDue = memory.journey.items.any((item) => item.url.isRevisitDue);
    if (await RediscoverMemoryPrefs.isMemorySnoozed(memory.id, now: now)) {
      continue;
    }
    if (await RediscoverMemoryPrefs.isTopicSuppressed(
      memory.topicKey,
      now: now,
    )) {
      continue;
    }
    if (!hasDue &&
        await RediscoverMemoryPrefs.wasMemoryShownRecently(
          memory.id,
          now: now,
        )) {
      continue;
    }
    if (!hasDue &&
        await RediscoverMemoryPrefs.wasMemoryOpenedRecently(
          memory.id,
          now: now,
        )) {
      continue;
    }
    final fatigue = hasDue
        ? 1.0
        : await RediscoverMemoryPrefs.topicFatigueMultiplier(
            memory.topicKey,
            now: now,
          );
    if (fatigue == 0) continue;
    if (fatigue < 1) {
      final journey = _copyJourney(
        memory.journey,
        items: memory.journey.items,
        signal: memory.journey.signal * fatigue,
      );
      visible.add(RediscoverMemory.fromJourney(journey));
    } else {
      visible.add(memory);
    }
  }
  visible.sort((a, b) {
    final aDue = a.journey.items.any((item) => item.url.isRevisitDue) ? 1 : 0;
    final bDue = b.journey.items.any((item) => item.url.isRevisitDue) ? 1 : 0;
    final byDue = bDue.compareTo(aDue);
    if (byDue != 0) return byDue;
    final bySignal = b.journey.signal.compareTo(a.journey.signal);
    if (bySignal != 0) return bySignal;
    return a.topicKey.compareTo(b.topicKey);
  });
  return visible;
}

List<RediscoverMemory> _insertNewlyDueMemory({
  required List<RediscoverMemory> restored,
  required List<RediscoverMemory> candidates,
  required List<SavedUrl> liveUrls,
}) {
  final dueIds = liveUrls
      .where((url) => url.isRevisitDue)
      .map((url) => url.id)
      .toSet();
  final representedIds = restored
      .expand((memory) => _reservedIds(memory.journey))
      .toSet();
  final missingDueIds = dueIds.difference(representedIds);
  if (missingDueIds.isEmpty) return restored;

  RediscoverMemory? dueMemory;
  for (final candidate in candidates) {
    if (candidate.journey.items.any(
      (item) => missingDueIds.contains(item.url.id),
    )) {
      dueMemory = candidate;
      break;
    }
  }
  if (dueMemory == null) return restored;

  final dueTopic = _normalizeTopic(dueMemory.topicKey);
  final dueSaveIds = _reservedIds(dueMemory.journey);
  final kept = restored.where((memory) {
    if (_normalizeTopic(memory.topicKey) == dueTopic) return false;
    final ids = _reservedIds(memory.journey);
    return ids.intersection(dueSaveIds).isEmpty;
  });
  return [dueMemory, ...kept].take(3).toList();
}

List<RediscoverMemory> insertNewTopicPulseForDailySet({
  required List<RediscoverMemory> restored,
  required List<RediscoverMemory> candidates,
  required DateTime? generatedAt,
  required bool hasInteraction,
}) {
  if (hasInteraction || generatedAt == null) return restored;
  final usedIds = {
    for (final memory in restored) ..._reservedIds(memory.journey),
  };
  final usedTopics = restored
      .map((memory) => _normalizeTopic(memory.topicKey))
      .toSet();
  RediscoverMemory? pulse;
  for (final candidate in candidates) {
    final journey = candidate.journey;
    final detectedAt = journey.topicPulseDetectedAt;
    if (journey.kind != RediscoverJourneyKind.returningTopic ||
        detectedAt == null ||
        !detectedAt.isAfter(generatedAt)) {
      continue;
    }
    if (usedTopics.contains(_normalizeTopic(candidate.topicKey))) continue;
    if (_reservedIds(journey).any(usedIds.contains)) continue;
    pulse = candidate;
    break;
  }
  if (pulse == null) return restored;
  if (restored.length < 3) return [...restored, pulse];
  return [...restored.take(2), pulse];
}

RediscoverJourney? _sanitizedJourney(
  RediscoverJourney journey,
  Map<int, SavedUrl> eligibleById,
) {
  final seen = <int>{};
  final items = <RediscoveryItem>[];
  for (final item in journey.items) {
    final current = eligibleById[item.url.id];
    if (current == null || !seen.add(current.id)) continue;
    items.add(
      RediscoveryItem(url: current, reason: item.reason, timeAgo: item.timeAgo),
    );
  }
  if (items.length < (journey.items.length == 1 ? 1 : 2)) return null;
  return _copyJourney(journey, items: items);
}

RediscoverJourney _singleJourney(
  SavedUrl url, {
  required RediscoverJourneyKind kind,
  required String reason,
  required double signal,
}) {
  final topic = _topicForUrl(url);
  return RediscoverJourney(
    kind: kind,
    title: topic,
    subtitle: reason,
    icon: switch (kind) {
      RediscoverJourneyKind.onThisDay => Icons.history_rounded,
      RediscoverJourneyKind.forgottenGems => Icons.diamond_outlined,
      _ => Icons.play_circle_outline_rounded,
    },
    items: [
      RediscoveryItem(
        url: url,
        reason: reason,
        timeAgo: _timeAgo(url.savedAt, DateTime.now()),
      ),
    ],
    signal: signal,
    recommendedFirstSaveId: url.id,
    topicAnchor: topic,
  );
}

RediscoverJourney _copyJourney(
  RediscoverJourney journey, {
  required List<RediscoveryItem> items,
  double? signal,
}) {
  final recommendedId =
      items.any((item) => item.url.id == journey.recommendedFirstSaveId)
      ? journey.recommendedFirstSaveId
      : items.firstOrNull?.url.id;
  return RediscoverJourney(
    kind: journey.kind,
    title: journey.title,
    subtitle: journey.subtitle,
    icon: journey.icon,
    items: items,
    signal: signal ?? journey.signal,
    categoryLabel: journey.categoryLabel,
    hookLine: journey.hookLine,
    narrative: journey.narrative,
    recommendedFirstSaveId: recommendedId,
    topicAnchor: journey.topicAnchor,
    stableTopicKey: journey.stableTopicKey,
    triggerSaveId: journey.triggerSaveId,
    triggerTitle: journey.triggerTitle,
    topicPulseConfidence: journey.topicPulseConfidence,
    topicPulseDetectedAt: journey.topicPulseDetectedAt,
  );
}

Map<String, Object?> _recordFor(RediscoverMemory memory) {
  final journey = memory.journey;
  return {
    'id': memory.id,
    'kind': journey.kind.name,
    'title': journey.title,
    'subtitle': journey.subtitle,
    'signal': journey.signal,
    'categoryLabel': journey.categoryLabel,
    'hookLine': journey.hookLine,
    'narrative': journey.narrative,
    'recommendedFirstSaveId': journey.recommendedFirstSaveId,
    'topicAnchor': journey.topicAnchor,
    'stableTopicKey': journey.stableTopicKey,
    'triggerSaveId': journey.triggerSaveId,
    'triggerTitle': journey.triggerTitle,
    'topicPulseConfidence': journey.topicPulseConfidence,
    'topicPulseDetectedAt': journey.topicPulseDetectedAt?.toIso8601String(),
    'itemIds': journey.items.map((item) => item.url.id).toList(),
    'reasons': journey.items.map((item) => item.reason).toList(),
    'minimumItems': journey.kind == RediscoverJourneyKind.returningTopic
        ? (journey.topicPulseConfidence ==
                  RediscoverTopicPulseConfidence.strong.name
              ? 1
              : 2)
        : (journey.items.length == 1 ? 1 : 2),
  };
}

RediscoverMemory? _memoryFromRecord(
  Map<String, Object?> record,
  List<SavedUrl> liveUrls,
) {
  final kindName = record['kind']?.toString();
  final kind = RediscoverJourneyKind.values
      .where((value) => value.name == kindName)
      .firstOrNull;
  final rawIds = record['itemIds'];
  if (kind == null || rawIds is! List) return null;
  final ids = rawIds.whereType<num>().map((id) => id.toInt()).toList();
  final byId = {for (final url in liveUrls) url.id: url};
  final triggerValue = record['triggerSaveId'];
  final triggerId = triggerValue is num ? triggerValue.toInt() : null;
  final trigger = triggerId == null ? null : byId[triggerId];
  if (kind == RediscoverJourneyKind.returningTopic && trigger == null) {
    return null;
  }
  final rawReasons = record['reasons'];
  final reasons = rawReasons is List
      ? rawReasons.map((reason) => reason.toString()).toList()
      : const <String>[];
  final items = <RediscoveryItem>[];
  for (var index = 0; index < ids.length; index++) {
    final url = byId[ids[index]];
    if (url == null || items.any((item) => item.url.id == url.id)) continue;
    items.add(
      RediscoveryItem(
        url: url,
        reason: index < reasons.length ? reasons[index] : _itemReason(url),
        timeAgo: _timeAgo(url.savedAt, DateTime.now()),
      ),
    );
  }
  final minimumItems = (record['minimumItems'] as num?)?.toInt() ?? 2;
  if (items.length < minimumItems) return null;
  final signalValue = record['signal'];
  final recommendedValue = record['recommendedFirstSaveId'];
  final journey = RediscoverJourney(
    kind: kind,
    title:
        record['title']?.toString() ?? record['topicAnchor']?.toString() ?? '',
    subtitle: record['subtitle']?.toString() ?? '',
    icon: _iconFor(kind),
    items: items,
    signal: signalValue is num ? signalValue.toDouble() : 0,
    categoryLabel: _nullableString(record['categoryLabel']),
    hookLine: _nullableString(record['hookLine']),
    narrative: _nullableString(record['narrative']),
    recommendedFirstSaveId: recommendedValue is num
        ? recommendedValue.toInt()
        : null,
    topicAnchor: _nullableString(record['topicAnchor']),
    stableTopicKey: _nullableString(record['stableTopicKey']),
    triggerSaveId: triggerId,
    triggerTitle: trigger == null
        ? _nullableString(record['triggerTitle'])
        : TitleResolver.resolveDetailTitle(trigger),
    topicPulseConfidence: _nullableString(record['topicPulseConfidence']),
    topicPulseDetectedAt: DateTime.tryParse(
      record['topicPulseDetectedAt']?.toString() ?? '',
    ),
  );
  return RediscoverMemory.fromJourney(journey);
}

bool _isEligible(SavedUrl url) {
  return !url.isInBin &&
      !url.isDone &&
      url.rediscoverDismissedAt == null &&
      (!url.isQueued || url.isRevisitDue) &&
      url.isProcessingReady;
}

bool _isExceptionalGem(SavedUrl url) {
  final intent = MemoryIntentResolver.fromUrl(url);
  final actionability = intent?.actionability?.trim().toLowerCase();
  final horizon = intent?.timeHorizon?.trim().toLowerCase();
  return actionability == 'high' && (horizon == 'now' || horizon == 'soon');
}

Set<int> _reservedIds(RediscoverJourney journey) {
  return {
    for (final item in journey.items) item.url.id,
    if (journey.triggerSaveId != null) journey.triggerSaveId!,
  };
}

String _topicForUrl(SavedUrl url) {
  final topics = TagAnalyzer.notificationTopicTags(url.tags);
  if (topics.isNotEmpty) return topics.first;
  for (final category in url.effectiveCategories) {
    final value = category.trim();
    if (value.isNotEmpty && value != 'Other' && value != 'Web') return value;
  }
  return TitleResolver.resolveDetailTitle(url);
}

String? _seasonalReason(DateTime savedAt, DateTime now) {
  final days = now.difference(savedAt).inDays;
  bool near(int target) => (days - target).abs() <= 3;
  if (near(365)) return 'A year ago around now';
  if (near(180)) return 'Six months ago around now';
  if (near(90)) return 'Three months ago around now';
  if (near(30)) return 'A month ago around now';
  return null;
}

String _itemReason(SavedUrl url) {
  if (url.isQueued) return 'You chose to revisit this';
  if (url.openedAt != null) return 'Previously opened';
  return 'Forgotten gem';
}

double _enrichmentQualityScore(RediscoverJourney journey) {
  if (journey.items.isEmpty) return 0;
  var total = 0.0;
  for (final item in journey.items) {
    final url = item.url;
    if ((url.summary ?? '').trim().isNotEmpty) total += 3;
    if ((url.thumbnailUrl ?? '').trim().isNotEmpty) total += 2;
    if ((url.enrichmentJson ?? '').trim().isNotEmpty) total += 3;
    if (url.embedding?.isNotEmpty == true) total += 2;
  }
  return total / journey.items.length;
}

String _timeAgo(DateTime date, DateTime now) {
  final days = now.difference(date).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 7) return '${days}d ago';
  if (days < 30) return '${(days / 7).floor()}w ago';
  if (days < 365) return '${(days / 30).floor()}mo ago';
  return '${(days / 365).floor()}y ago';
}

IconData _iconFor(RediscoverJourneyKind kind) => switch (kind) {
  RediscoverJourneyKind.returningTopic => Icons.history_toggle_off_rounded,
  RediscoverJourneyKind.onThisDay => Icons.history_rounded,
  RediscoverJourneyKind.forgottenGems => Icons.diamond_outlined,
  RediscoverJourneyKind.continueLearning => Icons.playlist_play_rounded,
  _ => Icons.auto_awesome_mosaic_outlined,
};

String rediscoverDateKey(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

String _topicKey(RediscoverJourney journey) {
  return (journey.stableTopicKey ?? journey.topicAnchor ?? journey.title)
      .trim();
}

String _normalizeTopic(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

bool _sameMemoryOrder(
  List<RediscoverMemory> first,
  List<RediscoverMemory> second,
) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index].id != second[index].id) return false;
  }
  return true;
}

class _DailyCandidate {
  const _DailyCandidate({
    required this.journey,
    required this.explicitPriority,
    required this.score,
  });

  final RediscoverJourney journey;
  final int explicitPriority;
  final double score;
}
