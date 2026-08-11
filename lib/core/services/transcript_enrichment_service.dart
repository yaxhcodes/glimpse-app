import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import 'ai/ai_transport.dart';
import 'tag_noise_filter.dart';
import 'text_cleaner.dart';

part 'transcript_enrichment_models.dart';

bool hasMovieRecommendationIntentForEnrichment(
  Map<String, dynamic> data, {
  required bool hasMovieMentions,
}) {
  final rawIntent = data['memory_intent'];
  final primaryIntent = rawIntent is Map
      ? TextCleaner.cleanLoose(rawIntent['primary_intent']).toLowerCase()
      : TextCleaner.cleanLoose(data['primary_intent']).toLowerCase();
  final recommendationText = [
    data['meaningful_title'],
    data['summary'],
    if (data['topics'] is List) ...(data['topics'] as List),
  ].map(TextCleaner.cleanLoose).join(' ').toLowerCase();
  final hasMovieSubject = RegExp(
    r'\b(movie|movies|film|films|cinema)\b',
  ).hasMatch(recommendationText);
  if (primaryIntent == 'watch_later') {
    return hasMovieMentions || hasMovieSubject;
  }
  final hasExplicitRecommendation = RegExp(
    r'\b(movie|movies|film|films|cinema)\b.{0,40}'
    r'\b(recommend|recommendation|recommendations|watchlist|must watch|to watch)\b|'
    r'\b(recommend|recommendation|recommendations|watchlist|must watch|to watch)\b'
    r'.{0,40}\b(movie|movies|film|films|cinema)\b',
  ).hasMatch(recommendationText);
  return hasMovieMentions && hasExplicitRecommendation;
}

class TranscriptEnrichmentService {
  TranscriptEnrichmentService({AiTransport? transport})
    : _transport = transport ?? AiTransport.instance;

  final AiTransport _transport;
  static final Map<String, TranscriptEnrichmentResult> _memoryCache = {};
  static const _cachePrefix = 'transcript_enrichment_v5_';

  static bool supportsUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    final normalizedHost = host.startsWith('www.') ? host.substring(4) : host;
    // Must stay in lockstep with the Worker's isInstagramReelUrl
    // (services/shared.ts). Any media URL the Worker will send to Apify must
    // also be treated as "supported" here, otherwise the client routes it to
    // the generic Gemini fallback and saves caption-only metadata as READY.
    if ((normalizedHost == 'instagram.com' ||
            normalizedHost.endsWith('.instagram.com') ||
            normalizedHost == 'instagr.am') &&
        RegExp(r'/(reel|reels|p|tv|share)/').hasMatch(uri.path)) {
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
    if (_isAcceptableCachedResult(rawUrl, cached)) return cached;
    if (cached != null) _memoryCache.remove(cacheKey);
    final persisted = await _readPersisted(cacheKey);
    if (persisted != null) {
      if (_isAcceptableCachedResult(rawUrl, persisted)) {
        _memoryCache[cacheKey] = persisted;
        return persisted;
      }
      await _removePersisted(cacheKey);
    }
    return null;
  }

