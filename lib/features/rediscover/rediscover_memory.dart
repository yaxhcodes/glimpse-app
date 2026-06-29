import '../../core/models/saved_url.dart';
import '../../core/services/title_resolver.dart';
import 'rediscover_journey_provider.dart';

class RediscoverMemory {
  const RediscoverMemory({
    required this.journey,
    required this.identity,
    required this.whyNow,
    required this.actionLabel,
    required this.primaryUrl,
    required this.primaryTitle,
    required this.saveCount,
    required this.unopenedCount,
    required this.notificationTitle,
    required this.notificationBody,
  });

  final RediscoverJourney journey;
  final String identity;
  final String whyNow;
  final String actionLabel;
  final SavedUrl? primaryUrl;
  final String? primaryTitle;
  final int saveCount;
  final int unopenedCount;
  final String notificationTitle;
  final String notificationBody;

  String get topicKey => journey.topicAnchor ?? journey.title;

  String get waitingLabel => unopenedCount == 0 ? 'ready' : '$unopenedCount waiting';

  static RediscoverMemory fromJourney(
    RediscoverJourney journey, {
    Map<String, int> tagFrequency = const {},
  }) {
    final primaryUrl = journey.items.isEmpty ? null : journey.items.first.url;
    final primaryTitle = primaryUrl == null
        ? null
        : TitleResolver.resolveDetailTitle(
            primaryUrl,
            tagFrequency: tagFrequency,
          );
    final saveCount = journey.items.length;
    final unopenedCount =
        journey.items.where((item) => item.url.openedAt == null).length;
    final identity = _identityFor(journey);
    final whyNow = _whyNowFor(journey);

    return RediscoverMemory(
      journey: journey,
      identity: identity,
      whyNow: whyNow,
      actionLabel: _actionFor(journey),
      primaryUrl: primaryUrl,
      primaryTitle: primaryTitle,
      saveCount: saveCount,
      unopenedCount: unopenedCount,
      notificationTitle: _notificationTitleFor(journey, identity),
      notificationBody: _notificationBodyFor(journey, unopenedCount),
    );
  }

  static String _identityFor(RediscoverJourney journey) {
    final topic = _topicTitle(journey.topicAnchor ?? journey.title);
    return switch (journey.kind) {
      RediscoverJourneyKind.continueLearning => '$topic thread',
      RediscoverJourneyKind.forgottenGems => '$topic waiting for you',
      RediscoverJourneyKind.onThisDay => 'A remembered $topic thread',
      RediscoverJourneyKind.memoryGoal => '$topic goal',
      RediscoverJourneyKind.neverOpened => '$topic you saved for later',
      RediscoverJourneyKind.becauseYouSaved => '$topic curiosity',
    };
  }

  static String _whyNowFor(RediscoverJourney journey) {
    return switch (journey.kind) {
      RediscoverJourneyKind.continueLearning =>
        'This thread is still warm from what you saved recently.',
      RediscoverJourneyKind.forgottenGems =>
        'These waited long enough to be useful again.',
      RediscoverJourneyKind.onThisDay =>
        'You saved these around this point in an earlier cycle.',
      RediscoverJourneyKind.memoryGoal =>
        'This points back to a goal you have been quietly building.',
      RediscoverJourneyKind.neverOpened =>
        'You saved these for later and never gave them a first look.',
      RediscoverJourneyKind.becauseYouSaved =>
        'This connects to patterns in what you keep saving.',
    };
  }

  static String _actionFor(RediscoverJourney journey) {
    return switch (journey.kind) {
      RediscoverJourneyKind.continueLearning => 'Continue the thread',
      RediscoverJourneyKind.forgottenGems => 'Reopen the best one',
      RediscoverJourneyKind.onThisDay => 'Look back',
      RediscoverJourneyKind.memoryGoal => 'Pick up the goal',
      RediscoverJourneyKind.neverOpened => 'Start with one',
      RediscoverJourneyKind.becauseYouSaved => 'Explore the thread',
    };
  }

  static String _notificationTitleFor(
    RediscoverJourney journey,
    String identity,
  ) {
    return switch (journey.kind) {
      RediscoverJourneyKind.continueLearning => 'Your $identity is still warm',
      RediscoverJourneyKind.forgottenGems => 'You set this aside for later',
      RediscoverJourneyKind.onThisDay => 'This came back around',
      RediscoverJourneyKind.memoryGoal => 'A quiet goal is ready again',
      RediscoverJourneyKind.neverOpened => 'Your future self left this here',
      RediscoverJourneyKind.becauseYouSaved => 'This matches what you keep saving',
    };
  }

  static String _notificationBodyFor(
    RediscoverJourney journey,
    int unopenedCount,
  ) {
    final count = unopenedCount == 0 ? journey.items.length : unopenedCount;
    return switch (journey.kind) {
      RediscoverJourneyKind.continueLearning =>
        '$count saves still belong to the same thread.',
      RediscoverJourneyKind.forgottenGems =>
        '$count saved pieces are worth a fresh look.',
      RediscoverJourneyKind.onThisDay =>
        'A thread from before is relevant again.',
      RediscoverJourneyKind.memoryGoal =>
        'Start with the most practical saved piece.',
      RediscoverJourneyKind.neverOpened =>
        '$count saves are still waiting for a first look.',
      RediscoverJourneyKind.becauseYouSaved =>
        'Glimpse found the pattern behind them.',
    };
  }

  static String _topicTitle(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+|_+'))
        .where((word) => word.isNotEmpty);
    return words.map((word) {
      final lower = word.toLowerCase();
      const upper = {'ai', 'api', 'ui', 'ux', 'seo', 'saas'};
      const lowerCase = {'and', 'or', 'for', 'to', 'of', 'in', 'on'};
      if (upper.contains(lower)) return lower.toUpperCase();
      if (lowerCase.contains(lower)) return lower;
      if (lower.length <= 3) return lower.toUpperCase();
      return '${lower[0].toUpperCase()}${lower.substring(1)}';
    }).join(' ');
  }
}
