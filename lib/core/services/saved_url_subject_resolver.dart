import 'dart:convert';

import '../models/saved_url.dart';
import 'memory_intent_resolver.dart';

class SavedUrlSubject {
  const SavedUrlSubject(this.key, this.label);

  final String key;
  final String label;
}

/// Per-operation subject lookup that avoids repeatedly parsing and normalizing
/// the same save while a Rediscover build compares overlapping clusters.
///
/// The cache is deliberately short-lived. A new instance should be created for
/// each build so edits to a persisted save are reflected on the next run.
class SavedUrlSubjectIndex {
  SavedUrlSubjectIndex({SavedUrlSubject? Function(SavedUrl url)? resolver})
    : _resolver = resolver ?? SavedUrlSubjectResolver.resolve;

  final SavedUrlSubject? Function(SavedUrl url) _resolver;
  final Map<Object, SavedUrlSubject?> _subjects = {};

  SavedUrlSubject? resolve(SavedUrl url) {
    final key = url.id > 0 ? url.id : url;
    return _subjects.putIfAbsent(key, () => _resolver(url));
  }

  SavedUrlSubject? dominantSubject(Iterable<SavedUrl> urls) {
    final candidates = urls.toList();
    if (candidates.isEmpty) return null;
    final counts = <String, int>{};
    final subjects = <String, SavedUrlSubject>{};
    for (final url in candidates) {
      final subject = resolve(url);
      if (subject == null) continue;
      counts[subject.key] = (counts[subject.key] ?? 0) + 1;
      subjects[subject.key] = subject;
    }
    if (counts.isEmpty) return null;
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final winner = ranked.first;
    final required = candidates.length == 1 ? 1 : 2;
    return winner.value >= required ? subjects[winner.key] : null;
  }

  List<SavedUrl> coherentCore(Iterable<SavedUrl> urls) {
    final candidates = urls.toList();
    final subject = dominantSubject(candidates);
    if (subject == null) return candidates;
    final matching = candidates
        .where((url) => resolve(url)?.key == subject.key)
        .toList();
    final minimum = (candidates.length * 0.6).ceil();
    return matching.length >= minimum && matching.length >= 2
        ? matching
        : candidates;
  }
}

/// Resolves the durable subject of a save from structured enrichment evidence.
///
/// This deliberately ignores descriptions and transcripts. Those fields often
/// mention adjacent topics (a sociology video can mention films, for example)
/// and are too noisy to decide which interest a save belongs to.
abstract final class SavedUrlSubjectResolver {
  static const recipes = SavedUrlSubject('recipes', 'Recipes & Cooking');
  static const animeManga = SavedUrlSubject('anime_manga', 'Anime & Manga');
  static const motorcycles = SavedUrlSubject('motorcycles', 'Motorcycles');
  static const music = SavedUrlSubject('music', 'Music');
  static const fitness = SavedUrlSubject('fitness', 'Health & Fitness');
  static const wildlife = SavedUrlSubject(
    'wildlife_nature',
    'Wildlife & Nature',
  );
  static const travel = SavedUrlSubject('travel_places', 'Travel & Places');
  static const movies = SavedUrlSubject('movies_watchlist', 'Movies To Watch');
  static const books = SavedUrlSubject('books_reading', 'Books & Reading');
  static const spirituality = SavedUrlSubject('spirituality', 'Spirituality');
  static const historySociety = SavedUrlSubject(
    'history_society',
    'History & Society',
  );
  static const personalGrowth = SavedUrlSubject(
    'personal_growth',
    'Personal Growth & Philosophy',
  );
  static const finance = SavedUrlSubject(
    'finance_economics',
    'Finance & Economics',
  );
  static const design = SavedUrlSubject(
    'design_creativity',
    'Design & Creativity',
  );
  static const software = SavedUrlSubject('software_ai', 'Software & AI');
  static const science = SavedUrlSubject('science', 'Science');

