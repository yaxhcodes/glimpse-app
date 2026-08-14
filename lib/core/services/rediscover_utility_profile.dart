import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/engagement_event.dart';

class RediscoverTopicUtility {
  const RediscoverTopicUtility({
    required this.topicKey,
    this.saveCount = 0,
    this.topicReturnCount = 0,
    this.distinctImpressionDays = 0,
    this.memoryOpenCount = 0,
    this.contentOpenCount = 0,
    this.queuedCount = 0,
    this.completedCount = 0,
    this.noteCount = 0,
    this.collectionAddCount = 0,
    this.snoozeCount = 0,
    this.lessLikeThisCount = 0,
    this.recentPositive = 0,
    this.recentNegative = 0,
    this.recentEvidence = 0,
    this.firstSavedAt,
    this.lastSavedAt,
    this.firstShownAt,
    this.lastShownAt,
    this.lastShownDate,
    this.firstOpenedAt,
    this.lastOpenedAt,
    this.lastActedAt,
    this.recentUpdatedAt,
  });

  final String topicKey;
  final int saveCount;
  final int topicReturnCount;
  final int distinctImpressionDays;
  final int memoryOpenCount;
  final int contentOpenCount;
  final int queuedCount;
  final int completedCount;
  final int noteCount;
  final int collectionAddCount;
  final int snoozeCount;
  final int lessLikeThisCount;
  final double recentPositive;
  final double recentNegative;
  final double recentEvidence;
  final DateTime? firstSavedAt;
  final DateTime? lastSavedAt;
  final DateTime? firstShownAt;
  final DateTime? lastShownAt;
  final String? lastShownDate;
  final DateTime? firstOpenedAt;
  final DateTime? lastOpenedAt;
  final DateTime? lastActedAt;
  final DateTime? recentUpdatedAt;

  int get attributedOutcomeCount =>
      memoryOpenCount +
      contentOpenCount +
      queuedCount +
      completedCount +
      noteCount +
      collectionAddCount +
      snoozeCount +
      lessLikeThisCount;

  double utilityMultiplier({DateTime? now}) {
    if (attributedOutcomeCount < 5) return 1;
    final at = now ?? DateTime.now();
    final decayed = _decayed(at);
    final denominator = decayed.$1 + decayed.$2 + 4;
    final smoothedRate = (decayed.$1 + 2) / denominator;
    var multiplier = 0.75 + (smoothedRate * 0.5);
    if (distinctImpressionDays >= 3 && contentOpenCount == 0) {
      multiplier -= min(0.08, (distinctImpressionDays - 2) * 0.02);
    }
    return multiplier.clamp(0.75, 1.25);
  }

  double get fatigueMultiplier {
    final ignoredDays =
        distinctImpressionDays -
        min(distinctImpressionDays, memoryOpenCount + snoozeCount);
    if (ignoredDays < 3) return 1;
    return (1 - ((ignoredDays - 2) * 0.02)).clamp(0.9, 1);
  }

