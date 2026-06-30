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

enum RediscoverMemoryPersonality {
  reflective,
  practical,
  curious,
  creative,
  adventurous,
  calm,
  ambitious,
  experimental,
  inspirational,
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

class RediscoverMemoryIdentity {
  const RediscoverMemoryIdentity({
    required this.primary,
    required this.secondaryDescription,
    required this.reasonForToday,
    required this.suggestedNextStep,
  });

  final String primary;
  final String secondaryDescription;
  final String reasonForToday;
  final String suggestedNextStep;
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

enum _MemoryDomain {
  cooking,
  building,
  philosophy,
  travel,
  nature,
  fitness,
  creative,
  learning,
  money,
  watchlist,
  general,
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
    required this.personality,
    required this.copyIdentity,
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
  final RediscoverMemoryPersonality personality;
  final RediscoverMemoryIdentity copyIdentity;
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

  String get identity => copyIdentity.primary;
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
    final emotion = _emotionFor(journey);
    final metadata = _metadataFor(
      journey,
      topicKey: topicKey,
      topicLabel: _topicTitle(topicKey),
      saveCount: saveCount,
      unopenedCount: unopenedCount,
      openedCount: openedCount,
    );
    final topicLabel = metadata.topicLabel;
    final personality = _personalityFor(journey, topicLabel, primaryTitle);
    final copyIdentity = _copyIdentityFor(
      journey,
      topicLabel: topicLabel,
      primaryTitle: primaryTitle,
      saveCount: saveCount,
      unopenedCount: unopenedCount,
      openedCount: openedCount,
      personality: personality,
    );
    final what = copyIdentity.primary;
    final whyItMatters = copyIdentity.secondaryDescription;
    final whyNow = copyIdentity.reasonForToday;
    final action = copyIdentity.suggestedNextStep;

    return RediscoverMemory(
      journey: journey,
      id: _memoryId(journey, topicKey),
      topicKey: topicKey,
      topicLabel: topicLabel,
      what: what,
      whyItMatters: whyItMatters,
      whyNow: whyNow,
      emotion: emotion,
      personality: personality,
      copyIdentity: copyIdentity,
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
        identity: copyIdentity,
        personality: personality,
      ),
      metadata: metadata,
      primaryUrl: primaryUrl,
      primaryTitle: primaryTitle,
      supportingUrls: supportingUrls,
      saveCount: saveCount,
      unopenedCount: unopenedCount,
    );
  }

