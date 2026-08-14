import 'rediscover_journey_provider.dart';
import 'rediscover_memory.dart';

class RediscoverNotificationReason {
  const RediscoverNotificationReason({
    required this.code,
    required this.label,
    required this.points,
  });

  final String code;
  final String label;
  final double points;

  Map<String, Object> toJson() => {
    'code': code,
    'label': label,
    'points': points,
  };
}

class RediscoverNotificationCandidate {
  const RediscoverNotificationCandidate({
    required this.memory,
    required this.score,
    required this.reasons,
  });

  static const threshold = 58.0;

  final RediscoverMemory memory;
  final double score;
  final List<RediscoverNotificationReason> reasons;

  bool get shouldNotify => score >= threshold;

  List<Map<String, Object>> get explanation =>
      reasons.map((reason) => reason.toJson()).toList();

  static RediscoverNotificationCandidate scoreMemory(
    RediscoverMemory memory, {
    required DateTime now,
    bool recentlyNotified = false,
    DateTime? lastNotificationAt,
  }) {
    final reasons = <RediscoverNotificationReason>[];

    void add(String code, String label, double points) {
      if (points == 0) return;
      reasons.add(
        RediscoverNotificationReason(code: code, label: label, points: points),
      );
    }

    final metadata = memory.metadata;
    final ageDays = metadata.oldestSavedAt == null
        ? 0
        : now.difference(metadata.oldestSavedAt!).inDays;

    add(
      'rediscover_signal',
      'strong Rediscover memory',
      (metadata.signal * 0.18).clamp(0, 18).toDouble(),
    );

    if (metadata.hasQueuedSaves) {
      add('explicit_revisit', 'explicit revisit requested', 34);
    }

    if (ageDays >= 21) {
      add('long_unopened', 'unopened for $ageDays days', 18);
    } else if (ageDays >= 10) {
      add('aging_memory', 'waiting for $ageDays days', 9);
    }

    if (metadata.unopenedCount >= 3) {
      add('unopened_depth', '${metadata.unopenedCount} unopened saves', 10);
    } else if (metadata.unopenedCount > 0) {
      add('has_unopened', 'has unopened saves', 5);
    }

    switch (metadata.kind) {
      case RediscoverJourneyKind.returningTopic:
        add('topic_return', 'recent save reactivated an older topic', 12);
        break;
      case RediscoverJourneyKind.continueLearning:
        add('topic_momentum', 'high engagement topic', 12);
        break;
      case RediscoverJourneyKind.forgottenGems:
        add('forgotten_gem', 'forgotten memory worth resurfacing', 14);
        break;
      case RediscoverJourneyKind.onThisDay:
        add('seasonal_relevance', 'seasonal relevance', 12);
        break;
      case RediscoverJourneyKind.memoryGoal:
        add('goal_relevance', 'goal-related memory', 16);
        break;
      case RediscoverJourneyKind.neverOpened:
        add('first_look', 'saved for later but never opened', 10);
        break;
      case RediscoverJourneyKind.becauseYouSaved:
        add('pattern_match', 'matches repeated saving pattern', 8);
        break;
    }

    final hour = now.hour;
    final topic = memory.topicKey.toLowerCase();
    if (_looksCookingRelated(topic) && hour >= 16 && hour <= 21) {
      add('cooking_evening', 'cooking-related evening context', 10);
    }
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      add('weekend_timing', 'weekend timing', 5);
    }

    if (metadata.saveCount > 6 && !metadata.hasQueuedSaves) {
      add('interruption_cost', 'large memory is better opened in-app', -8);
    }
    if (metadata.unopenedCount == 0) {
      add('low_actionability', 'nothing waiting for action', -18);
    }
    if (recentlyNotified) {
      add('recent_repeat', 'same memory notified recently', -100);
    }
    if (lastNotificationAt != null) {
      final hoursSince = now.difference(lastNotificationAt).inHours;
      if (hoursSince < 36) {
        add('notification_fatigue', 'recent notification fatigue', -18);
      }
    }

    final score = reasons.fold<double>(0, (sum, reason) => sum + reason.points);
    return RediscoverNotificationCandidate(
      memory: memory,
      score: score,
      reasons: reasons,
    );
  }

  static bool _looksCookingRelated(String topic) {
    return topic.contains('cook') ||
        topic.contains('recipe') ||
        topic.contains('food') ||
        topic.contains('meal') ||
        topic.contains('breakfast') ||
        topic.contains('dinner');
  }
}
