import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tag_noise_filter.dart';
import 'text_cleaner.dart';

class TranscriptEnrichmentResult {
  const TranscriptEnrichmentResult({
    required this.meaningfulTitle,
    required this.summary,
    required this.category,
    required this.tags,
    this.mentions = const [],
    this.recipe,
    this.keyPoints = const [],
    this.thumbnailUrl,
    this.creator,
    this.caption,
    this.transcript,
    this.likeCount,
    this.commentCount,
  });

  final String meaningfulTitle;
  final String summary;
  final String category;
  final List<String> tags;
  final List<EnrichedMention> mentions;
  final EnrichedRecipe? recipe;
  final List<String> keyPoints;
  final String? thumbnailUrl;
  final String? creator;
  final String? caption;
  final String? transcript;
  final int? likeCount;
  final int? commentCount;

  bool get hasUsefulContent =>
      meaningfulTitle.trim().isNotEmpty ||
      summary.trim().isNotEmpty ||
      tags.isNotEmpty ||
      mentions.isNotEmpty ||
      (recipe?.hasUsefulContent ?? false) ||
      (transcript?.trim().isNotEmpty ?? false);

  Map<String, dynamic> toJson() {
    return {
      'meaningful_title': meaningfulTitle,
      'summary': summary,
      'category': category,
      'tags': tags,
      'mentions': mentions.map((item) => item.toJson()).toList(),
      'recipe': recipe?.toJson(),
      'key_points': keyPoints,
      'thumbnail_url': thumbnailUrl,
      'creator': creator,
      'caption': caption,
      'transcript': transcript,
      'like_count': likeCount,
      'comment_count': commentCount,
    };
  }

  static TranscriptEnrichmentResult? fromJson(Map<String, dynamic> json) {
    final mentions = json['mentions'];
    return TranscriptEnrichmentResult(
      meaningfulTitle: TranscriptEnrichmentService._cleanText(
        json['meaningful_title'],
      ),
      summary: TranscriptEnrichmentService._cleanText(json['summary']),
      category: TranscriptEnrichmentService._cleanText(json['category']),
      tags: TagNoiseFilter.filterTags(
        TranscriptEnrichmentService._extractStringList(json['tags']),
      ),
      mentions: mentions is List
          ? mentions
              .map((item) => item is Map
                  ? EnrichedMention.fromJson(Map<String, dynamic>.from(item))
                  : null)
              .whereType<EnrichedMention>()
              .toList()
          : const [],
      recipe: EnrichedRecipe.fromJsonOrNull(json['recipe']),
      keyPoints: TranscriptEnrichmentService._extractStringList(
        json['key_points'],
      ),
      thumbnailUrl: TranscriptEnrichmentService._cleanNullableText(
        json['thumbnail_url'],
      ),
      creator: TranscriptEnrichmentService._cleanNullableText(json['creator']),
      caption: TranscriptEnrichmentService._cleanNullableText(json['caption']),
      transcript: TranscriptEnrichmentService._cleanNullableText(
        json['transcript'],
      ),
      likeCount: TranscriptEnrichmentService._extractPositiveInt(
        json['like_count'],
      ),
      commentCount: TranscriptEnrichmentService._extractPositiveInt(
        json['comment_count'],
      ),
    );
  }
}

class EnrichedRecipe {
  const EnrichedRecipe({
    required this.title,
    this.image,
    this.category,
    this.cuisine,
    this.ingredients = const [],
    this.instructions,
    this.prepTime,
  });

  final String title;
  final String? image;
  final String? category;
  final String? cuisine;
  final List<EnrichedRecipeIngredient> ingredients;
  final String? instructions;
  final String? prepTime;

