import '../../core/models/saved_url.dart';
import '../../core/services/memory_intent_resolver.dart';
import '../../core/services/tag_noise_filter.dart';
import '../../core/services/title_resolver.dart';
import 'rediscover_journey_provider.dart';
import 'rediscover_topic_evidence.dart';

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
  const RediscoverNotificationCopy({required this.title, required this.body});

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

enum RediscoverSemanticJourneyType {
  learning,
  planning,
  cooking,
  building,
  researching,
  collecting,
  watching,
  practicing,
  improving,
  revisiting,
}

class RediscoverSemanticIntent {
  const RediscoverSemanticIntent({
    required this.label,
    required this.journeyType,
    required this.userGoal,
    required this.behaviorSummary,
    required this.evidencePhrases,
    required this.confidence,
  });

  final String label;
  final RediscoverSemanticJourneyType journeyType;
  final String userGoal;
  final String behaviorSummary;
  final List<String> evidencePhrases;
  final double confidence;
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

class _SemanticLabelResult {
  const _SemanticLabelResult({
    required this.label,
    required this.confidence,
    required this.evidence,
  });

  final String label;
  final double confidence;
  final List<String> evidence;
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
    required this.semanticIntent,
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
  final RediscoverSemanticIntent semanticIntent;
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
    final unopenedCount = journey.items
        .where((item) => item.url.openedAt == null)
        .length;
    final openedCount = saveCount - unopenedCount;
    final displayTopic = (journey.topicAnchor ?? journey.title).trim();
    final topicKey = (journey.stableTopicKey ?? displayTopic).trim();
    final emotion = _emotionFor(journey);
    final metadata = _metadataFor(
      journey,
      topicKey: topicKey,
      topicLabel: _topicTitle(displayTopic),
      saveCount: saveCount,
      unopenedCount: unopenedCount,
      openedCount: openedCount,
    );
    final topicLabel = metadata.topicLabel;
    final personality = _personalityFor(journey, topicLabel);
    final semanticIntent = _semanticIntentFor(journey, topicLabel: topicLabel);
    final cardSubtitle = _cardSubtitleFor(
      journey,
      semanticIntent: semanticIntent,
    );
    final copyIdentity = _copyIdentityFor(
      journey,
      topicLabel: topicLabel,
      primaryTitle: primaryTitle,
      saveCount: saveCount,
      unopenedCount: unopenedCount,
      openedCount: openedCount,
      personality: personality,
      semanticIntent: semanticIntent,
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
      semanticIntent: semanticIntent,
      copyIdentity: copyIdentity,
      encouragedAction: action,
      homeCopy: _homeCopyFor(
        journey,
        title: what,
        subtitle: cardSubtitle,
        whyNow: whyNow,
        action: action,
      ),
      rediscoverCopy: _rediscoverCopyFor(
        journey,
        title: what,
        subtitle: cardSubtitle,
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
    required RediscoverSemanticIntent semanticIntent,
  }) {
    final domain = _domainFor(journey, topicLabel);
    return RediscoverMemoryIdentity(
      primary: semanticIntent.label,
      secondaryDescription: _secondaryDescriptionFor(
        journey,
        domain: domain,
        primaryTitle: primaryTitle,
        saveCount: saveCount,
        unopenedCount: unopenedCount,
        semanticIntent: semanticIntent,
      ),
      reasonForToday: _reasonForTodayFor(
        journey,
        openedCount: openedCount,
        unopenedCount: unopenedCount,
        semanticIntent: semanticIntent,
      ),
      suggestedNextStep: _suggestedNextStepFor(
        journey,
        domain: domain,
        primaryTitle: primaryTitle,
        semanticIntent: semanticIntent,
      ),
    );
  }