  static SavedUrlSubject? resolve(SavedUrl url) {
    final enrichment = _enrichmentEvidence(url);
    final intent = MemoryIntentResolver.fromUrl(url);
    final primaryIntent = intent?.primaryIntent.trim().toLowerCase() ?? '';
    final strongText = _normalize(
      [url.title, url.tags.join(' '), enrichment.topics.join(' ')].join(' '),
    );

    if (primaryIntent == 'cook' ||
        enrichment.contentType == 'recipe' ||
        enrichment.hasRecipe ||
        _hasAny(strongText, const [
          'recipe',
          'recipes',
          'cooking',
          'meal prep',
          'homemade pizza',
        ])) {
      return recipes;
    }
    if (_hasAny(strongText, const ['anime', 'manga', 'manhwa', 'manhua'])) {
      return animeManga;
    }
    if (_hasAny(strongText, const [
      'motorcycle',
      'motorcycles',
      'motorcycling',
      'rev matching',
    ])) {
      return motorcycles;
    }
    if (_hasAny(strongText, const [
      'music',
      'song',
      'songs',
      'album',
      'albums',
      'radwimps',
      'music production',
      'devotional chanting',
    ])) {
      return music;
    }
    if (_hasAny(strongText, const [
      'calisthenics',
      'bodyweight',
      'workout',
      'fitness',
      'creatine',
      'sports nutrition',
      'protein sources',
      'brain health',
    ])) {
      return fitness;
    }
    if (_hasAny(strongText, const [
      'wildlife',
      'bird identification',
      'drongo',
      'marine biology',
      'puffling',
      'grassland',
      'ecosystem services',
      'nature conservation',
    ])) {
      return wildlife;
    }
    if (primaryIntent == 'visit' ||
        _hasAny(strongText, const [
          'travel places',
          'travel destination',
          'travel destinations',
          'must visit',
          'must-visit',
          'tourism',
          'expedition',
          'historical sites',
          'places to visit',
        ])) {
      return travel;
    }
    if (_isMovieWatchRecommendation(
      url,
      enrichment,
      primaryIntent: primaryIntent,
    )) {
      return movies;
    }
    if (primaryIntent == 'read_later' ||
        _hasAny(strongText, const [
          'book recommendation',
          'book recommendations',
          'books for',
          'reading list',
          'reader favorites',
          'novel recommendations',
          'fantasy trilogies',
          'book series',
        ])) {
      return books;
    }
    if (_hasAny(strongText, const [
      'hinduism',
      'hindu philosophy',
      'bhagavad gita',
      'upanishad',
      'brahman',
      'non-dual awareness',
      'spirituality',
      'jyotirlinga',
      'shiva',
      'vishnu',
    ])) {
      return spirituality;
    }
    if (_hasAny(strongText, const [
      'world war',
      'ww2',
      'ancient history',
      'historical origins',
      'political science',
      'political theory',
      'fascism',
      'liberalism',
      'demographic coding',
      'social change',
      'sociology',
      'cultural history',
    ])) {
      return historySociety;
    }
    if (_hasAny(strongText, const [
      'personal growth',
      'personal development',
      'self improvement',
      'self-improvement',
      'discipline',
      'mindset',
      'human psychology',
      'life philosophy',
      'personal agency',
      'friendship',
      'journaling',
      'protective boundaries',
    ])) {
      return personalGrowth;
    }
    if (_hasAny(strongText, const [
      'finance',
      'financial',
      'economics',
      'economic development',
      'banking',
      'telecom industry',
      'wealth creation',
    ])) {
      return finance;
    }
    if (_hasAny(strongText, const [
      'graphic design',
      'visual design',
      'ui components',
      'after effects',
      'bitmap halftone',
      'midjourney art',
      'visual storytelling',
      'advertising strategy',
      'creative formats',
    ])) {
      return design;
    }
    if (_hasAny(strongText, const [
      'artificial intelligence',
      'ai coding',
      'ai security',
      'ai agents',
      'coding agent',
      'software',
      'github',
      'react development',
      'nginx',
      'database access',
      'robotics',
      'geotiff',
    ])) {
      return software;
    }
    if (_hasAny(strongText, const [
      'quantum physics',
      'quantum teleportation',
      'dna repair',
      'cell biology',
      'knot theory',
      'mathematical applications',
    ])) {
      return science;
    }
    return null;
  }

