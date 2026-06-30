import '../models/saved_url.dart';
import 'memory_intent_resolver.dart';
import 'tag_noise_filter.dart';
import 'transcript_enrichment_service.dart';

class MemoryGoal {
  const MemoryGoal({
    required this.id,
    required this.name,
    required this.intent,
    required this.lifeArea,
    required this.urls,
    required this.keyTerms,
    required this.strength,
    required this.status,
    required this.nextAction,
  });

  final String id;
  final String name;
  final String intent;
  final String lifeArea;
  final List<SavedUrl> urls;
  final List<String> keyTerms;
  final double strength;
  final String status;
  final String nextAction;

  int get saveCount => urls.length;

  int get unopenedCount => urls.where((url) => url.openedAt == null).length;

  DateTime get newestSavedAt =>
      urls.map((url) => url.savedAt).reduce((a, b) => a.isAfter(b) ? a : b);
}

class MemoryGoalService {
  const MemoryGoalService._();

  static List<MemoryGoal> buildGoals(
    List<SavedUrl> urls, {
    DateTime? now,
    int minSaves = 2,
  }) {
    final clock = now ?? DateTime.now();
    final candidates = urls.where((url) => !url.isDone).toList();
    if (candidates.isEmpty) return const [];

    final buckets = <String, _GoalBucket>{};
    for (final url in candidates) {
      final intent = MemoryIntentResolver.fromUrl(url) ?? _fallbackIntent(url);
      final primaryIntent = _cleanToken(intent.primaryIntent);
      if (primaryIntent.isEmpty || primaryIntent == 'reference') continue;

      final concept = _goalConcept(url, intent);
      if (concept.isEmpty) continue;
      final key = '$primaryIntent|${_cleanToken(concept)}';
      final bucket = buckets.putIfAbsent(
        key,
        () => _GoalBucket(
          intent: primaryIntent,
          lifeArea:
              _cleanDisplay(intent.lifeArea) ??
              _lifeAreaForIntent(primaryIntent),
          concept: concept,
        ),
      );
      bucket.add(url, intent);
    }

    final goals = <MemoryGoal>[];
    for (final bucket in buckets.values) {
      if (bucket.urls.length < minSaves) continue;
      final sortedUrls = List<SavedUrl>.from(bucket.urls)
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
      final keyTerms = bucket.keyTerms();
      final name = _goalName(bucket.intent, bucket.concept);
      goals.add(
        MemoryGoal(
          id: _goalId(bucket.intent, bucket.concept),
          name: name,
          intent: bucket.intent,
          lifeArea: bucket.lifeArea,
          urls: sortedUrls,
          keyTerms: keyTerms,
          strength: _strength(bucket, clock),
          status: _status(bucket, clock),
          nextAction: _nextAction(bucket.intent),
        ),
      );
    }

    goals.sort((a, b) {
      final byStrength = b.strength.compareTo(a.strength);
      if (byStrength != 0) return byStrength;
      return b.newestSavedAt.compareTo(a.newestSavedAt);
    });
    return goals;
  }

  static MemoryIntentMetadata _fallbackIntent(SavedUrl url) {
    final text = [
      url.title,
      url.description,
      url.summary ?? '',
      url.category,
      ...url.tags,
    ].join(' ').toLowerCase();

    if (_containsAny(text, const [
      'recipe',
      'cook',
      'meal',
      'dinner',
      'lunch',
      'breakfast',
      'ingredient',
    ])) {
      return const MemoryIntentMetadata(
        primaryIntent: 'cook',
        lifeArea: 'food',
        actionability: 'high',
      );
    }
    if (_containsAny(text, const [
      'travel',
      'trip',
      'visit',
      'itinerary',
      'trek',
      'hotel',
      'restaurant',
    ])) {
      return const MemoryIntentMetadata(
        primaryIntent: 'visit',
        lifeArea: 'travel',
      );
    }
    if (_containsAny(text, const [
      'learn',
      'tutorial',
      'guide',
      'course',
      'lesson',
      'flutter',
      'riverpod',
    ])) {
      return const MemoryIntentMetadata(
        primaryIntent: 'learn',
        lifeArea: 'education',
      );
    }
    if (_containsAny(text, const [
      'startup',
      'business idea',
      'saas',
      'build',
      'github',
      'repository',
      'repo',
      'api',
    ])) {
      return const MemoryIntentMetadata(
        primaryIntent: 'build',
        lifeArea: 'business',
      );
    }
    return const MemoryIntentMetadata(primaryIntent: 'reference');
  }

  static String _goalConcept(SavedUrl url, MemoryIntentMetadata intent) {
    final location = _cleanDisplay(intent.location);
    if (intent.primaryIntent == 'visit' && location != null) return location;

    final tags = TagNoiseFilter.filterTags(
      url.tags,
    ).where((tag) => !_genericTerms.contains(tag)).toList();
    if (tags.isNotEmpty) {
      tags.sort((a, b) {
        final byLength = b.length.compareTo(a.length);
        if (byLength != 0) return byLength;
        return a.compareTo(b);
      });
      return _titleCase(tags.first);
    }

    final lifeArea = _cleanDisplay(intent.lifeArea);
    if (lifeArea != null && lifeArea.toLowerCase() != 'other') {
      return lifeArea;
    }

    final title = url.title.trim();
    if (title.isNotEmpty) {
      return title.split(RegExp(r'[:|·-]')).first.trim();
    }
    return '';
  }