  bool get hasUsefulContent =>
      title.trim().isNotEmpty ||
      ingredients.isNotEmpty ||
      (instructions?.trim().isNotEmpty ?? false);

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'image': image,
      'category': category,
      'cuisine': cuisine,
      'ingredients': ingredients.map((item) => item.toJson()).toList(),
      'instructions': instructions,
      'prep_time': prepTime,
    };
  }

  static EnrichedRecipe? fromJsonOrNull(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final ingredients = _parseIngredients(json['ingredients']);
    final steps = TranscriptEnrichmentService._extractStringList(json['steps']);
    final instructions = TranscriptEnrichmentService._cleanNullableText(
      json['instructions'],
    ) ?? (steps.isNotEmpty ? steps.join('\n') : null);
    final recipe = EnrichedRecipe(
      title: TranscriptEnrichmentService._cleanText(json['title'] ?? json['name']),
      image: TranscriptEnrichmentService._cleanNullableText(
        json['image'] ?? json['thumbnail'] ?? json['thumbnail_url'],
      ),
      category: TranscriptEnrichmentService._cleanNullableText(json['category']),
      cuisine: TranscriptEnrichmentService._cleanNullableText(
        json['cuisine'] ?? json['area'],
      ),
      ingredients: ingredients,
      instructions: instructions,
      prepTime: TranscriptEnrichmentService._cleanNullableText(
        json['prep_time'] ?? json['prepTime'],
      ),
    );
    return recipe.hasUsefulContent ? recipe : null;
  }

  static List<EnrichedRecipeIngredient> _parseIngredients(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((item) {
          if (item is String) {
            return EnrichedRecipeIngredient(
              name: TranscriptEnrichmentService._cleanText(item),
            );
          }
          if (item is Map) {
            final json = Map<String, dynamic>.from(item);
            return EnrichedRecipeIngredient(
              name: TranscriptEnrichmentService._cleanText(
                json['name'] ?? json['ingredient'] ?? json['title'],
              ),
              measure: TranscriptEnrichmentService._cleanNullableText(
                json['measure'] ?? json['measurement'] ?? json['amount'],
              ),
            );
          }
          return null;
        })
        .whereType<EnrichedRecipeIngredient>()
        .where((item) => item.name.isNotEmpty)
        .take(30)
        .toList();
  }
}

class EnrichedRecipeIngredient {
  const EnrichedRecipeIngredient({
    required this.name,
    this.measure,
  });

  final String name;
  final String? measure;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'measure': measure,
    };
  }
}

class EnrichedMention {
  const EnrichedMention({
    required this.title,
    required this.type,
    this.year,
    this.whyMentioned,
    this.posterUrl,
  });

  final String title;
  final String type;
  final String? year;
  final String? whyMentioned;
  final String? posterUrl;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'type': type,
      'year': year,
      'why_mentioned': whyMentioned,
      'poster_url': posterUrl,
    };
  }

  static EnrichedMention fromJson(Map<String, dynamic> json) {
    return EnrichedMention(
      title: TranscriptEnrichmentService._cleanText(json['title']),
      type: TranscriptEnrichmentService._cleanText(json['type']).isEmpty
          ? 'other'
          : TranscriptEnrichmentService._cleanText(json['type']).toLowerCase(),
      year: TranscriptEnrichmentService._cleanNullableText(json['year']),
      whyMentioned: TranscriptEnrichmentService._cleanNullableText(
        json['why_mentioned'],
      ),
      posterUrl: TranscriptEnrichmentService._cleanNullableText(
        json['poster_url'],
      ),
    );
  }
}

class TranscriptEnrichmentService {
  TranscriptEnrichmentService({Dio? dio}) : _dio = dio ?? _defaultDio();

  static const _defaultBaseUrl =
      'https://glimpse-enrichment-backend.glimpse.workers.dev';
  static const baseUrlOverride =
      String.fromEnvironment('GLIMPSE_ENRICHMENT_BASE_URL');

  static String get baseUrl =>
      baseUrlOverride.isEmpty ? _defaultBaseUrl : baseUrlOverride;

  final Dio _dio;
  static final Map<String, TranscriptEnrichmentResult> _memoryCache = {};
  static const _cachePrefix = 'transcript_enrichment_v4_';