  RediscoverTopicUtility record(EngagementEvent event) {
    final now = event.at;
    final date = _dateKey(now);
    final decayed = _decayed(now);
    final confidence = _confidenceWeight(event);
    var positive = decayed.$1;
    var negative = decayed.$2;
    var evidence = decayed.$3;

    var topicReturns = topicReturnCount;
    var impressionDays = distinctImpressionDays;
    var memoryOpens = memoryOpenCount;
    var contentOpens = contentOpenCount;
    var queued = queuedCount;
    var completed = completedCount;
    var notes = noteCount;
    var collections = collectionAddCount;
    var snoozes = snoozeCount;
    var lessLike = lessLikeThisCount;
    DateTime? shownFirst = firstShownAt;
    DateTime? shownLast = lastShownAt;
    var shownDate = lastShownDate;
    DateTime? openedFirst = firstOpenedAt;
    DateTime? openedLast = lastOpenedAt;
    DateTime? actedLast = lastActedAt;

    switch (event.type) {
      case EngagementEventType.cardShown:
        if (shownDate != date) impressionDays++;
        shownDate = date;
        shownFirst ??= now;
        shownLast = now;
      case EngagementEventType.clusterVisit:
        memoryOpens++;
        positive += 0.75 * confidence;
        evidence += confidence;
        openedFirst ??= now;
        openedLast = now;
      case EngagementEventType.cardOpened:
        contentOpens++;
        positive += 3 * confidence;
        evidence += confidence;
        openedFirst ??= now;
        openedLast = now;
        actedLast = now;
      case EngagementEventType.rediscoverQueued:
        queued++;
        positive += 2 * confidence;
        evidence += confidence;
        actedLast = now;
      case EngagementEventType.rediscoverCompleted:
        completed++;
        positive += 5 * confidence;
        evidence += confidence;
        actedLast = now;
      case EngagementEventType.noteAdded:
        notes++;
        positive += 3 * confidence;
        evidence += confidence;
        actedLast = now;
      case EngagementEventType.collectionAdded:
        collections++;
        positive += 3 * confidence;
        evidence += confidence;
        actedLast = now;
      case EngagementEventType.cardSnoozed:
        // "Not now" is composition-specific. Retain the count, but do not
        // turn it into topic dislike.
        snoozes++;
        evidence += confidence;
        actedLast = now;
      case EngagementEventType.cardDismissed:
        lessLike++;
        negative += 4 * confidence;
        evidence += confidence;
        actedLast = now;
      default:
        break;
    }

    return RediscoverTopicUtility(
      topicKey: topicKey,
      saveCount: saveCount,
      topicReturnCount: topicReturns,
      distinctImpressionDays: impressionDays,
      memoryOpenCount: memoryOpens,
      contentOpenCount: contentOpens,
      queuedCount: queued,
      completedCount: completed,
      noteCount: notes,
      collectionAddCount: collections,
      snoozeCount: snoozes,
      lessLikeThisCount: lessLike,
      recentPositive: positive,
      recentNegative: negative,
      recentEvidence: evidence,
      firstSavedAt: firstSavedAt,
      lastSavedAt: lastSavedAt,
      firstShownAt: shownFirst,
      lastShownAt: shownLast,
      lastShownDate: shownDate,
      firstOpenedAt: openedFirst,
      lastOpenedAt: openedLast,
      lastActedAt: actedLast,
      recentUpdatedAt: now,
    );
  }

  RediscoverTopicUtility recordSave(
    DateTime at, {
    required bool isTopicReturn,
  }) {
    return RediscoverTopicUtility(
      topicKey: topicKey,
      saveCount: saveCount + 1,
      topicReturnCount: topicReturnCount + (isTopicReturn ? 1 : 0),
      distinctImpressionDays: distinctImpressionDays,
      memoryOpenCount: memoryOpenCount,
      contentOpenCount: contentOpenCount,
      queuedCount: queuedCount,
      completedCount: completedCount,
      noteCount: noteCount,
      collectionAddCount: collectionAddCount,
      snoozeCount: snoozeCount,
      lessLikeThisCount: lessLikeThisCount,
      recentPositive: recentPositive,
      recentNegative: recentNegative,
      recentEvidence: recentEvidence,
      firstSavedAt: firstSavedAt ?? at,
      lastSavedAt: at,
      firstShownAt: firstShownAt,
      lastShownAt: lastShownAt,
      lastShownDate: lastShownDate,
      firstOpenedAt: firstOpenedAt,
      lastOpenedAt: lastOpenedAt,
      lastActedAt: lastActedAt,
      recentUpdatedAt: recentUpdatedAt,
    );
  }

  (double, double, double) _decayed(DateTime now) {
    final updated = recentUpdatedAt;
    if (updated == null || !now.isAfter(updated)) {
      return (recentPositive, recentNegative, recentEvidence);
    }
    final days = now.difference(updated).inHours / 24;
    final factor = pow(0.5, days / 90).toDouble();
    return (
      recentPositive * factor,
      recentNegative * factor,
      recentEvidence * factor,
    );
  }