  static bool isMovieWatchRecommendation(SavedUrl url) {
    return _isMovieWatchRecommendation(url, _enrichmentEvidence(url));
  }

  static bool _isMovieWatchRecommendation(
    SavedUrl url,
    _EnrichmentEvidence enrichment, {
    String? primaryIntent,
  }) {
    primaryIntent ??= MemoryIntentResolver.fromUrl(
      url,
    )?.primaryIntent.trim().toLowerCase();
    final text = _normalize(
      [url.title, url.tags.join(' '), enrichment.topics.join(' ')].join(' '),
    );
    final hasMovieSubject =
        enrichment.mentionTypes.contains('movie') ||
        _hasAny(text, const [
          'movie',
          'movies',
          'film',
          'films',
          'cinema',
          'thriller',
        ]);
    if (!hasMovieSubject) return false;

    final userQueuedToWatch = url.intentAction == 'watch_later';
    final explicitRecommendation = _hasAny(_normalize(url.title), const [
      'movie recommendation',
      'movie recommendations',
      'film recommendation',
      'film recommendations',
      'recommended family films',
      'films to watch',
      'movies to watch',
      'watchlist',
      'best plot twists',
    ]);
    return primaryIntent == 'watch_later' ||
        userQueuedToWatch ||
        explicitRecommendation;
  }

  static SavedUrlSubject? dominantSubject(Iterable<SavedUrl> urls) {
    return SavedUrlSubjectIndex().dominantSubject(urls);
  }

  static List<SavedUrl> coherentCore(Iterable<SavedUrl> urls) {
    return SavedUrlSubjectIndex().coherentCore(urls);
  }
}

class _EnrichmentEvidence {
  const _EnrichmentEvidence({
    required this.contentType,
    required this.hasRecipe,
    required this.topics,
    required this.mentionTypes,
  });

  final String contentType;
  final bool hasRecipe;
  final List<String> topics;
  final Set<String> mentionTypes;
}

_EnrichmentEvidence _enrichmentEvidence(SavedUrl url) {
  final raw = url.enrichmentJson;
  if (raw == null || raw.trim().isEmpty) {
    return const _EnrichmentEvidence(
      contentType: '',
      hasRecipe: false,
      topics: [],
      mentionTypes: {},
    );
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException();
    final topics = decoded['topics'] is List
        ? (decoded['topics'] as List)
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
        : const <String>[];
    final mentions = decoded['mentions'] is List
        ? (decoded['mentions'] as List)
              .whereType<Map>()
              .map((item) => item['type']?.toString().trim().toLowerCase())
              .whereType<String>()
              .where((item) => item.isNotEmpty)
              .toSet()
        : const <String>{};
    return _EnrichmentEvidence(
      contentType: (decoded['content_type'] ?? decoded['contentType'] ?? '')
          .toString()
          .trim()
          .toLowerCase(),
      hasRecipe: decoded['recipe'] != null,
      topics: topics,
      mentionTypes: mentions,
    );
  } catch (_) {
    return const _EnrichmentEvidence(
      contentType: '',
      hasRecipe: false,
      topics: [],
      mentionTypes: {},
    );
  }
}

final RegExp _nonAlphaNumeric = RegExp(r'[^a-z0-9]+');
final RegExp _whitespace = RegExp(r'\s+');
final Map<String, String> _normalizedPhrases = {};

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(_nonAlphaNumeric, ' ')
    .replaceAll(_whitespace, ' ')
    .trim();

bool _hasAny(String normalizedText, Iterable<String> phrases) {
  final padded = ' $normalizedText ';
  for (final phrase in phrases) {
    final normalizedPhrase = _normalizedPhrases.putIfAbsent(
      phrase,
      () => _normalize(phrase),
    );
    if (normalizedPhrase.isNotEmpty && padded.contains(' $normalizedPhrase ')) {
      return true;
    }
  }
  return false;
}