  static RediscoverSemanticIntent _semanticIntentFor(
    RediscoverJourney journey, {
    required String topicLabel,
  }) {
    final urls = journey.items.map((item) => item.url).toList();
    final text = _combinedText(journey, topicLabel);
    final tags = _rankedTags(urls);
    final intentCounts = <String, int>{};
    for (final url in urls) {
      final intent = MemoryIntentResolver.fromUrl(url);
      final primary = intent?.primaryIntent.trim().toLowerCase();
      if (primary != null && primary.isNotEmpty) {
        intentCounts[primary] = (intentCounts[primary] ?? 0) + 1;
      }
    }

    final primaryIntent = _dominantKey(intentCounts);
    final journeyType = _journeyTypeFor(
      primaryIntent,
      journey: journey,
      domain: _domainFor(journey, topicLabel),
      text: text,
    );
    final labelResult = _semanticLabelFor(
      journey,
      journeyType: journeyType,
      topicLabel: topicLabel,
      tags: tags,
      text: text,
    );
    final goal = _userGoalFor(labelResult.label, journeyType);
    final behavior = _behaviorSummaryFor(
      labelResult.label,
      journeyType,
      journey.kind,
    );

    return RediscoverSemanticIntent(
      label: labelResult.label,
      journeyType: journeyType,
      userGoal: goal,
      behaviorSummary: behavior,
      evidencePhrases: labelResult.evidence,
      confidence: labelResult.confidence,
    );
  }

  static String _combinedText(RediscoverJourney journey, String topicLabel) {
    return [
      topicLabel,
      journey.title,
      journey.subtitle,
      for (final item in journey.items.take(8)) ...[
        item.url.title,
        item.url.description,
        item.url.summary ?? '',
        item.url.category,
        item.url.categories.join(' '),
        item.url.tags.join(' '),
        MemoryIntentResolver.searchableText(item.url),
      ],
    ].join(' ').toLowerCase();
  }

  static List<String> _rankedTags(List<SavedUrl> urls, {int minimumCount = 1}) {
    final counts = <String, int>{};
    for (final url in urls) {
      for (final tag in TagNoiseFilter.filterTags(url.tags)) {
        if (_semanticNoiseTerms.contains(tag)) continue;
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return b.key.length.compareTo(a.key.length);
      });
    return ranked
        .where((entry) => entry.value >= minimumCount)
        .map((entry) => entry.key)
        .toList();
  }

  static String? _dominantKey(Map<String, int> counts) {
    if (counts.isEmpty) return null;
    final ranked = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    return ranked.first.key;
  }

  static RediscoverSemanticJourneyType _journeyTypeFor(
    String? primaryIntent, {
    required RediscoverJourney journey,
    required _MemoryDomain domain,
    required String text,
  }) {
    final intentType = switch (primaryIntent) {
      'cook' => RediscoverSemanticJourneyType.cooking,
      'visit' => RediscoverSemanticJourneyType.planning,
      'build' => RediscoverSemanticJourneyType.building,
      'watch_later' => RediscoverSemanticJourneyType.watching,
      'read_later' =>
        _containsAny(text, const ['manga', 'book', 'reading'])
            ? RediscoverSemanticJourneyType.collecting
            : RediscoverSemanticJourneyType.learning,
      'try' => RediscoverSemanticJourneyType.practicing,
      'health_change' => RediscoverSemanticJourneyType.improving,
      'career_move' => RediscoverSemanticJourneyType.improving,
      'learn' => RediscoverSemanticJourneyType.learning,
      _ => null,
    };
    if (intentType != null) return intentType;

    if (_hasSharedEvidence(journey, const [
      'free will',
      'free-will',
      'determinism',
      'consciousness',
      'stoic',
      'philosophy',
    ])) {
      return RediscoverSemanticJourneyType.learning;
    }
    if (_hasSharedEvidence(journey, const [
      'book recommendation',
      'book recommendations',
      'reading recommendation',
      'reading recommendations',
      'reading list',
    ])) {
      return RediscoverSemanticJourneyType.collecting;
    }

    return switch (domain) {
      _MemoryDomain.cooking => RediscoverSemanticJourneyType.cooking,
      _MemoryDomain.building => RediscoverSemanticJourneyType.building,
      _MemoryDomain.travel => RediscoverSemanticJourneyType.planning,
      _MemoryDomain.watchlist =>
        _containsAny(text, const ['book', 'reading', 'novel', 'essay'])
            ? RediscoverSemanticJourneyType.collecting
            : RediscoverSemanticJourneyType.watching,
      _MemoryDomain.fitness => RediscoverSemanticJourneyType.improving,
      _MemoryDomain.philosophy => RediscoverSemanticJourneyType.learning,
      _MemoryDomain.nature =>
        _containsAny(text, const ['farm', 'garden'])
            ? RediscoverSemanticJourneyType.planning
            : RediscoverSemanticJourneyType.learning,
      _ => RediscoverSemanticJourneyType.researching,
    };
  }