  Map<String, dynamic> toJson() => {
    'topicKey': topicKey,
    'saveCount': saveCount,
    'topicReturnCount': topicReturnCount,
    'distinctImpressionDays': distinctImpressionDays,
    'memoryOpenCount': memoryOpenCount,
    'contentOpenCount': contentOpenCount,
    'queuedCount': queuedCount,
    'completedCount': completedCount,
    'noteCount': noteCount,
    'collectionAddCount': collectionAddCount,
    'snoozeCount': snoozeCount,
    'lessLikeThisCount': lessLikeThisCount,
    'recentPositive': recentPositive,
    'recentNegative': recentNegative,
    'recentEvidence': recentEvidence,
    'normalizedUtility': utilityMultiplier(),
    if (firstSavedAt != null) 'firstSavedAt': firstSavedAt!.toIso8601String(),
    if (lastSavedAt != null) 'lastSavedAt': lastSavedAt!.toIso8601String(),
    if (firstShownAt != null) 'firstShownAt': firstShownAt!.toIso8601String(),
    if (lastShownAt != null) 'lastShownAt': lastShownAt!.toIso8601String(),
    if (lastShownDate != null) 'lastShownDate': lastShownDate,
    if (firstOpenedAt != null)
      'firstOpenedAt': firstOpenedAt!.toIso8601String(),
    if (lastOpenedAt != null) 'lastOpenedAt': lastOpenedAt!.toIso8601String(),
    if (lastActedAt != null) 'lastActedAt': lastActedAt!.toIso8601String(),
    if (recentUpdatedAt != null)
      'recentUpdatedAt': recentUpdatedAt!.toIso8601String(),
  };

  static RediscoverTopicUtility? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final topicKey = json['topicKey'];
    if (topicKey is! String || topicKey.trim().isEmpty) return null;
    int count(String key) =>
        (json[key] as num?)?.toInt().clamp(0, 1000000) ?? 0;
    double score(String key) =>
        ((json[key] as num?)?.toDouble() ?? 0).clamp(0, 1000000);
    DateTime? date(String key) => DateTime.tryParse(json[key] as String? ?? '');
    return RediscoverTopicUtility(
      topicKey: topicKey.trim(),
      saveCount: count('saveCount'),
      topicReturnCount: count('topicReturnCount'),
      distinctImpressionDays: count('distinctImpressionDays'),
      memoryOpenCount: count('memoryOpenCount'),
      contentOpenCount: count('contentOpenCount'),
      queuedCount: count('queuedCount'),
      completedCount: count('completedCount'),
      noteCount: count('noteCount'),
      collectionAddCount: count('collectionAddCount'),
      snoozeCount: count('snoozeCount'),
      lessLikeThisCount: count('lessLikeThisCount'),
      recentPositive: score('recentPositive'),
      recentNegative: score('recentNegative'),
      recentEvidence: score('recentEvidence'),
      firstSavedAt: date('firstSavedAt'),
      lastSavedAt: date('lastSavedAt'),
      firstShownAt: date('firstShownAt'),
      lastShownAt: date('lastShownAt'),
      lastShownDate: json['lastShownDate'] as String?,
      firstOpenedAt: date('firstOpenedAt'),
      lastOpenedAt: date('lastOpenedAt'),
      lastActedAt: date('lastActedAt'),
      recentUpdatedAt: date('recentUpdatedAt'),
    );
  }
}

class RediscoverReasonUtility {
  const RediscoverReasonUtility({
    required this.reasonCode,
    this.impressionCount = 0,
    this.outcomeCount = 0,
    this.positiveScore = 0,
    this.negativeScore = 0,
  });

  final String reasonCode;
  final int impressionCount;
  final int outcomeCount;
  final double positiveScore;
  final double negativeScore;