  Future<TranscriptEnrichmentResult?> enrichUrl({
    required String rawUrl,
    required String title,
    required String description,
    required String? thumbnailUrl,
    required String domain,
    String? saveId,
    String? processingId,
    int attempt = 1,
    bool forceRefresh = false,
  }) async {
    if (!supportsUrl(rawUrl)) return null;
    final cacheKey = _cacheKeyForUrl(rawUrl);
    if (forceRefresh) {
      _memoryCache.remove(cacheKey);
      await _removePersisted(cacheKey);
    }
    final cached = _memoryCache[cacheKey];
    if (!forceRefresh && _isAcceptableCachedResult(rawUrl, cached)) {
      return cached;
    }
    if (cached != null) _memoryCache.remove(cacheKey);
    final persisted = await _readPersisted(cacheKey);
    if (!forceRefresh && persisted != null) {
      if (_isAcceptableCachedResult(rawUrl, persisted)) {
        _memoryCache[cacheKey] = persisted;
        return persisted;
      }
      await _removePersisted(cacheKey);
    }

    try {
      final requestData = <String, dynamic>{
        'url': rawUrl,
        'attempt': attempt,
        'title': title,
        'description': description,
        'thumbnailUrl': thumbnailUrl,
        'domain': domain,
      };
      if (saveId != null) requestData['save_id'] = saveId;
      if (processingId != null) requestData['processing_id'] = processingId;
      final data = await _transport.postEnrichment(body: requestData);

      final mentions = _extractMentions(data);
      final recipe = EnrichedRecipe.fromJsonOrNull(data['recipe']);
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
        hasRecipe: recipe != null,
      ).take(8).toList();

      final result = TranscriptEnrichmentResult(
        schemaVersion:
            _extractPositiveInt(
              data['schema_version'] ?? data['schemaVersion'],
            ) ??
            1,
        meaningfulTitle: _cleanText(data['meaningful_title']),
        summary: _cleanText(data['summary']),
        category: _cleanText(data['category']),
        tags: usefulTags,
        contentType: recipe != null ? 'recipe' : _contentTypeFromJson(data),
        brief: _cleanNullableText(
          data['brief'] ??
              data['short_description'] ??
              data['content_description'],
        ),
        steps: _extractContentSteps(data),
        mentions: mentions,
        recipe: recipe,
        keyPoints: _extractStringList(data['key_points']),
        notableItems: _extractNotableItems(data),
        contentSections: _extractContentSections(data),
        categoryEvidence: _cleanNullableText(
          data['category_evidence'] ?? data['domain_evidence'],
        ),
        categoryConfidence: _toDouble(
          data['category_confidence'] ??
              data['domain_confidence'] ??
              data['confidence'],
        ),
        topics: _extractStringList(data['topics']),
        categoryNeedsReview:
            data['category_needs_review'] == true ||
            data['domain_needs_review'] == true,
        originalGeminiCategory: _cleanNullableText(
          data['original_gemini_category'] ?? data['original_gemini_domain'],
        ),
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
        ocrText: _cleanText(data['ocr_text'] ?? data['ocrText']).isNotEmpty
            ? _cleanText(data['ocr_text'] ?? data['ocrText'])
            : null,
        likeCount: _extractPositiveInt(data['like_count']),
        commentCount: _extractPositiveInt(data['comment_count']),
        imageUrls: _extractStringList(
          data['image_urls'] ?? data['imageUrls'] ?? data['images'],
        ),
        firstComment:
            _cleanText(data['first_comment'] ?? data['firstComment']).isNotEmpty
            ? _cleanText(data['first_comment'] ?? data['firstComment'])
            : null,
        latestComments: _extractStringList(
          data['latest_comments'] ?? data['latestComments'],
        ),
        memoryIntent: MemoryIntentMetadata.fromJsonOrNull(
          data['memory_intent'] ?? data,
        ),
      );

      if (!result.hasUsefulContent ||
          (supportsUrl(rawUrl) &&
              (!result.hasReliableMediaEvidence ||
                  !result.hasStructuredEnrichment))) {
        throw const TranscriptEnrichmentException(
          'backend_returned_low_quality_evidence',
        );
      }
      _memoryCache[cacheKey] = result;
      await _writePersisted(cacheKey, result);
      return result;
    } on TranscriptEnrichmentException {
      rethrow;
    } on AiTransportException catch (error) {
      throw TranscriptEnrichmentException(
        'backend_http_${error.statusCode ?? 0}',
        statusCode: error.statusCode,
        retryable: error.isRetryable,
      );
    } catch (e, st) {
      developer.log(
        'Transcript enrichment failed: ${e.runtimeType}',
        name: 'TranscriptEnrichment',
        stackTrace: st,
      );
      throw TranscriptEnrichmentException(e.toString());
    }
  }

  static bool _isAcceptableCachedResult(
    String rawUrl,
    TranscriptEnrichmentResult? result,
  ) {
    if (result == null || !result.hasUsefulContent) return false;
    if (supportsUrl(rawUrl) &&
        (!result.hasReliableMediaEvidence || !result.hasStructuredEnrichment)) {
      return false;
    }
    return true;
  }

  static List<EnrichedContentStep> _extractContentSteps(
    Map<String, dynamic> data,
  ) {
    final raw = data['steps'] ?? data['key_steps'] ?? data['takeaways'];
    final parsed = _parseContentSteps(raw);
    if (parsed.isNotEmpty) return parsed;

    final keyPoints = data['key_points'];
    return _parseContentSteps(keyPoints);
  }

  static List<EnrichedNotableItem> _extractNotableItems(
    Map<String, dynamic> data,
  ) {
    final raw =
        data['notable_items'] ??
        data['notableItems'] ??
        data['highlight_items'] ??
        data['highlights'];
    if (raw is! List) return const [];
    final seen = <String>{};
    return raw
        .map((item) {
          if (item is String) {
            final text = _cleanText(item);
            if (text.isEmpty) return null;
            return EnrichedNotableItem(text: text, type: 'quote');
          }
          if (item is Map) {
            return EnrichedNotableItem.fromJson(
              Map<String, dynamic>.from(item),
            );
          }
          return null;
        })
        .whereType<EnrichedNotableItem>()
        .where((item) => item.hasUsefulContent)
        .where((item) {
          final key = _cleanText(item.text).toLowerCase();
          if (seen.contains(key)) return false;
          seen.add(key);
          return true;
        })
        .take(12)
        .toList();
  }

  static List<EnrichedContentSection> _extractContentSections(
    Map<String, dynamic> data,
  ) {
    final raw = data['content_sections'] ?? data['contentSections'];
    if (raw is! List) return const [];
    final seenTitles = <String>{};
    final seenPoints = <String>{};
    var totalPoints = 0;
    final sections = <EnrichedContentSection>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final parsed = EnrichedContentSection.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (parsed == null) continue;
      final titleKey = _cleanText(parsed.title).toLowerCase();
      if (!seenTitles.add(titleKey)) continue;
      final points = <String>[];
      for (final point in parsed.points) {
        final key = _cleanText(point).toLowerCase();
        if (key.isEmpty || !seenPoints.add(key)) continue;
        points.add(point);
        totalPoints++;
        if (points.length >= 6 || totalPoints >= 32) break;
      }
      if (points.isNotEmpty) {
        sections.add(
          EnrichedContentSection(title: parsed.title, points: points),
        );
      }
      if (sections.length >= 8 || totalPoints >= 32) break;
    }
    return sections;
  }

  static List<EnrichedContentStep> _parseContentSteps(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((item) {
          if (item is String) {
            final text = _cleanText(item);
            if (text.isEmpty) return null;
            final split = _splitStepTitle(text);
            return EnrichedContentStep(title: split.$1, description: split.$2);
          }
          if (item is Map) {
            final json = Map<String, dynamic>.from(item);
            final title = _cleanText(
              json['title'] ??
                  json['label'] ??
                  json['step'] ??
                  json['name'] ??
                  json['point'],
            );
            final description = _cleanNullableText(
              json['description'] ??
                  json['summary'] ??
                  json['detail'] ??
                  json['why'],
            );
            if (title.isEmpty && (description ?? '').isEmpty) return null;
            if (title.isEmpty) {
              final split = _splitStepTitle(description!);
              return EnrichedContentStep(
                title: split.$1,
                description: split.$2,
              );
            }
            return EnrichedContentStep(title: title, description: description);
          }
          return null;
        })
        .whereType<EnrichedContentStep>()
        .where((item) => item.hasUsefulContent)
        .take(12)
        .toList();
  }

  static (String, String?) _splitStepTitle(String text) {
    final cleaned = _cleanText(text);
    final index = cleaned.indexOf(':');
    if (index > 2 && index <= 48) {
      final title = cleaned.substring(0, index).trim();
      final description = cleaned.substring(index + 1).trim();
      return (title, description.isEmpty ? null : description);
    }
    return (cleaned, null);
  }

  static List<String> _extractTags(Map<String, dynamic> data) {
    final raw = data['tags'];
    if (raw is! List) return const [];
    return raw
        .map((item) => _cleanText(item))
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<EnrichedMention> _extractMentions(Map<String, dynamic> data) {
    final byKey = <String, EnrichedMention>{};
    final mentions = data['mentions'];
    if (mentions is List) {
      for (final item in mentions) {
        if (item is! Map) continue;
        final mention = EnrichedMention.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (mention.title.isEmpty) continue;
        byKey[_mentionIdentityKey(mention.type, mention.title)] = mention;
      }
    }
    final books = data['books'];
    if (books is List) {
      for (final item in books) {
        if (item is! Map) continue;
        final title = _cleanText(item['title']);
        if (title.isEmpty) continue;
        byKey.putIfAbsent(
          _mentionIdentityKey('book', title),
          () => EnrichedMention(
            title: title,
            type: 'book',
            subtype: 'book',
            creator: _cleanNullableText(item['author'] ?? item['creator']),
            year: _cleanNullableText(
              item['year'] ?? item['first_publish_year'],
            ),
            whyMentioned: _cleanNullableText(
              item['why_mentioned'] ?? item['reason'] ?? item['description'],
            ),
            posterUrl: _cleanNullableText(
              item['cover_url'] ?? item['coverUrl'],
            ),
            genres: _extractGenreList(item['genres'] ?? item['genre']),
            rawGenres: _extractGenreList(
              item['raw_genres'] ?? item['rawGenres'] ?? item['subjects'],
            ),
            catalogId: _cleanNullableText(
              item['catalog_id'] ?? item['catalogId'] ?? item['work_id'],
            ),
            catalogSource: _cleanNullableText(
              item['catalog_source'] ?? item['catalogSource'],
            ),
            matchConfidence: _toDouble(
              item['match_confidence'] ?? item['matchConfidence'],
            ),
          ),
        );
      }
    }
    final movies = data['movies'];
    if (movies is List) {
      for (final item in movies) {
        if (item is! Map) continue;
        final title = _cleanText(item['title']);
        if (title.isEmpty) continue;
        final subtype = _cleanNullableText(item['subtype'] ?? item['type']);
        byKey.putIfAbsent(
          _mentionIdentityKey('movie', title),
          () => EnrichedMention(
            title: title,
            type: 'movie',
            subtype: subtype ?? 'movie',
            creator: _cleanNullableText(item['creator'] ?? item['director']),
            year: _cleanNullableText(item['year']),
            whyMentioned: _cleanNullableText(
              item['why_mentioned'] ?? item['reason'] ?? item['description'],
            ),
            posterUrl: _cleanNullableText(
              item['poster_url'] ?? item['posterUrl'],
            ),
            genres: _extractGenreList(item['genres'] ?? item['genre']),
            rawGenres: _extractGenreList(
              item['raw_genres'] ?? item['rawGenres'],
            ),
            catalogId: _cleanNullableText(
              item['catalog_id'] ?? item['catalogId'] ?? item['tmdb_id'],
            ),
            catalogSource: _cleanNullableText(
              item['catalog_source'] ?? item['catalogSource'],
            ),
            matchConfidence: _toDouble(
              item['match_confidence'] ?? item['matchConfidence'],
            ),
          ),
        );
      }
    }
    final places = data['places'];
    if (places is List) {
      for (final item in places) {
        if (item is! Map) continue;
        final title = _cleanText(item['name'] ?? item['title']);
        if (title.isEmpty) continue;
        final locale = [
          _cleanText(item['city']),
          _cleanText(item['country']),
        ].where((part) => part.isNotEmpty).join(', ');
        byKey.putIfAbsent(
          _mentionIdentityKey('place', title),
          () => EnrichedMention(
            title: title,
            type: 'place',
            subtype: 'place',
            city: _cleanNullableText(item['city']),
            country: _cleanNullableText(item['country']),
            latitude: _toDouble(item['latitude'] ?? item['lat']),
            longitude: _toDouble(
              item['longitude'] ?? item['lon'] ?? item['lng'],
            ),
            catalogId: _cleanNullableText(
              item['catalog_id'] ?? item['catalogId'] ?? item['place_id'],
            ),
            catalogSource: _cleanNullableText(
              item['catalog_source'] ?? item['catalogSource'],
            ),
            matchConfidence: _toDouble(
              item['match_confidence'] ?? item['matchConfidence'],
            ),
            whyMentioned:
                _cleanNullableText(
                  item['why_mentioned'] ??
                      item['reason'] ??
                      item['description'],
                ) ??
                (locale.isEmpty ? null : locale),
          ),
        );
      }
    }
    final entities = data['entities'];
    if (entities is List) {
      for (final item in entities) {
        if (item is! Map) continue;
        final type = _normalizeMentionType(item['type']);
        final title = _cleanText(item['name'] ?? item['title']);
        if (title.isEmpty) continue;
        final key = _mentionIdentityKey(type, title);
        byKey.putIfAbsent(
          key,
          () => EnrichedMention.fromJson({
            ...Map<String, dynamic>.from(item),
            'title': title,
            'type': type,
          }),
        );
      }
    }
    return byKey.values.take(20).toList();
  }

  static String _normalizeMentionType(Object? raw) {
    final type = _cleanText(raw).toLowerCase().replaceAll('-', '_');
    return switch (type) {
      'movie' ||
      'film' ||
      'show' ||
      'series' ||
      'anime' ||
      'documentary' => 'movie',
      'book' || 'novel' => 'book',
      'place' || 'location' || 'destination' => 'place',
      'product' => 'product',
      'app' || 'application' => 'app',
      'person' || 'creator' || 'author' => 'person',
      'game' || 'video_game' || 'mobile_game' => 'game',
      'music' ||
      'song' ||
      'track' ||
      'album' ||
      'artist' ||
      'band' ||
      'musician' => 'music',
      'tool' ||
      'website' ||
      'service' ||
      'platform' ||
      'software' ||
      'repository' => 'tool',
      _ => 'other',
    };
  }

  static List<String> _extractStringList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((item) => _cleanText(item))
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<String> _extractGenreList(Object? raw) {
    final values = raw is List
        ? raw
        : raw is String
        ? raw.split(RegExp(r'[,;/|]'))
        : const <Object?>[];
    final seen = <String>{};
    final genres = <String>[];
    for (final value in values) {
      final cleaned = _cleanText(value);
      if (cleaned.isEmpty) continue;
      final key = cleaned.toLowerCase();
      if (seen.add(key)) genres.add(cleaned);
    }
    return genres.take(12).toList(growable: false);
  }

  static String _contentTypeFromJson(Map<String, dynamic> json) {
    final explicit = _cleanText(
      json['content_type'] ?? json['contentType'],
    ).toLowerCase();
    if (explicit.isNotEmpty) return explicit;
    return EnrichedRecipe.fromJsonOrNull(json['recipe']) != null
        ? 'recipe'
        : 'generic';
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
      if (clean.isNotEmpty &&
          !TagNoiseFilter.isNoiseTag(clean) &&
          !out.contains(clean)) {
        out.add(clean);
      }
    }

    if (hasMovieRecommendationIntentForEnrichment(
      data,
      hasMovieMentions: hasMovieMentions,
    )) {
      add('movie recommendations');
      if (haystack.contains('sci-fi') || haystack.contains('science fiction')) {
        add('sci-fi movies');
      }
      if (haystack.contains('mind-bending') ||
          haystack.contains('time travel')) {
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

  static double? _toDouble(Object? raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    final value = double.tryParse(_cleanText(raw));
    return value;
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
      final segments = uri.pathSegments
          .where((item) => item.isNotEmpty)
          .toList();
      String? id;
      if (segments.isNotEmpty &&
          segments.first == 'shorts' &&
          segments.length >= 2) {
        id = segments[1];
      } else if (segments.isNotEmpty &&
          segments.first == 'embed' &&
          segments.length >= 2) {
        id = segments[1];
      } else {
        id = uri.queryParameters['v'];
      }
      if (id != null && id.isNotEmpty) {
        return 'https://www.youtube.com/watch?v=$id';
      }
    }
    if (host == 'instagram.com' ||
        host.endsWith('.instagram.com') ||
        host == 'instagr.am') {
      final segments = uri.pathSegments
          .where((item) => item.isNotEmpty)
          .toList();
      if (segments.length >= 2 &&
          {'reel', 'reels', 'p', 'tv'}.contains(segments.first.toLowerCase())) {
        return 'https://www.instagram.com/${segments.first}/${segments[1]}/';
      }
    }
    if (host == 'tiktok.com' || host.endsWith('.tiktok.com')) {
      final segments = uri.pathSegments
          .where((item) => item.isNotEmpty)
          .toList();
      final videoIndex = segments.indexWhere(
        (item) => item.toLowerCase() == 'video',
      );
      if (videoIndex > 0 && videoIndex + 1 < segments.length) {
        return 'https://www.tiktok.com/${segments[videoIndex - 1]}/video/${segments[videoIndex + 1]}';
      }
    }
    return uri.replace(fragment: '', query: '').toString();
  }

  static String _mentionKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static String _mentionIdentityKey(String type, String title) =>
      '${_normalizeMentionType(type)}:${_mentionKey(title)}';

  static Future<TranscriptEnrichmentResult?> _readPersisted(
    String rawUrl,
  ) async {
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
      await prefs.setString(
        '$_cachePrefix$rawUrl',
        jsonEncode(result.toJson()),
      );
    } catch (e, st) {
      developer.log(
        'Transcript enrichment cache write failed: $e',
        name: 'TranscriptEnrichment',
        stackTrace: st,
      );
    }
  }

  static Future<void> _removePersisted(String rawUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_cachePrefix$rawUrl');
    } catch (e, st) {
      developer.log(
        'Transcript enrichment cache remove failed: $e',
        name: 'TranscriptEnrichment',
        stackTrace: st,
      );
    }
  }
}