  static _SemanticLabelResult _semanticLabelFor(
    RediscoverJourney journey, {
    required RediscoverSemanticJourneyType journeyType,
    required String topicLabel,
    required List<String> tags,
    required String text,
  }) {
    _SemanticLabelResult result(
      String label,
      double confidence,
      List<String> evidence,
    ) {
      return _SemanticLabelResult(
        label: label,
        confidence: confidence,
        evidence: evidence.where((item) => item.trim().isNotEmpty).toList(),
      );
    }

    if (_hasSharedEvidence(journey, const [
      'high protein',
      'high-protein',
      'protein recipe',
    ])) {
      if (_hasSharedEvidence(journey, const ['breakfast'])) {
        return result('High-Protein Breakfasts', 0.92, [
          'high protein',
          'breakfast',
        ]);
      }
      if (_hasSharedEvidence(journey, const [
        'vegetarian',
        'paneer',
        'soya',
        'edamame',
      ])) {
        return result('High-Protein Vegetarian Meals', 0.9, [
          'high protein',
          'vegetarian',
        ]);
      }
      return result('High-Protein Recipes', 0.86, ['high protein']);
    }
    if (_hasSharedEvidence(journey, const ['healthy', 'salad']) &&
        _hasSharedEvidence(journey, const ['dinner', 'recipe', 'meal'])) {
      return result('Healthy Dinner Recipes', 0.84, ['healthy', 'recipe']);
    }
    if (_hasSharedEvidence(journey, const [
      'free will',
      'free-will',
      'determinism',
      'agency',
    ])) {
      return result('Understanding Free Will', 0.92, ['free will']);
    }
    if (_hasSharedEvidence(journey, const ['consciousness', 'awareness'])) {
      return result('Understanding Consciousness', 0.88, ['consciousness']);
    }
    if (_hasSharedEvidence(journey, const ['stoic', 'marcus aurelius'])) {
      return result('Stoic Principles', 0.86, ['stoicism']);
    }
    if (_hasSharedEvidence(journey, const ['hindu', 'gita', 'vedic'])) {
      return result('Hindu Philosophy', 0.84, ['hindu philosophy']);
    }
    if (_hasSharedEvidence(journey, const ['himalaya', 'himachal', 'ladakh']) &&
        _hasSharedEvidence(journey, const ['trek', 'travel', 'route'])) {
      return result('Himalayan Treks', 0.9, ['himalaya', 'trek']);
    }
    if (_hasSharedEvidence(journey, const ['manga'])) {
      return result('Manga To Read', 0.88, ['manga']);
    }
    if (_hasSharedEvidence(journey, const ['anime'])) {
      return result('Anime To Watch', 0.84, ['anime']);
    }
    if (RediscoverTopicEvidence.hasSharedMovieWatchRecommendations(
      journey.items.map((item) => item.url),
    )) {
      return result('Movies To Watch', 0.9, ['movie watch intent']);
    }
    if (_hasSharedEvidence(journey, const [
      'wildlife photography',
      'photography',
    ])) {
      return result('Wildlife Photography', 0.9, ['wildlife photography']);
    }
    if (_hasSharedEvidence(journey, const ['wildlife'])) {
      return result('Wildlife Notes', 0.82, ['wildlife']);
    }
    if (_hasSharedEvidence(journey, const [
      'natural farming',
      'permaculture',
    ])) {
      return result('Natural Farming', 0.9, ['natural farming']);
    }
    if (_hasSharedEvidence(journey, const ['crispr', 'plant biotechnology'])) {
      return result('Plant Biotechnology', 0.88, ['plant biotechnology']);
    }
    if (_hasSharedEvidence(journey, const ['flutter', 'riverpod'])) {
      return result('Flutter Development Notes', 0.88, ['flutter']);
    }
    if (_hasSharedEvidence(journey, const [
      'llm',
      'genai',
      'ai agent',
      'ai engineering',
    ])) {
      return result('AI Engineering Notes', 0.88, ['AI engineering']);
    }
    if (_hasSharedEvidence(journey, const [
      'startup',
      'founder',
      'y combinator',
    ])) {
      return result('Startup Reading', 0.86, ['startup']);
    }
    if (_hasSharedEvidence(journey, const [
          'book',
          'reading',
          'novel',
          'essay',
        ]) &&
        _hasSharedEvidence(journey, const [
          'recommendation',
          'recommendations',
          'reading list',
        ])) {
      return result('Reading Recommendations', 0.86, [
        'reading',
        'recommendations',
      ]);
    }

    final meaningfulTag = tags.isEmpty ? null : tags.first;
    if (meaningfulTag != null) {
      final concept = _topicTitle(meaningfulTag);
      final label = _labelFromConcept(concept, journeyType);
      return result(label, 0.72, [meaningfulTag]);
    }

    return result(_clearTopicLabel(topicLabel, journeyType), 0.56, [
      topicLabel,
    ]);
  }