  RediscoverReasonUtility record(EngagementEvent event) {
    final weight = _confidenceWeight(event);
    var impressions = impressionCount;
    var outcomes = outcomeCount;
    var positive = positiveScore;
    var negative = negativeScore;
    switch (event.type) {
      case EngagementEventType.cardShown:
        impressions++;
      case EngagementEventType.clusterVisit:
        outcomes++;
        positive += 0.75 * weight;
      case EngagementEventType.cardOpened:
        outcomes++;
        positive += 3 * weight;
      case EngagementEventType.rediscoverQueued:
        outcomes++;
        positive += 2 * weight;
      case EngagementEventType.rediscoverCompleted:
        outcomes++;
        positive += 5 * weight;
      case EngagementEventType.noteAdded:
      case EngagementEventType.collectionAdded:
        outcomes++;
        positive += 3 * weight;
      case EngagementEventType.cardSnoozed:
        outcomes++;
      case EngagementEventType.cardDismissed:
        outcomes++;
        negative += 4 * weight;
      default:
        break;
    }
    return RediscoverReasonUtility(
      reasonCode: reasonCode,
      impressionCount: impressions,
      outcomeCount: outcomes,
      positiveScore: positive,
      negativeScore: negative,
    );
  }

  Map<String, dynamic> toJson() => {
    'reasonCode': reasonCode,
    'impressionCount': impressionCount,
    'outcomeCount': outcomeCount,
    'positiveScore': positiveScore,
    'negativeScore': negativeScore,
  };

  static RediscoverReasonUtility? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final reason = json['reasonCode'];
    if (reason is! String || reason.isEmpty) return null;
    return RediscoverReasonUtility(
      reasonCode: reason,
      impressionCount:
          (json['impressionCount'] as num?)?.toInt().clamp(0, 1000000) ?? 0,
      outcomeCount:
          (json['outcomeCount'] as num?)?.toInt().clamp(0, 1000000) ?? 0,
      positiveScore: ((json['positiveScore'] as num?)?.toDouble() ?? 0).clamp(
        0,
        1000000,
      ),
      negativeScore: ((json['negativeScore'] as num?)?.toDouble() ?? 0).clamp(
        0,
        1000000,
      ),
    );
  }
}

class RediscoverUtilityProfile {
  const RediscoverUtilityProfile({
    required this.originId,
    required this.revision,
    required this.topics,
    this.reasonUtilities = const {},
    this.schemaVersion = currentSchemaVersion,
  });

  static const currentSchemaVersion = 1;
  static const empty = RediscoverUtilityProfile(
    originId: '',
    revision: 0,
    topics: {},
  );

  final int schemaVersion;
  final String originId;
  final int revision;
  final Map<String, RediscoverTopicUtility> topics;
  final Map<String, RediscoverReasonUtility> reasonUtilities;

  double topicMultiplier(String topicKey, {DateTime? now}) =>
      ((topics[topicKey]?.utilityMultiplier(now: now) ?? 1) *
              (topics[topicKey]?.fatigueMultiplier ?? 1))
          .clamp(0.75, 1.25);

  RediscoverUtilityProfile record(EngagementEvent event) {
    final topicKey = event.topicKey?.trim();
    if (topicKey == null || topicKey.isEmpty) return this;
    final current =
        topics[topicKey] ?? RediscoverTopicUtility(topicKey: topicKey);
    final reasonCode = event.reasonCode?.trim();
    final reasons = {...reasonUtilities};
    if (reasonCode != null && reasonCode.isNotEmpty) {
      final reason =
          reasons[reasonCode] ??
          RediscoverReasonUtility(reasonCode: reasonCode);
      reasons[reasonCode] = reason.record(event);
    }
    return RediscoverUtilityProfile(
      originId: originId,
      revision: revision + 1,
      topics: {...topics, topicKey: current.record(event)},
      reasonUtilities: reasons,
    );
  }

  RediscoverUtilityProfile recordTopicSave(
    String topicKey,
    DateTime at, {
    required bool isTopicReturn,
  }) {
    final normalized = topicKey.trim();
    if (normalized.isEmpty) return this;
    final current =
        topics[normalized] ?? RediscoverTopicUtility(topicKey: normalized);
    return RediscoverUtilityProfile(
      originId: originId,
      revision: revision + 1,
      topics: {
        ...topics,
        normalized: current.recordSave(at, isTopicReturn: isTopicReturn),
      },
      reasonUtilities: reasonUtilities,
    );
  }

  Map<String, dynamic> toBackupJson() => {
    'schemaVersion': schemaVersion,
    'originId': originId,
    'revision': revision,
    'topics': topics.values.map((topic) => topic.toJson()).toList(),
    'reasonUtilities': reasonUtilities.values
        .map((reason) => reason.toJson())
        .toList(),
  };