  static Dio _defaultDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 10),
        headers: const {'Content-Type': 'application/json'},
        responseType: ResponseType.json,
      ),
    );
  }

  static bool supportsUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    final normalizedHost =
        host.startsWith('www.') ? host.substring(4) : host;
    if ((normalizedHost == 'instagram.com' ||
            normalizedHost.endsWith('.instagram.com')) &&
        RegExp(r'/(reel|reels|p)/').hasMatch(uri.path)) {
      return true;
    }
    if (normalizedHost == 'tiktok.com' ||
        normalizedHost.endsWith('.tiktok.com')) {
      return RegExp(r'/@[^/]+/video/\d+').hasMatch(uri.path);
    }
    if (normalizedHost == 'youtu.be') return uri.pathSegments.isNotEmpty;
    if (normalizedHost == 'youtube.com' ||
        normalizedHost.endsWith('.youtube.com') ||
        normalizedHost == 'youtube-nocookie.com' ||
        normalizedHost.endsWith('.youtube-nocookie.com')) {
      return uri.queryParameters['v']?.isNotEmpty == true ||
          RegExp(r'^/(shorts|embed)/[^/]+').hasMatch(uri.path);
    }
    return false;
  }

  /// Reads only local transcript enrichment cache. This never calls the backend.
  static Future<TranscriptEnrichmentResult?> cachedResultForUrl(
    String rawUrl,
  ) async {
    final cacheKey = _cacheKeyForUrl(rawUrl);
    final cached = _memoryCache[cacheKey];
    if (cached != null) return cached;
    final persisted = await _readPersisted(cacheKey);
    if (persisted != null) {
      _memoryCache[cacheKey] = persisted;
    }
    return persisted;
  }

  Future<TranscriptEnrichmentResult?> enrichUrl({
    required String rawUrl,
    required String title,
    required String description,
    required String? thumbnailUrl,
    required String domain,
  }) async {
    if (!supportsUrl(rawUrl)) return null;
    final cacheKey = _cacheKeyForUrl(rawUrl);
    final cached = _memoryCache[cacheKey];
    if (cached != null) return cached;
    final persisted = await _readPersisted(cacheKey);
    if (persisted != null) {
      _memoryCache[cacheKey] = persisted;
      return persisted;
    }

    try {
      final endpoint = Uri.parse(baseUrl).resolve('enrich-url').toString();
      final response = await _dio.post<dynamic>(
        endpoint,
        data: {
          'url': rawUrl,
          'title': title,
          'description': description,
          'thumbnailUrl': thumbnailUrl,
          'domain': domain,
        },
        options: Options(validateStatus: (_) => true),
      );

      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        developer.log(
          'Transcript enrichment HTTP $status: ${response.data}',
          name: 'TranscriptEnrichment',
        );
        return null;
      }

      final data = _asMap(response.data);
      if (data == null) return null;

      final mentions = _extractMentions(data);
      final mentionTitles = mentions
          .map((item) => TagNoiseFilter.cleanTag(item.title))
          .where((item) => item.isNotEmpty)
          .toSet();
      final tags = TagNoiseFilter.filterTags(_extractTags(data))
          .where((tag) => !mentionTitles.contains(TagNoiseFilter.cleanTag(tag)))
          .toList();
      final usefulTags = _ensureUsefulTags(
        tags,
        data,
        hasMovieMentions: mentions.any((item) => item.type == 'movie'),
        hasRecipe: EnrichedRecipe.fromJsonOrNull(data['recipe']) != null,
      ).take(8).toList();

      final result = TranscriptEnrichmentResult(
        meaningfulTitle: _cleanText(data['meaningful_title']),
        summary: _cleanText(data['summary']),
        category: _cleanText(data['category']),
        tags: usefulTags,
        mentions: mentions,
        recipe: EnrichedRecipe.fromJsonOrNull(data['recipe']),
        keyPoints: _extractStringList(data['key_points']),
        thumbnailUrl: _cleanText(data['thumbnail_url']).isNotEmpty
            ? _cleanText(data['thumbnail_url'])
            : null,
        creator: _cleanText(data['creator']).isNotEmpty
            ? _cleanText(data['creator'])
            : null,
        caption: _cleanText(data['caption']).isNotEmpty
            ? _cleanText(data['caption'])
            : null,
        transcript: _cleanText(data['transcript']).isNotEmpty
            ? _cleanText(data['transcript'])
            : null,
        likeCount: _extractPositiveInt(data['like_count']),
        commentCount: _extractPositiveInt(data['comment_count']),
      );

      if (!result.hasUsefulContent) return null;
      _memoryCache[cacheKey] = result;
      await _writePersisted(cacheKey, result);
      return result;
    } catch (e, st) {
      developer.log(
        'Transcript enrichment failed for $rawUrl: $e',
        name: 'TranscriptEnrichment',
        stackTrace: st,
      );
      return null;
    }
  }

  static Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  static List<String> _extractTags(Map<String, dynamic> data) {
    final raw = data['tags'];
    if (raw is! List) return const [];
    return raw.map((item) => _cleanText(item)).where((item) => item.isNotEmpty).toList();
  }

  static List<EnrichedMention> _extractMentions(Map<String, dynamic> data) {
    final byKey = <String, EnrichedMention>{};
    final books = data['books'];
    if (books is List) {
      for (final item in books) {
        if (item is! Map) continue;
        final title = _cleanText(item['title']);
        if (title.isEmpty) continue;
        byKey[_mentionKey(title)] = EnrichedMention(
          title: title,
          type: 'book',
          whyMentioned: _cleanNullableText(
            item['why_mentioned'] ?? item['reason'] ?? item['description'],
          ),
          posterUrl: _cleanNullableText(item['cover_url'] ?? item['coverUrl']),
        );
      }
    }
    final movies = data['movies'];
    if (movies is List) {
      for (final item in movies) {
        if (item is! Map) continue;
        final title = _cleanText(item['title']);
        if (title.isEmpty) continue;
        byKey[_mentionKey(title)] = EnrichedMention(
          title: title,
          type: 'movie',
          year: _cleanNullableText(item['year']),
          whyMentioned: _cleanNullableText(
            item['why_mentioned'] ?? item['reason'] ?? item['description'],
          ),
          posterUrl: _cleanNullableText(item['poster_url'] ?? item['posterUrl']),
        );
      }
    }
    final entities = data['entities'];
    if (entities is List) {
      for (final item in entities) {
        if (item is! Map) continue;
        final type = _cleanText(item['type']).toLowerCase();
        if (type != 'movie' &&
            type != 'book' &&
            type != 'place' &&
            type != 'product' &&
            type != 'person') {
          continue;
        }
        final title = _cleanText(item['name'] ?? item['title']);
        if (title.isEmpty) continue;
        final key = _mentionKey(title);
        byKey.putIfAbsent(
          key,
          () => EnrichedMention(
            title: title,
            type: type,
            whyMentioned: _cleanNullableText(item['why_mentioned'] ?? item['reason']),
          ),
        );
      }
    }
    return byKey.values.take(20).toList();
  }

  static List<String> _extractStringList(Object? raw) {
    if (raw is! List) return const [];
    return raw.map((item) => _cleanText(item)).where((item) => item.isNotEmpty).toList();
  }

  static List<String> _ensureUsefulTags(
    List<String> tags,
    Map<String, dynamic> data, {
    required bool hasMovieMentions,
    required bool hasRecipe,
  }) {
    final out = <String>[...tags];
    final haystack = [
      data['meaningful_title'],
      data['summary'],
      data['category'],
      data['transcript'],
      data['caption'],
    ].map(_cleanText).join(' ').toLowerCase();
    void add(String tag) {
      final clean = TagNoiseFilter.cleanTag(tag);
      if (clean.isNotEmpty && !TagNoiseFilter.isNoiseTag(clean) && !out.contains(clean)) {
        out.add(clean);
      }
    }

    if (hasMovieMentions || haystack.contains('movie') || haystack.contains('film')) {
      add('movie recommendations');
      if (haystack.contains('sci-fi') || haystack.contains('science fiction')) {
        add('sci-fi movies');
      }
      if (haystack.contains('mind-bending') || haystack.contains('time travel')) {
        add('mind-bending films');
      }
    }
    if (hasRecipe || haystack.contains('recipe') || haystack.contains('cook')) {
      add('recipe');
      if (haystack.contains('protein')) add('protein recipes');
      if (haystack.contains('vegan')) add('vegan recipes');
      if (haystack.contains('meal prep')) add('meal prep');
    }
    return TagNoiseFilter.filterTags(out);
  }

  static String _cleanText(Object? raw) {
    return TextCleaner.cleanLoose(raw);
  }

  static String? _cleanNullableText(Object? raw) {
    final text = _cleanText(raw);
    return text.isEmpty ? null : text;
  }

  static int? _extractPositiveInt(Object? raw) {
    if (raw is int && raw > 0) return raw;
    if (raw is num && raw > 0) return raw.round();
    final text = _cleanText(raw).replaceAll(',', '');
    final value = double.tryParse(text);
    if (value == null || value <= 0) return null;
    return value.round();
  }

  static String _cacheKeyForUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return rawUrl.trim();
    var host = uri.host.toLowerCase();
    if (host.startsWith('www.')) host = host.substring(4);

    if (host == 'youtu.be') {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (id.isNotEmpty) return 'https://www.youtube.com/watch?v=$id';
    }
    if (host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtube-nocookie.com' ||
        host.endsWith('.youtube-nocookie.com')) {
      final segments = uri.pathSegments.where((item) => item.isNotEmpty).toList();
      String? id;
      if (segments.isNotEmpty && segments.first == 'shorts' && segments.length >= 2) {
        id = segments[1];
      } else if (segments.isNotEmpty && segments.first == 'embed' && segments.length >= 2) {
        id = segments[1];
      } else {
        id = uri.queryParameters['v'];
      }
      if (id != null && id.isNotEmpty) {
        return 'https://www.youtube.com/watch?v=$id';
      }
    }
    if (host == 'instagram.com' || host.endsWith('.instagram.com') || host == 'instagr.am') {
      final segments = uri.pathSegments.where((item) => item.isNotEmpty).toList();
      if (segments.length >= 2 &&
          {'reel', 'reels', 'p', 'tv'}.contains(segments.first.toLowerCase())) {
        return 'https://www.instagram.com/${segments.first}/${segments[1]}/';
      }
    }
    if (host == 'tiktok.com' || host.endsWith('.tiktok.com')) {
      final segments = uri.pathSegments.where((item) => item.isNotEmpty).toList();
      final videoIndex = segments.indexWhere((item) => item.toLowerCase() == 'video');
      if (videoIndex > 0 && videoIndex + 1 < segments.length) {
        return 'https://www.tiktok.com/${segments[videoIndex - 1]}/video/${segments[videoIndex + 1]}';
      }
    }
    return uri.replace(fragment: '', query: '').toString();
  }

  static String _mentionKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static Future<TranscriptEnrichmentResult?> _readPersisted(String rawUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefix$rawUrl');
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final result = TranscriptEnrichmentResult.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return result?.hasUsefulContent == true ? result : null;
    } catch (e, st) {
      developer.log(
        'Transcript enrichment cache read failed: $e',
        name: 'TranscriptEnrichment',
        stackTrace: st,
      );
      return null;
    }
  }

  static Future<void> _writePersisted(
    String rawUrl,
    TranscriptEnrichmentResult result,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cachePrefix$rawUrl', jsonEncode(result.toJson()));
    } catch (e, st) {
      developer.log(
        'Transcript enrichment cache write failed: $e',
        name: 'TranscriptEnrichment',
        stackTrace: st,
      );
    }
  }
}