  static String _labelFromConcept(
    String concept,
    RediscoverSemanticJourneyType journeyType,
  ) {
    final normalized = _normalizeConceptPhrase(concept);
    final lower = normalized.toLowerCase();
    if (lower.endsWith('recipes') ||
        lower.endsWith('meals') ||
        lower.endsWith('notes') ||
        lower.endsWith('treks') ||
        lower.endsWith('photography') ||
        lower.endsWith('recommendations') ||
        lower.endsWith('reading') ||
        lower.endsWith('list')) {
      return normalized;
    }
    return switch (journeyType) {
      RediscoverSemanticJourneyType.cooking =>
        lower.contains('recipe') ? normalized : '$normalized Recipes',
      RediscoverSemanticJourneyType.watching => '$normalized To Watch',
      RediscoverSemanticJourneyType.collecting =>
        lower.contains('book') ? normalized : '$normalized List',
      RediscoverSemanticJourneyType.building => '$normalized Notes',
      RediscoverSemanticJourneyType.planning => normalized,
      RediscoverSemanticJourneyType.improving => normalized,
      RediscoverSemanticJourneyType.practicing => normalized,
      RediscoverSemanticJourneyType.learning =>
        lower.startsWith('understanding')
            ? normalized
            : 'Understanding $normalized',
      RediscoverSemanticJourneyType.researching => normalized,
      RediscoverSemanticJourneyType.revisiting => normalized,
    };
  }

  static String _normalizeConceptPhrase(String concept) {
    final clean = concept.trim();
    final lower = clean.toLowerCase();
    if (lower == 'recommendation reading' ||
        lower == 'recommendations reading' ||
        lower == 'reading recommendation') {
      return 'Reading Recommendations';
    }
    if (lower == 'recommendation') return 'Recommendations';
    return clean;
  }

  static String _clearTopicLabel(
    String topicLabel,
    RediscoverSemanticJourneyType journeyType,
  ) {
    final clean = topicLabel.trim().isEmpty ? 'Saved Ideas' : topicLabel;
    return _labelFromConcept(clean, journeyType);
  }

  static String _userGoalFor(
    String label,
    RediscoverSemanticJourneyType journeyType,
  ) {
    final lower = _semanticSubject(label);
    return switch (journeyType) {
      RediscoverSemanticJourneyType.cooking => 'cooking $lower',
      RediscoverSemanticJourneyType.planning => 'planning around $lower',
      RediscoverSemanticJourneyType.building => 'building with $lower',
      RediscoverSemanticJourneyType.watching => 'choosing what to watch',
      RediscoverSemanticJourneyType.collecting => 'saving $lower for later',
      RediscoverSemanticJourneyType.practicing => 'practicing $lower',
      RediscoverSemanticJourneyType.improving => 'improving $lower',
      RediscoverSemanticJourneyType.learning => 'understanding $lower',
      RediscoverSemanticJourneyType.researching => 'researching $lower',
      RediscoverSemanticJourneyType.revisiting => 'returning to $lower',
    };
  }