  static RediscoverUtilityProfile? fromBackupJson(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    if (json['schemaVersion'] != currentSchemaVersion) return null;
    final origin = json['originId'];
    final revision = json['revision'];
    final rawTopics = json['topics'];
    if (origin is! String ||
        origin.isEmpty ||
        revision is! num ||
        rawTopics is! List) {
      return null;
    }
    final topics = <String, RediscoverTopicUtility>{};
    for (final rawTopic in rawTopics) {
      final topic = RediscoverTopicUtility.fromJson(rawTopic);
      if (topic != null) topics[topic.topicKey] = topic;
    }
    final reasons = <String, RediscoverReasonUtility>{};
    final rawReasons = json['reasonUtilities'];
    if (rawReasons is List) {
      for (final rawReason in rawReasons) {
        final reason = RediscoverReasonUtility.fromJson(rawReason);
        if (reason != null) reasons[reason.reasonCode] = reason;
      }
    }
    return RediscoverUtilityProfile(
      originId: origin,
      revision: revision.toInt().clamp(0, 1 << 31),
      topics: topics,
      reasonUtilities: reasons,
    );
  }

  static RediscoverUtilityProfile merge(
    RediscoverUtilityProfile current,
    RediscoverUtilityProfile incoming,
  ) {
    if (current.originId == incoming.originId) {
      return incoming.revision > current.revision ? incoming : current;
    }
    final keys = {...current.topics.keys, ...incoming.topics.keys};
    final merged = <String, RediscoverTopicUtility>{};
    for (final key in keys) {
      final a = current.topics[key];
      final b = incoming.topics[key];
      if (a == null) {
        merged[key] = b!;
      } else if (b == null) {
        merged[key] = a;
      } else {
        merged[key] = _mergeTopic(a, b);
      }
    }
    final reasonKeys = {
      ...current.reasonUtilities.keys,
      ...incoming.reasonUtilities.keys,
    };
    final reasons = <String, RediscoverReasonUtility>{};
    for (final key in reasonKeys) {
      final a = current.reasonUtilities[key];
      final b = incoming.reasonUtilities[key];
      reasons[key] = a == null
          ? b!
          : b == null
          ? a
          : RediscoverReasonUtility(
              reasonCode: key,
              impressionCount: a.impressionCount + b.impressionCount,
              outcomeCount: a.outcomeCount + b.outcomeCount,
              positiveScore: a.positiveScore + b.positiveScore,
              negativeScore: a.negativeScore + b.negativeScore,
            );
    }
    return RediscoverUtilityProfile(
      originId: current.originId,
      revision: current.revision + 1,
      topics: merged,
      reasonUtilities: reasons,
    );
  }

  static RediscoverTopicUtility _mergeTopic(
    RediscoverTopicUtility a,
    RediscoverTopicUtility b,
  ) {
    final aWeight = a.attributedOutcomeCount.clamp(1, 50);
    final bWeight = b.attributedOutcomeCount.clamp(1, 50);
    final total = aWeight + bWeight;
    double weighted(double x, double y) => (x * aWeight + y * bWeight) / total;
    int sum(int x, int y) => (x + y).clamp(0, 1000000);
    return RediscoverTopicUtility(
      topicKey: a.topicKey,
      saveCount: sum(a.saveCount, b.saveCount),
      topicReturnCount: sum(a.topicReturnCount, b.topicReturnCount),
      distinctImpressionDays: sum(
        a.distinctImpressionDays,
        b.distinctImpressionDays,
      ),
      memoryOpenCount: sum(a.memoryOpenCount, b.memoryOpenCount),
      contentOpenCount: sum(a.contentOpenCount, b.contentOpenCount),
      queuedCount: sum(a.queuedCount, b.queuedCount),
      completedCount: sum(a.completedCount, b.completedCount),
      noteCount: sum(a.noteCount, b.noteCount),
      collectionAddCount: sum(a.collectionAddCount, b.collectionAddCount),
      snoozeCount: sum(a.snoozeCount, b.snoozeCount),
      lessLikeThisCount: sum(a.lessLikeThisCount, b.lessLikeThisCount),
      recentPositive: weighted(a.recentPositive, b.recentPositive),
      recentNegative: weighted(a.recentNegative, b.recentNegative),
      recentEvidence: weighted(a.recentEvidence, b.recentEvidence),
      firstSavedAt: _earlier(a.firstSavedAt, b.firstSavedAt),
      lastSavedAt: _later(a.lastSavedAt, b.lastSavedAt),
      firstShownAt: _earlier(a.firstShownAt, b.firstShownAt),
      lastShownAt: _later(a.lastShownAt, b.lastShownAt),
      lastShownDate: _later(a.lastShownAt, b.lastShownAt) == a.lastShownAt
          ? a.lastShownDate
          : b.lastShownDate,
      firstOpenedAt: _earlier(a.firstOpenedAt, b.firstOpenedAt),
      lastOpenedAt: _later(a.lastOpenedAt, b.lastOpenedAt),
      lastActedAt: _later(a.lastActedAt, b.lastActedAt),
      recentUpdatedAt: _later(a.recentUpdatedAt, b.recentUpdatedAt),
    );
  }
}