  static RediscoverMemoryIdentity _copyIdentityFor(
    RediscoverJourney journey, {
    required String topicLabel,
    required String? primaryTitle,
    required int saveCount,
    required int unopenedCount,
    required int openedCount,
    required RediscoverMemoryPersonality personality,
  }) {
    final domain = _domainFor(journey, topicLabel, primaryTitle);
    final title = _primaryIdentityFor(
      journey,
      domain: domain,
      topicLabel: topicLabel,
      primaryTitle: primaryTitle,
      personality: personality,
    );
    return RediscoverMemoryIdentity(
      primary: title,
      secondaryDescription: _secondaryDescriptionFor(
        journey,
        domain: domain,
        topicLabel: topicLabel,
        primaryTitle: primaryTitle,
        saveCount: saveCount,
        unopenedCount: unopenedCount,
      ),
      reasonForToday: _reasonForTodayFor(
        journey,
        openedCount: openedCount,
        unopenedCount: unopenedCount,
      ),
      suggestedNextStep: _suggestedNextStepFor(
        journey,
        domain: domain,
        primaryTitle: primaryTitle,
      ),
    );
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
    required RediscoverMemoryIdentity identity,
    required RediscoverMemoryPersonality personality,
  }) {
    return RediscoverNotificationCopy(
      title: _notificationTitleFor(journey, personality, identity.primary),
      body: identity.reasonForToday,
    );
  }

  static String _notificationTitleFor(
    RediscoverJourney journey,
    RediscoverMemoryPersonality personality,
    String title,
  ) {
    if (journey.kind == RediscoverJourneyKind.onThisDay) {
      return 'This came back around';
    }
    return switch (personality) {
      RediscoverMemoryPersonality.practical => '$title might be useful today',
      RediscoverMemoryPersonality.adventurous => '$title is worth reopening',
      RediscoverMemoryPersonality.ambitious => '$title is still in reach',
      RediscoverMemoryPersonality.experimental => '$title deserves a second look',
      RediscoverMemoryPersonality.reflective => '$title came back for a reason',
      RediscoverMemoryPersonality.creative => '$title is still alive',
      RediscoverMemoryPersonality.inspirational => '$title still has a spark',
      RediscoverMemoryPersonality.calm => '$title is waiting quietly',
      RediscoverMemoryPersonality.curious => '$title still has a question',
    };
  }

  static RediscoverMemoryPersonality _personalityFor(
    RediscoverJourney journey,
    String topicLabel,
    String? primaryTitle,
  ) {
    final domain = _domainFor(journey, topicLabel, primaryTitle);
    if (journey.kind == RediscoverJourneyKind.memoryGoal) {
      return domain == _MemoryDomain.cooking
          ? RediscoverMemoryPersonality.practical
          : RediscoverMemoryPersonality.ambitious;
    }
    if (journey.kind == RediscoverJourneyKind.onThisDay) {
      return RediscoverMemoryPersonality.reflective;
    }
    if (journey.kind == RediscoverJourneyKind.neverOpened) {
      return domain == _MemoryDomain.creative
          ? RediscoverMemoryPersonality.creative
          : RediscoverMemoryPersonality.calm;
    }
    return switch (domain) {
      _MemoryDomain.cooking => RediscoverMemoryPersonality.practical,
      _MemoryDomain.building => RediscoverMemoryPersonality.ambitious,
      _MemoryDomain.philosophy => RediscoverMemoryPersonality.reflective,
      _MemoryDomain.travel => RediscoverMemoryPersonality.adventurous,
      _MemoryDomain.nature => RediscoverMemoryPersonality.calm,
      _MemoryDomain.fitness => RediscoverMemoryPersonality.experimental,
      _MemoryDomain.creative => RediscoverMemoryPersonality.creative,
      _MemoryDomain.learning => RediscoverMemoryPersonality.curious,
      _MemoryDomain.money => RediscoverMemoryPersonality.practical,
      _MemoryDomain.watchlist => RediscoverMemoryPersonality.inspirational,
      _MemoryDomain.general => journey.kind == RediscoverJourneyKind.continueLearning
          ? RediscoverMemoryPersonality.curious
          : RediscoverMemoryPersonality.reflective,
    };
  }

  static _MemoryDomain _domainFor(
    RediscoverJourney journey,
    String topicLabel,
    String? primaryTitle,
  ) {
    final text = [
      topicLabel,
      primaryTitle ?? '',
      journey.title,
      for (final item in journey.items.take(6)) ...[
        item.url.title,
        item.url.description,
        item.url.category,
        item.url.categories.join(' '),
        item.url.tags.join(' '),
      ],
    ].join(' ').toLowerCase();

    if (_containsAny(text, const [
      'recipe',
      'cook',
      'meal',
      'breakfast',
      'dinner',
      'food',
      'kitchen',
    ])) {
      return _MemoryDomain.cooking;
    }
    if (_containsAny(text, const [
      'code',
      'programming',
      'developer',
      'build',
      'app',
      'api',
      'ai',
      'agent',
      'startup',
      'saas',
    ])) {
      return _MemoryDomain.building;
    }
    if (_containsAny(text, const [
      'philosophy',
      'stoic',
      'gita',
      'meaning',
      'wisdom',
      'question',
    ])) {
      return _MemoryDomain.philosophy;
    }
    if (_containsAny(text, const [
      'travel',
      'trip',
      'trek',
      'hike',
      'route',
      'camp',
      'place',
    ])) {
      return _MemoryDomain.travel;
    }
    if (_containsAny(text, const [
      'farm',
      'garden',
      'wildlife',
      'forest',
      'nature',
      'plant',
    ])) {
      return _MemoryDomain.nature;
    }
    if (_containsAny(text, const [
      'fitness',
      'workout',
      'protein',
      'run',
      'strength',
      'health',
    ])) {
      return _MemoryDomain.fitness;
    }
    if (_containsAny(text, const [
      'photo',
      'camera',
      'music',
      'design',
      'write',
      'art',
      'film',
    ])) {
      return _MemoryDomain.creative;
    }
    if (_containsAny(text, const [
      'learn',
      'course',
      'study',
      'tutorial',
      'research',
      'science',
    ])) {
      return _MemoryDomain.learning;
    }
    if (_containsAny(text, const [
      'money',
      'finance',
      'invest',
      'budget',
      'tax',
    ])) {
      return _MemoryDomain.money;
    }
    if (_containsAny(text, const [
      'movie',
      'documentary',
      'series',
      'watch',
      'book',
      'read',
    ])) {
      return _MemoryDomain.watchlist;
    }
    return _MemoryDomain.general;
  }

  static String _primaryIdentityFor(
    RediscoverJourney journey, {
    required _MemoryDomain domain,
    required String topicLabel,
    required String? primaryTitle,
    required RediscoverMemoryPersonality personality,
  }) {
    final titleText = (primaryTitle ?? '').toLowerCase();
    if (domain == _MemoryDomain.cooking && titleText.contains('breakfast')) {
      return 'A Better Breakfast';
    }
    if (domain == _MemoryDomain.cooking && titleText.contains('dinner')) {
      return 'Dinner You Already Planned';
    }

    final bank = switch (domain) {
      _MemoryDomain.cooking => _cookingTitles(journey.kind),
      _MemoryDomain.building => _buildingTitles(journey.kind),
      _MemoryDomain.philosophy => _philosophyTitles(journey.kind),
      _MemoryDomain.travel => _travelTitles(journey.kind),
      _MemoryDomain.nature => _natureTitles(journey.kind),
      _MemoryDomain.fitness => _fitnessTitles(journey.kind),
      _MemoryDomain.creative => _creativeTitles(journey.kind),
      _MemoryDomain.learning => _learningTitles(journey.kind),
      _MemoryDomain.money => _moneyTitles(journey.kind),
      _MemoryDomain.watchlist => _watchlistTitles(journey.kind),
      _MemoryDomain.general => _generalTitles(journey.kind, personality),
    };
    return _pick(bank, journey, topicLabel);
  }

  static String _secondaryDescriptionFor(
    RediscoverJourney journey, {
    required _MemoryDomain domain,
    required String topicLabel,
    required String? primaryTitle,
    required int saveCount,
    required int unopenedCount,
  }) {
    final count = _countWord(saveCount);
    final noun = _domainNoun(domain, plural: saveCount != 1);
    final first = primaryTitle == null ? '' : ' Start with $primaryTitle.';
    if (unopenedCount == saveCount) {
      return '$count saved $noun you have not opened yet.$first';
    }
    if (unopenedCount > 0) {
      return '$count saved $noun, $unopenedCount still waiting.$first';
    }
    return '$count saved $noun around ${topicLabel.toLowerCase()}.$first';
  }

  static String _reasonForTodayFor(
    RediscoverJourney journey, {
    required int openedCount,
    required int unopenedCount,
  }) {
    return switch (journey.kind) {
      RediscoverJourneyKind.continueLearning =>
        'You have been adding to this recently, so the thread still has momentum.',
      RediscoverJourneyKind.forgottenGems =>
        'You saved these with intent, then let them fall out of view.',
      RediscoverJourneyKind.onThisDay =>
        'This belongs to an earlier season of what mattered to you.',
      RediscoverJourneyKind.memoryGoal =>
        'Several saves point toward the same thing you may still want to do.',
      RediscoverJourneyKind.neverOpened =>
        unopenedCount <= 1
            ? 'This is still waiting for its first real look.'
            : 'These are still waiting for a first real look.',
      RediscoverJourneyKind.becauseYouSaved =>
        openedCount > 0
            ? 'You returned to part of this already; the rest still connects.'
            : 'The pattern is clear enough to be worth bringing back.',
    };
  }

  static String _suggestedNextStepFor(
    RediscoverJourney journey, {
    required _MemoryDomain domain,
    required String? primaryTitle,
  }) {
    if (primaryTitle != null && primaryTitle.trim().isNotEmpty) {
      return switch (domain) {
        _MemoryDomain.cooking => 'Cook from $primaryTitle',
        _MemoryDomain.building => 'Open $primaryTitle first',
        _MemoryDomain.travel => 'Recheck $primaryTitle',
        _MemoryDomain.watchlist => 'Start with $primaryTitle',
        _ => 'Start with $primaryTitle',
      };
    }
    return switch (journey.kind) {
      RediscoverJourneyKind.continueLearning => 'Continue where you left off',
      RediscoverJourneyKind.forgottenGems => 'Reopen the strongest save',
      RediscoverJourneyKind.onThisDay => 'Look back for a minute',
      RediscoverJourneyKind.memoryGoal => 'Choose the most practical next step',
      RediscoverJourneyKind.neverOpened => 'Open one saved piece',
      RediscoverJourneyKind.becauseYouSaved => 'Follow the connection',
    };
  }

  static List<String> _cookingTitles(RediscoverJourneyKind kind) => switch (kind) {
        RediscoverJourneyKind.continueLearning => const [
            'The Meal Plan Taking Shape',
            'Still Working Out Dinner',
            'The Kitchen Thread Continues',
          ],
        RediscoverJourneyKind.forgottenGems => const [
            'The Recipes You Nearly Tried',
            'What You Meant to Cook',
            'A Small Dinner Rescue',
          ],
        RediscoverJourneyKind.neverOpened => const [
            'The Unopened Recipe Stack',
            'Meals Still on the Shelf',
            'The First Recipe to Try',
          ],
        RediscoverJourneyKind.memoryGoal => const [
            'A More Useful Kitchen',
            'The Cooking Goal Is Still There',
            'A Practical Meal Plan',
          ],
        RediscoverJourneyKind.onThisDay => const [
            'A Recipe From Before',
            'An Old Kitchen Note',
            'The Meal Idea Came Back',
          ],
        RediscoverJourneyKind.becauseYouSaved => const [
            'The Flavor Pattern',
            'A Weeknight Idea',
            'The Food Thread You Started',
          ],
      };

  static List<String> _buildingTitles(RediscoverJourneyKind kind) => switch (kind) {
        RediscoverJourneyKind.continueLearning => const [
            'The Project Is Still Open',
            'Your Build Notes Are Still Here',
            'The Workbench Is Ready',
          ],
        RediscoverJourneyKind.forgottenGems => const [
            'The Project You Kept Preparing For',
            'An Unfinished Build Trail',
            'The Idea You Parked',
          ],
        RediscoverJourneyKind.neverOpened => const [
            'Tools You Never Tested',
            'The First Build Step',
            'A Saved Shortcut',
          ],
        RediscoverJourneyKind.memoryGoal => const [
            'The Thing You Wanted to Make',
            'A Build Goal With Receipts',
            'The Plan Is Still Usable',
          ],
        RediscoverJourneyKind.onThisDay => const [
            'An Earlier Build Note',
            'A Project From Another Week',
            'The Old Prototype Thread',
          ],
        RediscoverJourneyKind.becauseYouSaved => const [
            'A Pattern in What You Build',
            'The Stack You Were Studying',
            'The Tools Keep Reappearing',
          ],
      };

  static List<String> _philosophyTitles(RediscoverJourneyKind kind) =>
      switch (kind) {
        RediscoverJourneyKind.continueLearning => const [
            'The Question Is Still Open',
            'A Thought You Kept Following',
            'The Same Idea Keeps Returning',
          ],
        RediscoverJourneyKind.forgottenGems => const [
            'The Questions You Put Down',
            'A Thought Worth Picking Up',
            'The Note That Still Asks Something',
          ],
        RediscoverJourneyKind.neverOpened => const [
            'Unread Questions',
            'A First Look at the Idea',
            'The Essay Waiting Quietly',
          ],
        RediscoverJourneyKind.memoryGoal => const [
            'A Practice You Meant to Keep',
            'The Reflection Habit',
            'A Quieter Goal',
          ],
        RediscoverJourneyKind.onThisDay => const [
            'A Question From Before',
            'An Older Thought Returned',
            'Something You Were Wrestling With',
          ],
        RediscoverJourneyKind.becauseYouSaved => const [
            'The Questions You Kept Collecting',
            'A Line of Thought',
            'The Idea Trail',
          ],
      };

  static List<String> _travelTitles(RediscoverJourneyKind kind) => switch (kind) {
        RediscoverJourneyKind.continueLearning => const [
            'The Trip Is Taking Shape',
            'The Route Keeps Growing',
            'Planning Another Way Out',
          ],
        RediscoverJourneyKind.forgottenGems => const [
            'The Trip You Started Sketching',
            'A Route You Left Behind',
            'The Place You Meant to Revisit',
          ],
        RediscoverJourneyKind.neverOpened => const [
            'The First Stop Is Still There',
            'Places You Never Checked',
            'The Unopened Route',
          ],
        RediscoverJourneyKind.memoryGoal => const [
            'A Trip That Still Makes Sense',
            'The Plan Is Still Possible',
            'A Map You Already Started',
          ],
        RediscoverJourneyKind.onThisDay => const [
            'A Place From Before',
            'An Older Route Returned',
            'The Travel Note Came Back',
          ],
        RediscoverJourneyKind.becauseYouSaved => const [
            'The Places Keep Lining Up',
            'A Small Escape Plan',
            'The Map in Your Saves',
          ],
      };

  static List<String> _natureTitles(RediscoverJourneyKind kind) => switch (kind) {
        RediscoverJourneyKind.continueLearning => const [
            'The Green Notebook Grows',
            'Still Learning the Land',
            'The Living Thread Continues',
          ],
        RediscoverJourneyKind.forgottenGems => const [
            'The Nature Notes You Forgot',
            'A Quieter Kind of Research',
            'The Field Notes Are Still Here',
          ],
        _ => const [
            'The Living Things Notebook',
            'A Small Return to Nature',
            'The Outdoor Thread',
          ],
      };

  static List<String> _fitnessTitles(RediscoverJourneyKind kind) => switch (kind) {
        RediscoverJourneyKind.memoryGoal => const [
            'The Routine You Were Testing',
            'A Health Plan With Evidence',
            'The Stronger Week',
          ],
        RediscoverJourneyKind.forgottenGems => const [
            'The Routine You Put Aside',
            'A Useful Reset',
            'The Health Notes Waiting',
          ],
        _ => const [
            'A Better Baseline',
            'The Experiment With Energy',
            'The Training Thread',
          ],
      };

  static List<String> _creativeTitles(RediscoverJourneyKind kind) => switch (kind) {
        RediscoverJourneyKind.continueLearning => const [
            'The Idea Still Has Shape',
            'The Creative Thread Continues',
            'Something You Could Make',
          ],
        RediscoverJourneyKind.forgottenGems => const [
            'The Idea You Almost Used',
            'A Draft Still Waiting',
            'The Reference Stack',
          ],
        _ => const [
            'A Spark You Saved',
            'The Moodboard Has a Point',
            'The Thing You Might Make',
          ],
      };

  static List<String> _learningTitles(RediscoverJourneyKind kind) => switch (kind) {
        RediscoverJourneyKind.continueLearning => const [
            'The Lesson Continues',
            'You Were Building Context',
            'The Study Trail Is Warm',
          ],
        RediscoverJourneyKind.forgottenGems => const [
            'The Lesson You Parked',
            'A Useful Explainer Returned',
            'The Research Stack',
          ],
        _ => const [
            'The Thing You Wanted to Understand',
            'A Thread Worth Finishing',
            'The Learning Curve',
          ],
      };

  static List<String> _moneyTitles(RediscoverJourneyKind kind) => switch (kind) {
        RediscoverJourneyKind.memoryGoal => const [
            'A More Boring Money Plan',
            'The Practical Finance Stack',
            'A Decision You Were Preparing For',
          ],
        _ => const [
            'The Money Notes You Saved',
            'A Practical Check-In',
            'The Decision File',
          ],
      };

  static List<String> _watchlistTitles(RediscoverJourneyKind kind) => switch (kind) {
        RediscoverJourneyKind.forgottenGems => const [
            'The Watchlist With a Reason',
            'What You Meant to Watch',
            'A Story You Saved for Later',
          ],
        RediscoverJourneyKind.onThisDay => const [
            'An Old Watchlist Note',
            'Something You Once Wanted to See',
            'The Story Came Back',
          ],
        _ => const [
            'The Next Thing to Watch',
            'A Queue With Taste',
            'The Story Thread',
          ],
      };

  static List<String> _generalTitles(
    RediscoverJourneyKind kind,
    RediscoverMemoryPersonality personality,
  ) {
    if (personality == RediscoverMemoryPersonality.calm) {
      return const [
        'A Quiet Save Worth Opening',
        'The Thing You Left for Later',
        'A Small Return',
      ];
    }
    return switch (kind) {
      RediscoverJourneyKind.continueLearning => const [
          'The Thread You Were Building',
          'This Was Becoming Something',
          'The Next Piece Is Still There',
        ],
      RediscoverJourneyKind.forgottenGems => const [
          'You Were Onto Something Here',
          'The Thing You Meant to Revisit',
          'A Save With Some Weight',
        ],
      RediscoverJourneyKind.onThisDay => const [
          'Something From Before',
          'An Older Interest Returned',
          'The Past Version of This',
        ],
      RediscoverJourneyKind.memoryGoal => const [
          'A Goal Hiding in Plain Sight',
          'The Plan Beneath the Saves',
          'A Next Step You Already Collected',
        ],
      RediscoverJourneyKind.neverOpened => const [
          'The First Look Is Still Missing',
          'Saved, But Never Started',
          'One Worth Opening First',
        ],
      RediscoverJourneyKind.becauseYouSaved => const [
          'There Is a Pattern Here',
          'This Keeps Showing Up',
          'The Interest Underneath',
        ],
    };
  }

  static String _pick(
    List<String> values,
    RediscoverJourney journey,
    String salt,
  ) {
    if (values.isEmpty) return 'Something Worth Reopening';
    final ids = journey.items.map((item) => item.url.id).join(':');
    final index = '$ids:${journey.kind.name}:$salt'.hashCode.abs() %
        values.length;
    return values[index];
  }

  static String _domainNoun(_MemoryDomain domain, {required bool plural}) {
    return switch (domain) {
      _MemoryDomain.cooking => plural ? 'recipes' : 'recipe',
      _MemoryDomain.building => plural ? 'build notes' : 'build note',
      _MemoryDomain.philosophy => plural ? 'questions' : 'question',
      _MemoryDomain.travel => plural ? 'places' : 'place',
      _MemoryDomain.nature => plural ? 'field notes' : 'field note',
      _MemoryDomain.fitness => plural ? 'health ideas' : 'health idea',
      _MemoryDomain.creative => plural ? 'references' : 'reference',
      _MemoryDomain.learning => plural ? 'learning notes' : 'learning note',
      _MemoryDomain.money => plural ? 'money notes' : 'money note',
      _MemoryDomain.watchlist => plural ? 'watchlist saves' : 'watchlist save',
      _MemoryDomain.general => plural ? 'saves' : 'save',
    };
  }

  static String _countWord(int count) {
    return switch (count) {
      0 => 'No',
      1 => 'One',
      2 => 'Two',
      3 => 'Three',
      4 => 'Four',
      5 => 'Five',
      6 => 'Six',
      7 => 'Seven',
      8 => 'Eight',
      _ => '$count',
    };
  }

  static bool _containsAny(String text, List<String> needles) {
    for (final needle in needles) {
      if (text.contains(needle)) return true;
    }
    return false;
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