  static String _behaviorSummaryFor(
    String label,
    RediscoverSemanticJourneyType journeyType,
    RediscoverJourneyKind kind,
  ) {
    final lower = _semanticSubject(label);
    final base = switch (journeyType) {
      RediscoverSemanticJourneyType.cooking => 'You were collecting $lower.',
      RediscoverSemanticJourneyType.planning =>
        'You were comparing options around $lower.',
      RediscoverSemanticJourneyType.building =>
        'You were saving technical references for $lower.',
      RediscoverSemanticJourneyType.watching =>
        'You were building a watchlist around $lower.',
      RediscoverSemanticJourneyType.collecting =>
        'You were collecting $lower for later.',
      RediscoverSemanticJourneyType.practicing =>
        'You were gathering ways to practice $lower.',
      RediscoverSemanticJourneyType.improving =>
        'You were looking for ways to improve $lower.',
      RediscoverSemanticJourneyType.learning =>
        'You were trying to understand $lower.',
      RediscoverSemanticJourneyType.researching =>
        'You were researching $lower from a few angles.',
      RediscoverSemanticJourneyType.revisiting =>
        'You kept coming back to $lower.',
    };
    if (kind == RediscoverJourneyKind.continueLearning) {
      return base.replaceFirst('.', ' and recently added more.');
    }
    if (kind == RediscoverJourneyKind.neverOpened) {
      return base.replaceFirst('were ', 'saved these to ');
    }
    return base;
  }

  static String _semanticSubject(String label) {
    var subject = _lowerFirst(label);
    const prefixes = ['understanding ', 'learning about '];
    for (final prefix in prefixes) {
      if (subject.startsWith(prefix)) {
        subject = subject.substring(prefix.length);
        break;
      }
    }
    return subject;
  }

  static String _cardSubtitleFor(
    RediscoverJourney journey, {
    required RediscoverSemanticIntent semanticIntent,
  }) {
    final concepts = _supportingConcepts(journey, semanticIntent.label);
    final details = _readableConcepts(concepts);
    if (details.isNotEmpty) {
      return switch (semanticIntent.journeyType) {
        RediscoverSemanticJourneyType.cooking => 'Recipes featuring $details.',
        RediscoverSemanticJourneyType.planning =>
          'Ideas for planning around $details.',
        RediscoverSemanticJourneyType.building =>
          'Technical notes on $details.',
        RediscoverSemanticJourneyType.watching =>
          'Watch picks shaped around $details.',
        RediscoverSemanticJourneyType.collecting =>
          'Reading picks on $details.',
        RediscoverSemanticJourneyType.practicing =>
          'Ways to practice $details.',
        RediscoverSemanticJourneyType.improving =>
          'Practical ideas around $details.',
        RediscoverSemanticJourneyType.learning => 'Ideas on $details.',
        RediscoverSemanticJourneyType.researching =>
          'Perspectives on $details.',
        RediscoverSemanticJourneyType.revisiting =>
          'Saves connected by $details.',
      };
    }

    return switch (semanticIntent.journeyType) {
      RediscoverSemanticJourneyType.cooking => 'Recipes you saved to try.',
      RediscoverSemanticJourneyType.planning =>
        'Options and ideas worth comparing.',
      RediscoverSemanticJourneyType.building =>
        'Technical references worth reopening.',
      RediscoverSemanticJourneyType.watching =>
        'Watch picks you set aside for later.',
      RediscoverSemanticJourneyType.collecting =>
        'Reading picks worth returning to.',
      RediscoverSemanticJourneyType.practicing =>
        'Practical steps worth trying.',
      RediscoverSemanticJourneyType.improving =>
        'Useful ideas worth another look.',
      RediscoverSemanticJourneyType.learning =>
        'Questions and explanations worth revisiting.',
      RediscoverSemanticJourneyType.researching =>
        'Perspectives worth comparing again.',
      RediscoverSemanticJourneyType.revisiting =>
        'Related saves worth reopening.',
    };
  }

