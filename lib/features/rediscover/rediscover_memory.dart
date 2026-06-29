import '../../core/models/saved_url.dart';
import '../../core/services/title_resolver.dart';
import 'rediscover_journey_provider.dart';

enum RediscoverMemoryEmotion {
  recognition,
  momentum,
  nostalgia,
  relief,
  intention,
  curiosity,
}

class RediscoverMemoryCopy {
  const RediscoverMemoryCopy({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.actionLabel,
  });

  final String title;
  final String subtitle;
  final String body;
  final String actionLabel;
}

class RediscoverNotificationCopy {
  const RediscoverNotificationCopy({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

class RediscoverJourneyMetadata {
  const RediscoverJourneyMetadata({
    required this.kind,
    required this.topicKey,
    required this.topicLabel,
    required this.signal,
    required this.saveCount,
    required this.unopenedCount,
    required this.openedCount,
    required this.hasQueuedSaves,
    required this.primaryUrlIds,
    required this.supportingUrlIds,
    required this.oldestSavedAt,
    required this.newestSavedAt,
  });

  final RediscoverJourneyKind kind;
  final String topicKey;
  final String topicLabel;
  final double signal;
  final int saveCount;
  final int unopenedCount;
  final int openedCount;
  final bool hasQueuedSaves;
  final List<int> primaryUrlIds;
  final List<int> supportingUrlIds;
  final DateTime? oldestSavedAt;
  final DateTime? newestSavedAt;
}

class RediscoverMemory {
  const RediscoverMemory({
    required this.journey,
    required this.id,
    required this.topicKey,
    required this.topicLabel,
    required this.what,
    required this.whyItMatters,
    required this.whyNow,
    required this.emotion,
    required this.encouragedAction,
    required this.homeCopy,
    required this.rediscoverCopy,
    required this.notificationCopy,
    required this.metadata,
    required this.primaryUrl,
    required this.primaryTitle,
    required this.supportingUrls,
    required this.saveCount,
    required this.unopenedCount,
  });

  final RediscoverJourney journey;
  final String id;
  final String topicKey;
  final String topicLabel;
  final String what;
  final String whyItMatters;
  final String whyNow;
  final RediscoverMemoryEmotion emotion;
  final String encouragedAction;
  final RediscoverMemoryCopy homeCopy;
  final RediscoverMemoryCopy rediscoverCopy;
  final RediscoverNotificationCopy notificationCopy;
  final RediscoverJourneyMetadata metadata;
  final SavedUrl? primaryUrl;
  final String? primaryTitle;
  final List<SavedUrl> supportingUrls;
  final int saveCount;
  final int unopenedCount;

  String get identity => what;
  String get actionLabel => encouragedAction;
  String get notificationTitle => notificationCopy.title;
  String get notificationBody => notificationCopy.body;

  String get waitingLabel =>
      unopenedCount == 0 ? 'ready' : '$unopenedCount waiting';

  static RediscoverMemory fromJourney(
    RediscoverJourney journey, {
    Map<String, int> tagFrequency = const {},
  }) {
    final primaryUrl = journey.items.isEmpty ? null : journey.items.first.url;
    final supportingUrls = journey.items
        .skip(1)
        .map((item) => item.url)
        .toList();
    final primaryTitle = primaryUrl == null
        ? null
        : TitleResolver.resolveDetailTitle(
            primaryUrl,
            tagFrequency: tagFrequency,
          );
    final saveCount = journey.items.length;
    final unopenedCount =
        journey.items.where((item) => item.url.openedAt == null).length;
    final openedCount = saveCount - unopenedCount;
    final topicKey = (journey.topicAnchor ?? journey.title).trim();
    final topicLabel = _topicTitle(topicKey);
    final what = _identityFor(journey, topicLabel);
    final whyItMatters = _whyItMattersFor(journey, topicLabel);
    final whyNow = _whyNowFor(journey);
    final action = _actionFor(journey);
    final emotion = _emotionFor(journey);
    final metadata = _metadataFor(
      journey,
      topicKey: topicKey,
      topicLabel: topicLabel,
      saveCount: saveCount,
      unopenedCount: unopenedCount,
      openedCount: openedCount,
    );

    return RediscoverMemory(
      journey: journey,
      id: _memoryId(journey, topicKey),
      topicKey: topicKey,
      topicLabel: topicLabel,
      what: what,
      whyItMatters: whyItMatters,
      whyNow: whyNow,
      emotion: emotion,
      encouragedAction: action,
      homeCopy: _homeCopyFor(
        journey,
        title: what,
        whyNow: whyNow,
        action: action,
      ),
      rediscoverCopy: _rediscoverCopyFor(
        journey,
        title: what,
        whyItMatters: whyItMatters,
        whyNow: whyNow,
        action: action,
        primaryTitle: primaryTitle,
      ),
      notificationCopy: _notificationCopyFor(
        journey,
        title: what,
        unopenedCount: unopenedCount,
      ),
      metadata: metadata,
      primaryUrl: primaryUrl,
      primaryTitle: primaryTitle,
      supportingUrls: supportingUrls,
      saveCount: saveCount,
      unopenedCount: unopenedCount,
    );
  }

  static String _identityFor(RediscoverJourney journey, String topic) {
    return switch (journey.kind) {
      RediscoverJourneyKind.continueLearning => '$topic thread',
      RediscoverJourneyKind.forgottenGems => '$topic waiting for you',
      RediscoverJourneyKind.onThisDay => 'A remembered $topic thread',
      RediscoverJourneyKind.memoryGoal => '$topic goal',
      RediscoverJourneyKind.neverOpened => '$topic you saved for later',
      RediscoverJourneyKind.becauseYouSaved => '$topic curiosity',
    };
  }

  static String _whyItMattersFor(RediscoverJourney journey, String topic) {
    return switch (journey.kind) {
      RediscoverJourneyKind.continueLearning =>
        'You have been building a live thread around $topic.',
      RediscoverJourneyKind.forgottenGems =>
        'You saved enough around $topic that it should not stay buried.',
      RediscoverJourneyKind.onThisDay =>
        'This $topic thread carries context from an earlier moment.',
      RediscoverJourneyKind.memoryGoal =>
        'This $topic cluster points to something you may still want to do.',
      RediscoverJourneyKind.neverOpened =>
        'You saved this $topic thread but never gave it attention.',
      RediscoverJourneyKind.becauseYouSaved =>
        '$topic keeps appearing in what you choose to keep.',
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

  static RediscoverMemoryEmotion _emotionFor(RediscoverJourney journey) {
    return switch (journey.kind) {
      RediscoverJourneyKind.continueLearning => RediscoverMemoryEmotion.momentum,
      RediscoverJourneyKind.forgottenGems => RediscoverMemoryEmotion.recognition,
      RediscoverJourneyKind.onThisDay => RediscoverMemoryEmotion.nostalgia,
      RediscoverJourneyKind.memoryGoal => RediscoverMemoryEmotion.intention,
      RediscoverJourneyKind.neverOpened => RediscoverMemoryEmotion.relief,
      RediscoverJourneyKind.becauseYouSaved => RediscoverMemoryEmotion.curiosity,
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

  static RediscoverMemoryCopy _homeCopyFor(
    RediscoverJourney journey, {
    required String title,
    required String whyNow,
    required String action,
  }) {
    return RediscoverMemoryCopy(
      title: title,
      subtitle: journey.subtitle,
      body: whyNow,
      actionLabel: action,
    );
  }

  static RediscoverMemoryCopy _rediscoverCopyFor(
    RediscoverJourney journey, {
    required String title,
    required String whyItMatters,
    required String whyNow,
    required String action,
    required String? primaryTitle,
  }) {
    final startLine =
        primaryTitle == null ? whyItMatters : '$action: $primaryTitle';
    return RediscoverMemoryCopy(
      title: title,
      subtitle: journey.subtitle,
      body: '$whyNow $whyItMatters',
      actionLabel: startLine,
    );
  }

  static RediscoverNotificationCopy _notificationCopyFor(
    RediscoverJourney journey, {
    required String title,
    required int unopenedCount,
  }) {
    return RediscoverNotificationCopy(
      title: _notificationTitleFor(journey, title),
      body: _notificationBodyFor(journey, unopenedCount),
    );
  }

  static String _notificationTitleFor(
    RediscoverJourney journey,
    String title,
  ) {
    return switch (journey.kind) {
      RediscoverJourneyKind.continueLearning => 'Your $title is still warm',
      RediscoverJourneyKind.forgottenGems => 'You set $title aside',
      RediscoverJourneyKind.onThisDay => 'This came back around',
      RediscoverJourneyKind.memoryGoal => 'A quiet goal is ready again',
      RediscoverJourneyKind.neverOpened => 'Your future self left this here',
      RediscoverJourneyKind.becauseYouSaved =>
        'This matches what you keep saving',
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

  static RediscoverJourneyMetadata _metadataFor(
    RediscoverJourney journey, {
    required String topicKey,
    required String topicLabel,
    required int saveCount,
    required int unopenedCount,
    required int openedCount,
  }) {
    final urls = journey.items.map((item) => item.url).toList();
    final dates = urls.map((url) => url.savedAt).toList()
      ..sort((a, b) => a.compareTo(b));
    return RediscoverJourneyMetadata(
      kind: journey.kind,
      topicKey: topicKey,
      topicLabel: topicLabel,
      signal: journey.signal,
      saveCount: saveCount,
      unopenedCount: unopenedCount,
      openedCount: openedCount,
      hasQueuedSaves: urls.any((url) => url.isQueued),
      primaryUrlIds: urls.take(1).map((url) => url.id).toList(),
      supportingUrlIds: urls.skip(1).map((url) => url.id).toList(),
      oldestSavedAt: dates.isEmpty ? null : dates.first,
      newestSavedAt: dates.isEmpty ? null : dates.last,
    );
  }

  static String _memoryId(RediscoverJourney journey, String topicKey) {
    final ids = journey.items.map((item) => item.url.id).toList()..sort();
    return [
      journey.kind.name,
      topicKey.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
      ids.take(4).join('-'),
    ].where((part) => part.isNotEmpty).join(':');
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