class RediscoverUtilityProfileStore {
  static const prefsKey = 'rediscover_utility_profile_v1';
  static Future<void> _pendingRecord = Future.value();

  static Future<RediscoverUtilityProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(prefsKey);
      if (raw != null) {
        final parsed = RediscoverUtilityProfile.fromBackupJson(jsonDecode(raw));
        if (parsed != null) return parsed;
      }
    } catch (error, stackTrace) {
      // Preferences are best-effort personalization state. Rebuild a neutral
      // profile without blocking the user's library.
      debugPrint(
        'Rediscover profile reset after parse failure: $error\n$stackTrace',
      );
    }
    final created = _newProfile();
    await prefs.setString(prefsKey, jsonEncode(created.toBackupJson()));
    return created;
  }

  static Future<void> save(RediscoverUtilityProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(profile.toBackupJson()));
  }

  static Future<void> record(EngagementEvent event) async {
    if ((event.topicKey ?? '').trim().isEmpty) return;
    _pendingRecord = _pendingRecord.catchError((_) {}).then((_) async {
      final current = await load();
      await save(current.record(event));
    });
    await _pendingRecord;
  }

  static Future<void> recordTopicSave(
    String topicKey, {
    required DateTime at,
    bool isTopicReturn = true,
  }) async {
    _pendingRecord = _pendingRecord.catchError((_) {}).then((_) async {
      final current = await load();
      await save(
        current.recordTopicSave(topicKey, at, isTopicReturn: isTopicReturn),
      );
    });
    await _pendingRecord;
  }

  static Future<void> import(Object? raw, {required bool merge}) async {
    final incoming = RediscoverUtilityProfile.fromBackupJson(raw);
    if (incoming == null) return;
    await _pendingRecord.catchError((_) {});
    if (!merge) {
      await save(incoming);
      return;
    }
    final current = await load();
    await save(RediscoverUtilityProfile.merge(current, incoming));
  }

  static Future<void> clear() async {
    await _pendingRecord.catchError((_) {});
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }

  static RediscoverUtilityProfile _newProfile() {
    final random = Random.secure();
    return RediscoverUtilityProfile(
      originId:
          '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
          '${random.nextInt(1 << 32).toRadixString(36)}',
      revision: 0,
      topics: const {},
    );
  }
}

final rediscoverUtilityProfileProvider =
    FutureProvider<RediscoverUtilityProfile>((ref) {
      return RediscoverUtilityProfileStore.load();
    });

double _confidenceWeight(EngagementEvent event) =>
    switch (event.confidenceTier) {
      'supported' => 0.8,
      _ when event.reasonCode == 'exceptionalGem' => 0.75,
      _ when event.reasonCode == 'seasonalReturn' => 0.85,
      _ => 1,
    };

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

DateTime? _earlier(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isBefore(b) ? a : b;
}

DateTime? _later(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}