  static List<String> _supportingConcepts(
    RediscoverJourney journey,
    String title,
  ) {
    final titleWords = _conceptWords(title);
    final concepts = <String>[];
    for (final tag in _rankedTags(
      journey.items.map((item) => item.url).toList(),
      minimumCount: journey.items.length == 1 ? 1 : 2,
    )) {
      final concept = _normalizeConceptPhrase(_topicTitle(tag));
      final words = _conceptWords(concept);
      if (words.isEmpty || words.every(titleWords.contains)) continue;
      if (_genericSupportingConcepts.contains(concept.toLowerCase())) continue;
      concepts.add(_sentenceConcept(concept));
      if (concepts.length == 2) break;
    }
    return concepts;
  }

  static Set<String> _conceptWords(String value) {
    return value
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.length > 2)
        .toSet();
  }

  static String _sentenceConcept(String value) {
    return value
        .split(' ')
        .map((word) {
          if (word.length <= 3 && word == word.toUpperCase()) return word;
          return word.toLowerCase();
        })
        .join(' ');
  }

  static String _readableConcepts(List<String> concepts) {
    return switch (concepts.length) {
      0 => '',
      1 => concepts.first,
      _ => '${concepts.first} and ${concepts[1]}',
    };
  }

  static bool _hasSharedEvidence(
    RediscoverJourney journey,
    List<String> needles,
  ) {
    return RediscoverTopicEvidence.hasSharedTerms(
      journey.items.map((item) => item.url),
      needles,
    );
  }

  static RediscoverMemoryEmotion _emotionFor(RediscoverJourney journey) {
    return switch (journey.kind) {
      RediscoverJourneyKind.returningTopic =>
        RediscoverMemoryEmotion.recognition,
      RediscoverJourneyKind.continueLearning =>
        RediscoverMemoryEmotion.momentum,
      RediscoverJourneyKind.forgottenGems =>
        RediscoverMemoryEmotion.recognition,
      RediscoverJourneyKind.onThisDay => RediscoverMemoryEmotion.nostalgia,
      RediscoverJourneyKind.memoryGoal => RediscoverMemoryEmotion.intention,
      RediscoverJourneyKind.neverOpened => RediscoverMemoryEmotion.relief,
      RediscoverJourneyKind.becauseYouSaved =>
        RediscoverMemoryEmotion.curiosity,
    };
  }

  static RediscoverMemoryCopy _homeCopyFor(
    RediscoverJourney journey, {
    required String title,
    required String subtitle,
    required String whyNow,
    required String action,
  }) {
    return RediscoverMemoryCopy(
      title: title,
      subtitle: subtitle,
      body: whyNow,
      actionLabel: action,
    );
  }

  static RediscoverMemoryCopy _rediscoverCopyFor(
    RediscoverJourney journey, {
    required String title,
    required String subtitle,
    required String whyItMatters,
    required String whyNow,
    required String action,
    required String? primaryTitle,
  }) {
    final startLine =
        primaryTitle == null || _containsTitle(action, primaryTitle)
        ? action
        : '$action: $primaryTitle';
    return RediscoverMemoryCopy(
      title: title,
      subtitle: subtitle,
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
      RediscoverMemoryPersonality.experimental =>
        '$title deserves a second look',
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
  ) {
    final domain = _domainFor(journey, topicLabel);
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
      _MemoryDomain.general =>
        journey.kind == RediscoverJourneyKind.continueLearning
            ? RediscoverMemoryPersonality.curious
            : RediscoverMemoryPersonality.reflective,
    };
  }