  static double _strength(_GoalBucket bucket, DateTime now) {
    final countScore = bucket.urls.length * 10.0;
    final unopenedScore =
        bucket.urls.where((url) => url.openedAt == null).length * 2.0;
    final actionScore = bucket.actionabilityScore;
    final newest = bucket.urls
        .map((url) => url.savedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final daysSinceNewest = now.difference(newest).inDays;
    final recencyScore = daysSinceNewest <= 7
        ? 8.0
        : daysSinceNewest <= 30
        ? 4.0
        : 0.0;
    return countScore + unopenedScore + actionScore + recencyScore;
  }

  static String _status(_GoalBucket bucket, DateTime now) {
    final newest = bucket.urls
        .map((url) => url.savedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final days = now.difference(newest).inDays;
    if (bucket.urls.any((url) => url.isQueued)) return 'queued';
    if (days >= 60) return 'dormant';
    if (days >= 21) return 'cooling';
    return 'active';
  }

  static String _nextAction(String intent) {
    return switch (intent) {
      'cook' => 'Pick one recipe to try this week.',
      'visit' => 'Review the most practical save and start a shortlist.',
      'learn' => 'Start with the clearest beginner-friendly save.',
      'build' => 'Pull out the most concrete idea or tool.',
      'buy' => 'Compare the strongest saved options.',
      'try' => 'Choose one small experiment to try next.',
      'career_move' => 'Turn one save into a concrete career step.',
      'health_change' => 'Choose the lowest-friction habit to try.',
      _ => 'Revisit the most actionable save.',
    };
  }

  static String _goalName(String intent, String concept) {
    final cleanConcept = _titleCase(concept);
    // Some concepts are already an activity or field ("Software Development",
    // "Website Growth") where a leading action verb reads wrong
    // ("Build Software Development"). Use the concept on its own in that case.
    if (_isActivityConcept(concept)) return cleanConcept;
    return switch (intent) {
      'cook' => 'Cook $cleanConcept',
      'visit' => 'Visit $cleanConcept',
      'learn' => 'Learn $cleanConcept',
      'build' => 'Build $cleanConcept',
      'buy' => 'Buy $cleanConcept',
      'try' => 'Try $cleanConcept',
      'career_move' => 'Advance with $cleanConcept',
      'health_change' => 'Improve $cleanConcept',
      _ => 'Revisit $cleanConcept',
    };
  }

  /// True when the concept already names an activity/field, so a leading
  /// action verb ("Build", "Learn") would produce awkward grammar.
  static bool _isActivityConcept(String concept) {
    final lower = concept.trim().toLowerCase();
    const activitySuffixes = [
      'development',
      'growth',
      'building',
      'design',
      'writing',
      'marketing',
      'management',
      'engineering',
      'analysis',
      'research',
      'training',
      'planning',
      'investing',
    ];
    return activitySuffixes.any(lower.endsWith);
  }

  static String _goalId(String intent, String concept) {
    final slug = _cleanToken(concept).replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return '$intent-$slug';
  }

  static String _cleanToken(String? value) =>
      (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

  static String? _cleanDisplay(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String _lifeAreaForIntent(String intent) {
    return switch (intent) {
      'cook' => 'food',
      'visit' => 'travel',
      'learn' => 'education',
      'build' => 'business',
      'career_move' => 'career',
      'health_change' => 'health',
      _ => 'other',
    };
  }

  static String _titleCase(String value) {
    return value
        .trim()
        .split(RegExp(r'\s+|_+'))
        .where((word) => word.isNotEmpty)
        .map((word) {
          final lower = word.toLowerCase();
          const upper = {'ai', 'api', 'ui', 'ux', 'saas'};
          if (upper.contains(lower)) return lower.toUpperCase();
          if (lower.length == 1) return lower.toUpperCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  static bool _containsAny(String value, List<String> needles) =>
      needles.any(value.contains);

  static const _genericTerms = {
    'education',
    'business',
    'technology',
    'travel',
    'food',
    'recipe',
    'recipes',
    'guide',
    'tutorial',
    'idea',
    'ideas',
  };
}

class _GoalBucket {
  _GoalBucket({
    required this.intent,
    required this.lifeArea,
    required this.concept,
  });

  final String intent;
  final String lifeArea;
  final String concept;
  final List<SavedUrl> urls = [];
  final Map<String, int> terms = {};
  double actionabilityScore = 0;

  void add(SavedUrl url, MemoryIntentMetadata metadata) {
    urls.add(url);
    for (final tag in TagNoiseFilter.filterTags(url.tags)) {
      terms[tag] = (terms[tag] ?? 0) + 1;
    }
    actionabilityScore += switch (metadata.actionability?.toLowerCase()) {
      'high' => 3,
      'medium' => 1.5,
      _ => 0,
    };
  }

  List<String> keyTerms() {
    final ranked = terms.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return b.key.length.compareTo(a.key.length);
      });
    return ranked.map((entry) => entry.key).take(5).toList();
  }
}