  static _MemoryDomain _domainFor(
    RediscoverJourney journey,
    String topicLabel,
  ) {
    final topicText = [topicLabel, journey.title].join(' ').toLowerCase();

    bool hasDomainEvidence(List<String> needles) {
      return _containsAny(topicText, needles) ||
          _hasSharedEvidence(journey, needles);
    }

    if (_hasFoodSubjectMatter(topicText) || _hasSharedFoodEvidence(journey)) {
      return _MemoryDomain.cooking;
    }
    if (hasDomainEvidence(const [
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
    if (hasDomainEvidence(const [
      'philosophy',
      'stoic',
      'gita',
      'meaning',
      'wisdom',
      'question',
      'free will',
      'determinism',
      'consciousness',
    ])) {
      return _MemoryDomain.philosophy;
    }
    if (hasDomainEvidence(const [
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
    if (hasDomainEvidence(const [
      'farm',
      'garden',
      'wildlife',
      'forest',
      'nature',
      'plant',
    ])) {
      return _MemoryDomain.nature;
    }
    if (hasDomainEvidence(const [
      'fitness',
      'workout',
      'protein',
      'run',
      'strength',
      'health',
    ])) {
      return _MemoryDomain.fitness;
    }
    if (hasDomainEvidence(const [
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
    if (hasDomainEvidence(const [
      'learn',
      'course',
      'study',
      'tutorial',
      'research',
      'science',
    ])) {
      return _MemoryDomain.learning;
    }
    if (hasDomainEvidence(const [
      'money',
      'finance',
      'invest',
      'budget',
      'tax',
    ])) {
      return _MemoryDomain.money;
    }
    if (hasDomainEvidence(const [
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

  static bool _hasSharedFoodEvidence(RediscoverJourney journey) {
    return RediscoverTopicEvidence.hasSharedMatch(
      journey.items.map((item) => item.url),
      _hasFoodSubjectMatter,
    );
  }

  static String _secondaryDescriptionFor(
    RediscoverJourney journey, {
    required _MemoryDomain domain,
    required String? primaryTitle,
    required int saveCount,
    required int unopenedCount,
    required RediscoverSemanticIntent semanticIntent,
  }) {
    final count = _countWord(saveCount);
    final noun = _domainNoun(domain, plural: saveCount != 1);
    final first = primaryTitle == null ? '' : ' Start with $primaryTitle.';
    if (unopenedCount == saveCount) {
      return '$count saved $noun for ${semanticIntent.userGoal}.$first';
    }
    if (unopenedCount > 0) {
      return '$count saved $noun for ${semanticIntent.userGoal}, '
          '$unopenedCount still unopened.$first';
    }
    return '$count saved $noun for ${semanticIntent.userGoal}.$first';
  }

  static String _reasonForTodayFor(
    RediscoverJourney journey, {
    required int openedCount,
    required int unopenedCount,
    required RediscoverSemanticIntent semanticIntent,
  }) {
    final summary = semanticIntent.behaviorSummary;
    return switch (journey.kind) {
      RediscoverJourneyKind.returningTopic => _returningTopicReason(journey),
      RediscoverJourneyKind.continueLearning => summary,
      RediscoverJourneyKind.forgottenGems =>
        '$summary You had left this aside.',
      RediscoverJourneyKind.onThisDay =>
        '$summary This was part of an earlier season.',
      RediscoverJourneyKind.memoryGoal => summary,
      RediscoverJourneyKind.neverOpened =>
        '$summary You have not opened ${unopenedCount <= 1 ? 'it' : 'them'} yet.',
      RediscoverJourneyKind.becauseYouSaved =>
        openedCount > 0
            ? '$summary You already returned to part of it.'
            : summary,
    };
  }

  static String _suggestedNextStepFor(
    RediscoverJourney journey, {
    required _MemoryDomain domain,
    required String? primaryTitle,
    required RediscoverSemanticIntent semanticIntent,
  }) {
    if (primaryTitle != null && primaryTitle.trim().isNotEmpty) {
      return switch (domain) {
        _MemoryDomain.cooking => 'Try $primaryTitle',
        _MemoryDomain.building => 'Open $primaryTitle first',
        _MemoryDomain.travel => 'Recheck $primaryTitle',
        _MemoryDomain.watchlist => 'Start with $primaryTitle',
        _ => 'Start with $primaryTitle',
      };
    }
    return switch (semanticIntent.journeyType) {
      RediscoverSemanticJourneyType.cooking => 'Pick one recipe',
      RediscoverSemanticJourneyType.planning =>
        'Review the most practical save',
      RediscoverSemanticJourneyType.building => 'Open the clearest note',
      RediscoverSemanticJourneyType.watching => 'Pick one to watch',
      RediscoverSemanticJourneyType.collecting => 'Open the strongest item',
      RediscoverSemanticJourneyType.practicing => 'Try one small step',
      RediscoverSemanticJourneyType.improving => 'Choose one practical change',
      RediscoverSemanticJourneyType.learning => 'Start with the clearest save',
      RediscoverSemanticJourneyType.researching => 'Open the best overview',
      RediscoverSemanticJourneyType.revisiting => 'Reopen one save',
    };
  }

  static String _lowerFirst(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return clean;
    return clean.toLowerCase();
  }

  static const _semanticNoiseTerms = {
    'business',
    'education',
    'entertainment',
    'food',
    'guide',
    'health',
    'idea',
    'ideas',
    'lifestyle',
    'movie recommendations',
    'other',
    'recipe',
    'recipes',
    'recommendations',
    'recommendation',
    'reference',
    'science',
    'technology',
    'travel',
  };

  static const _genericSupportingConcepts = {
    'article',
    'articles',
    'book',
    'books',
    'content',
    'guide',
    'guides',
    'idea',
    'ideas',
    'note',
    'notes',
    'recommendation',
    'recommendations',
    'recipe',
    'recipes',
    'save',
    'saves',
  };

  static String _domainNoun(_MemoryDomain domain, {required bool plural}) {
    return switch (domain) {
      _MemoryDomain.cooking => plural ? 'recipes' : 'recipe',
      _MemoryDomain.building => plural ? 'technical saves' : 'technical save',
      _MemoryDomain.philosophy => plural ? 'questions' : 'question',
      _MemoryDomain.travel => plural ? 'places' : 'place',
      _MemoryDomain.nature => plural ? 'nature saves' : 'nature save',
      _MemoryDomain.fitness => plural ? 'health ideas' : 'health idea',
      _MemoryDomain.creative => plural ? 'references' : 'reference',
      _MemoryDomain.learning => plural ? 'learning saves' : 'learning save',
      _MemoryDomain.money => plural ? 'money saves' : 'money save',
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

  static bool _containsTitle(String value, String title) {
    return value.toLowerCase().contains(title.toLowerCase());
  }

  static bool _hasFoodSubjectMatter(String text) {
    if (_containsAny(text, const [
      'recipe',
      'recipes',
      'ingredient',
      'ingredients',
      'cook ',
      'cooking',
      'bake',
      'baking',
      'kitchen',
      'dish',
      'meal prep',
      'restaurant',
      'cafe',
      'cuisine',
    ])) {
      return true;
    }
    final hasMealWord = _containsAny(text, const [
      'breakfast',
      'lunch',
      'dinner',
      'snack',
      'meal',
    ]);
    if (!hasMealWord) return false;
    if (_containsAny(text, const [
      'debate',
      'argument',
      'conversation',
      'discussion',
      'thought',
    ])) {
      return false;
    }
    return _containsAny(text, const [
      'healthy',
      'protein',
      'vegetarian',
      'vegan',
      'calorie',
      'eat',
      'food',
    ]);
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
      if (journey.triggerSaveId != null) 'trigger-${journey.triggerSaveId}',
      ids.take(4).join('-'),
    ].where((part) => part.isNotEmpty).join(':');
  }

  static String _returningTopicReason(RediscoverJourney journey) {
    final topic = _topicTitle(journey.topicAnchor ?? journey.title);
    final triggerTitle = journey.triggerTitle?.trim();
    if (triggerTitle == null || triggerTitle.isEmpty) {
      return 'A new $topic save brought these earlier saves back into view.';
    }
    return 'Your new save, “$triggerTitle,” brought these earlier $topic saves back into view.';
  }

  static String _topicTitle(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+|_+'))
        .where((word) => word.isNotEmpty);
    return words
        .map((word) {
          final lower = word.toLowerCase();
          const upper = {'ai', 'api', 'ui', 'ux', 'seo', 'saas'};
          const lowerCase = {'and', 'or', 'for', 'to', 'of', 'in', 'on'};
          if (upper.contains(lower)) return lower.toUpperCase();
          if (lowerCase.contains(lower)) return lower;
          if (lower.length <= 3) return lower.toUpperCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }
}
