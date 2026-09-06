import 'dart:convert';
import 'dart:developer' as developer;

import 'package:any_link_preview/any_link_preview.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../utils/network/url_security_validator.dart';
import 'recipe_schema_parser.dart';
import 'source_evidence.dart';
import 'text_cleaner.dart';
import 'transcript_enrichment_service.dart';

/// Metadata extracted from a URL's Open Graph tags.
class LinkMetadata {
  final String title;
  final String description;
  final String? imageUrl;
  final String domain;
  final String? siteName;
  final String? author;
  final EnrichedRecipe? recipe;
  final SourceEvidence? sourceEvidence;

  /// Tags extracted by platform-specific parsers (e.g. Instagram hashtags).
  final List<String>? extractedTags;

  const LinkMetadata({
    required this.title,
    required this.description,
    this.imageUrl,
    required this.domain,
    this.siteName,
    this.author,
    this.recipe,
    this.sourceEvidence,
    this.extractedTags,
  });
}

/// Service for fetching Open Graph metadata from URLs.
class LinkPreviewService {
  final Dio _dio;

  LinkPreviewService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 12),
              sendTimeout: const Duration(seconds: 10),
            ),
          );

  /// Normalise a raw URL to ensure it has a scheme.
  static String normalizeUrl(String url) {
    var trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }
    return canonicalizeUrl(trimmed);
  }

  /// Canonicalises share URLs that otherwise create duplicate saves or cache keys.
  static String canonicalizeUrl(String url) {
    final parsed = Uri.tryParse(url.trim());
    if (parsed == null || !parsed.hasScheme) return url.trim();
    var host = parsed.host.toLowerCase();
    if (host.startsWith('www.')) host = host.substring(4);

    if (host == 'youtu.be') {
      final id = parsed.pathSegments.isNotEmpty
          ? parsed.pathSegments.first
          : '';
      if (id.isNotEmpty) {
        return Uri.https('www.youtube.com', '/watch', {'v': id}).toString();
      }
    }

    if (host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtube-nocookie.com' ||
        host.endsWith('.youtube-nocookie.com')) {
      final segments = parsed.pathSegments
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
        id = parsed.queryParameters['v'];
      }
      if (id != null && id.isNotEmpty) {
        return Uri.https('www.youtube.com', '/watch', {'v': id}).toString();
      }
    }

    if (host == 'instagram.com' ||
        host.endsWith('.instagram.com') ||
        host == 'instagr.am') {
      final segments = parsed.pathSegments
          .where((item) => item.isNotEmpty)
          .toList();
      if (segments.length >= 2 &&
          {'reel', 'reels', 'p', 'tv'}.contains(segments.first.toLowerCase())) {
        return Uri.https(
          'www.instagram.com',
          '/${segments.first}/${segments[1]}/',
        ).toString();
      }
    }

    if (host == 'tiktok.com' || host.endsWith('.tiktok.com')) {
      final segments = parsed.pathSegments
          .where((item) => item.isNotEmpty)
          .toList();
      final videoIndex = segments.indexWhere(
        (item) => item.toLowerCase() == 'video',
      );
      if (videoIndex > 0 && videoIndex + 1 < segments.length) {
        return Uri.https(
          'www.tiktok.com',
          '/${segments[videoIndex - 1]}/video/${segments[videoIndex + 1]}',
        ).toString();
      }
    }

    return parsed.replace(fragment: '', query: '').toString();
  }

  /// Fetches OG metadata for the given [url].
  ///
  /// Tries platform-specific APIs first (Reddit JSON, X oEmbed), then
  /// falls back to OG tag parsing. If all fail, returns the domain as title.
  Future<LinkMetadata> fetchMetadata(String url) async {
    final normalized = normalizeUrl(url);
    final uri = Uri.tryParse(normalized);
    final domain = uri?.host ?? url;
    final host = uri?.host.replaceFirst('www.', '') ?? '';

    if (!await urlSecurityValidator.isSafePublicUrl(normalized)) {
      developer.log(
        'Blocked unsafe preview URL: $normalized',
        name: 'LinkPreview',
      );
      return LinkMetadata(title: domain, description: '', domain: domain);
    }

    // ---- Reddit: use their JSON API ----
    if (host == 'reddit.com' ||
        host.endsWith('.reddit.com') ||
        host == 'redd.it') {
      final result = await _fetchReddit(normalized, domain);
      if (result != null) return result;
    }

    // ---- YouTube: the real video description is in player JSON, not OG tags ----
    if (_isYouTubeHost(host)) {
      final result = await _fetchYouTubeMetadata(normalized, domain);
      if (result != null) return result;
    }

    // ---- Instagram: run cleaning pipeline ----
    // (Also catches instagr.am short links and subdomains)
    final isInstagram =
        host == 'instagram.com' ||
        host.endsWith('.instagram.com') ||
        host == 'instagr.am';

    // ---- Instagram: prefer mobile HTML (richer og:image than Googlebot-only pages) ----
    if (isInstagram) {
      final igMeta = await _fetchInstagramPageMetadata(normalized, domain);
      if (igMeta != null) return igMeta;
    }

    // ---- X / Twitter: use oEmbed endpoint ----
    if (host == 'x.com' ||
        host == 'twitter.com' ||
        host == 'mobile.x.com' ||
        host == 'mobile.twitter.com') {
      final result = await _fetchXEmbed(normalized, domain);
      if (result != null) return result;
    }

    // ---- Manual OG tag parsing via Dio ----
    try {
      final response = await _safeGet(
        normalized,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
          },
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          responseType: ResponseType.plain,
        ),
      );

      final html = response.data?.toString() ?? '';
      var meta = _parseOgTags(html, domain);
      final sourceEvidence = sourceEvidenceFromHtml(html, pageUrl: normalized);
      final recipe = RecipeSchemaParser.parse(
        html,
        pageUrl: normalized,
        fallbackTitle: meta.title,
        fallbackImage: meta.imageUrl,
        fallbackAuthor: meta.author,
      );
      if (recipe != null) {
        meta = LinkMetadata(
          title: recipe.title.isNotEmpty ? recipe.title : meta.title,
          description: recipe.description ?? meta.description,
          imageUrl: recipe.image ?? meta.imageUrl,
          domain: meta.domain,
          siteName: meta.siteName,
          author: recipe.author ?? meta.author,
          recipe: recipe,
          extractedTags: meta.extractedTags,
          sourceEvidence: sourceEvidence.isEmpty ? null : sourceEvidence,
        );
      } else if (!sourceEvidence.isEmpty) {
        meta = _copyMetadata(meta, sourceEvidence: sourceEvidence);
      }
      // If title is still generic, fall through
      if (recipe != null || !_isGenericTitle(meta.title.toLowerCase(), host)) {
        if (isInstagram) {
          meta = _cleanInstagramMetadata(meta, domain);
        }
        return meta;
      }
    } catch (e, st) {
      developer.log(
        'Manual OG parse failed for $normalized: $e',
        name: 'LinkPreview',
        stackTrace: st,
      );
    }

    // Fallback: use domain as title
    return LinkMetadata(title: domain, description: '', domain: domain);
  }

  /// Returns true if the title is a known generic site-level title.
  bool _isGenericTitle(String lowerTitle, String host) {
    const generic = [
      'reddit - the front page of the internet',
      'reddit - the heart of the internet',
      'reddit',
      'x',
      'x (formerly twitter)',
      'twitter',
      'home / x',
      'home / twitter',
    ];
    if (generic.contains(lowerTitle)) return true;
    if (lowerTitle == host) return true;
    return false;
  }

  Future<Response<dynamic>> _safeGet(
    String url, {
    required Options options,
    int maxRedirects = 5,
  }) async {
    var current = url;
    final chain = <String>[];

    for (var redirects = 0; redirects <= maxRedirects; redirects++) {
      if (!await urlSecurityValidator.isSafePublicUrl(current)) {
        throw StateError('blocked unsafe URL: $current');
      }
      chain.add(current);

      final response = await _dio.get<dynamic>(
        current,
        options: options.copyWith(
          followRedirects: false,
          validateStatus: (_) => true,
        ),
      );

      final status = response.statusCode ?? 0;
      if (!_isRedirectStatus(status)) {
        return response;
      }

      final location = response.headers.value('location');
      if (location == null || location.trim().isEmpty) {
        return response;
      }

      final next = Uri.parse(current).resolve(location.trim()).toString();
      final nextChain = [...chain, next];
      if (!await urlSecurityValidator.validateRedirectChain(nextChain)) {
        throw StateError('blocked unsafe redirect: $next');
      }
      current = next;
    }

    throw StateError('too many redirects');
  }

  bool _isRedirectStatus(int status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;

  /// Fetches Reddit post metadata via their JSON API.
  Future<LinkMetadata?> _fetchReddit(String url, String domain) async {
    try {
      // Convert URL to .json endpoint
      var jsonUrl = url.split('?').first;
      if (jsonUrl.endsWith('/')) {
        jsonUrl = jsonUrl.substring(0, jsonUrl.length - 1);
      }
      jsonUrl = '$jsonUrl.json';

      final response = await _safeGet(
        jsonUrl,
        options: Options(
          headers: {
            'User-Agent': 'Glimpse/1.0 (Flutter app)',
            'Accept': 'application/json',
          },
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.data is List && (response.data as List).isNotEmpty) {
        final listing = response.data[0];
        final children = listing?['data']?['children'];
        if (children is List && children.isNotEmpty) {
          final post = children[0]['data'];
          final title = post['title'] as String? ?? '';
          final author = post['author'] as String?;
          final subreddit = post['subreddit_name_prefixed'] as String?;
          final selftext = post['selftext'] as String? ?? '';
          final thumbnail = post['thumbnail'] as String?;
          final preview = post['preview'];
          String? imageUrl;
          if (preview != null) {
            final images = preview['images'] as List?;
            if (images != null && images.isNotEmpty) {
              imageUrl = (images[0]['source']?['url'] as String?)?.replaceAll(
                '&amp;',
                '&',
              );
            }
          }
          if (imageUrl == null &&
              thumbnail != null &&
              thumbnail.startsWith('http')) {
            imageUrl = thumbnail;
          }

          if (title.isNotEmpty) {
            final fullSelfText = _normalizeLargeText(selftext);
            return LinkMetadata(
              title: title,
              description: fullSelfText.isNotEmpty
                  ? fullSelfText
                  : (subreddit ?? ''),
              imageUrl: imageUrl,
              domain: domain,
              siteName: subreddit,
              author: author != null ? 'u/$author' : null,
            );
          }
        }
      }
    } catch (e) {
      developer.log(
        'Reddit metadata fetch failed for $domain: $e',
        name: 'LinkPreview',
      );
    }
    return null;
  }

  bool _isYouTubeHost(String host) {
    return host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtu.be' ||
        host == 'youtube-nocookie.com' ||
        host.endsWith('.youtube-nocookie.com');
  }

  Future<LinkMetadata?> _fetchYouTubeMetadata(String url, String domain) async {
    try {
      final response = await _safeGet(
        url,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 12),
          sendTimeout: const Duration(seconds: 12),
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final html = response.data?.toString() ?? '';
      final playerJson = _extractJsonObjectAfter(
        html,
        'ytInitialPlayerResponse',
      );
      final player = playerJson == null
          ? null
          : json.decode(playerJson) as Map<String, dynamic>?;
      final details = player?['videoDetails'] as Map<String, dynamic>?;
      final microformat =
          player?['microformat']?['playerMicroformatRenderer']
              as Map<String, dynamic>?;

      final parsed = _parseOgTags(html, domain);
      final title = _firstNonEmpty([
        details?['title']?.toString(),
        microformat?['title']?['simpleText']?.toString(),
        parsed.title,
      ]);
      final description = _firstNonEmpty([
        details?['shortDescription']?.toString(),
        microformat?['description']?['simpleText']?.toString(),
        parsed.description,
      ]);
      final author = _firstNonEmpty([
        details?['author']?.toString(),
        microformat?['ownerChannelName']?.toString(),
        parsed.author,
      ]);
      final imageUrl = _bestYouTubeThumbnail(details) ?? parsed.imageUrl;

      if (title.trim().isEmpty ||
          _isGenericTitle(title.toLowerCase(), domain)) {
        return null;
      }

      return LinkMetadata(
        title: _decodeHtmlEntities(title.trim()),
        description: _normalizeLargeText(_decodeHtmlEntities(description)),
        imageUrl: imageUrl,
        domain: domain,
        siteName: 'YouTube',
        author: author.trim().isNotEmpty ? author.trim() : null,
      );
    } catch (e, st) {
      developer.log(
        'YouTube metadata fetch failed for $domain: $e',
        name: 'LinkPreview',
        stackTrace: st,
      );
      return null;
    }
  }

  String? _extractJsonObjectAfter(String html, String marker) {
    final markerIndex = html.indexOf(marker);
    if (markerIndex < 0) return null;
    final equalsIndex = html.indexOf('=', markerIndex);
    if (equalsIndex < 0) return null;
    final start = html.indexOf('{', equalsIndex);
    if (start < 0) return null;

    var depth = 0;
    var inString = false;
    var escaping = false;
    for (var i = start; i < html.length; i++) {
      final code = html.codeUnitAt(i);
      if (inString) {
        if (escaping) {
          escaping = false;
        } else if (code == 0x5c) {
          escaping = true;
        } else if (code == 0x22) {
          inString = false;
        }
        continue;
      }
      if (code == 0x22) {
        inString = true;
        continue;
      }
      if (code == 0x7b) depth++;
      if (code == 0x7d) {
        depth--;
        if (depth == 0) return html.substring(start, i + 1);
      }
    }
    return null;
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  String? _bestYouTubeThumbnail(Map<String, dynamic>? details) {
    final thumbnails = details?['thumbnail']?['thumbnails'];
    if (thumbnails is! List || thumbnails.isEmpty) return null;
    String? best;
    var bestArea = -1;
    for (final item in thumbnails) {
      if (item is! Map) continue;
      final url = item['url']?.toString();
      if (url == null || url.isEmpty) continue;
      final width = (item['width'] as num?)?.toInt() ?? 0;
      final height = (item['height'] as num?)?.toInt() ?? 0;
      final area = width * height;
      if (area > bestArea) {
        bestArea = area;
        best = url;
      }
    }
    return best;
  }

  /// Fetches X/Twitter post metadata via the oEmbed endpoint.
  Future<LinkMetadata?> _fetchXEmbed(String url, String domain) async {
    try {
      final fullPostEvidence = await _fetchFullXPostEvidence(url);
      final embedUrl =
          'https://publish.twitter.com/oembed?url=${Uri.encodeComponent(url)}&omit_script=true';

      final response = await _safeGet(
        embedUrl,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.data is Map) {
        final data = response.data as Map;
        final author = data['author_name'] as String?;
        final html = data['html'] as String? ?? '';

        // Strip HTML tags from the embed to get tweet text
        final tweetText = html
            .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&quot;', '"')
            .replaceAll('&#39;', "'")
            .trim();

        final normalizedOEmbed = _normalizeLargeText(tweetText);
        final resolvedTweetText =
            (fullPostEvidence != null &&
                fullPostEvidence.readableText.trim().isNotEmpty)
            ? _normalizeLargeText(fullPostEvidence.readableText)
            : normalizedOEmbed;

        // Use tweet content as title (more informative than just @author)
        // Format: first ~80 chars of tweet, or "@author" if no text (image-only tweet)
        final shortText = resolvedTweetText.isNotEmpty
            ? resolvedTweetText
                  .substring(0, resolvedTweetText.length.clamp(0, 80))
                  .trim()
            : '';
        final title = shortText.isNotEmpty
            ? shortText
            : (author != null ? '@$author' : domain);
        // Description: full tweet text with author attribution
        final description = author != null && resolvedTweetText.isNotEmpty
            ? '@$author: $resolvedTweetText'
            : resolvedTweetText;

        // Extract username from author_url (e.g. "https://twitter.com/username")
        final authorUrl = data['author_url'] as String?;
        String? profileImageUrl;
        if (authorUrl != null) {
          final usernameMatch = RegExp(
            r'(?:twitter\.com|x\.com)/([^/?#]+)',
          ).firstMatch(authorUrl);
          final username = usernameMatch?.group(1);
          if (username != null && username.isNotEmpty) {
            profileImageUrl = 'https://unavatar.io/twitter/$username';
          }
        }

        return LinkMetadata(
          title: title,
          description: description,
          imageUrl: profileImageUrl,
          domain: domain,
          siteName: 'X',
          author: author != null ? '@$author' : null,
          sourceEvidence: SourceEvidence(
            readableText: resolvedTweetText,
            outboundLinks: fullPostEvidence?.outboundLinks ?? const [],
          ),
        );
      }
    } catch (e) {
      developer.log('X oEmbed failed for $domain: $e', name: 'LinkPreview');
    }

    // Fallback path for when oEmbed fails: still try to return full tweet text.
    final fallbackEvidence = await _fetchFullXPostEvidence(url);
    if (fallbackEvidence != null &&
        fallbackEvidence.readableText.trim().isNotEmpty) {
      final normalized = _normalizeLargeText(fallbackEvidence.readableText);
      final shortText = normalized
          .substring(0, normalized.length.clamp(0, 80))
          .trim();
      return LinkMetadata(
        title: shortText.isNotEmpty ? shortText : domain,
        description: normalized,
        domain: domain,
        siteName: 'X',
        sourceEvidence: SourceEvidence(
          readableText: normalized,
          outboundLinks: fallbackEvidence.outboundLinks,
        ),
      );
    }

    return null;
  }

  Future<SourceEvidence?> _fetchFullXPostEvidence(String url) async {
    final postId = _extractXPostId(url);
    if (postId == null) return null;

    final fromSyndication = await _fetchXEvidenceFromSyndication(postId);
    if (fromSyndication != null &&
        fromSyndication.readableText.trim().isNotEmpty) {
      return fromSyndication;
    }

    final fromFxTwitter = await _fetchXEvidenceFromFxTwitter(postId);
    if (fromFxTwitter != null && fromFxTwitter.readableText.trim().isNotEmpty) {
      return fromFxTwitter;
    }

    final fromVxTwitter = await _fetchXEvidenceFromVxTwitter(postId);
    if (fromVxTwitter != null && fromVxTwitter.readableText.trim().isNotEmpty) {
      return fromVxTwitter;
    }

    return null;
  }

  Future<SourceEvidence?> _fetchXEvidenceFromSyndication(String postId) async {
    try {
      final response = await _safeGet(
        'https://cdn.syndication.twimg.com/tweet-result?id=$postId&lang=en',
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36',
            'Accept': 'application/json',
          },
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.data is! Map) return null;
      final data = response.data as Map;
      final text = (data['text'] ?? data['full_text'])?.toString();
      if (text == null || text.trim().isEmpty) return null;
      return SourceEvidence(
        readableText: _decodeHtmlEntities(text),
        outboundLinks: _expandedReferencesFromJson(data),
      );
    } catch (e) {
      developer.log('X syndication fetch failed: $e', name: 'LinkPreview');
      return null;
    }
  }

  Future<SourceEvidence?> _fetchXEvidenceFromFxTwitter(String postId) async {
    try {
      final response = await _safeGet(
        'https://api.fxtwitter.com/i/status/$postId',
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36',
            'Accept': 'application/json',
          },
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.data is! Map) return null;
      final data = response.data as Map;
      final tweet = data['tweet'];
      if (tweet is! Map) return null;

      final text = (tweet['text'] ?? tweet['raw_text']?['text'])?.toString();
      if (text == null || text.trim().isEmpty) return null;
      return SourceEvidence(
        readableText: _decodeHtmlEntities(text),
        outboundLinks: _expandedReferencesFromJson(tweet),
      );
    } catch (e) {
      developer.log('FxTwitter fetch failed: $e', name: 'LinkPreview');
      return null;
    }
  }

  Future<SourceEvidence?> _fetchXEvidenceFromVxTwitter(String postId) async {
    try {
      final response = await _safeGet(
        'https://api.vxtwitter.com/i/status/$postId',
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36',
            'Accept': 'application/json',
          },
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.data is! Map) return null;
      final data = response.data as Map;
      final text = data['text']?.toString();
      if (text == null || text.trim().isEmpty) return null;
      return SourceEvidence(
        readableText: _decodeHtmlEntities(text),
        outboundLinks: _expandedReferencesFromJson(data),
      );
    } catch (e) {
      developer.log('VxTwitter fetch failed: $e', name: 'LinkPreview');
      return null;
    }
  }

  String? _extractXPostId(String url) {
    final match = RegExp(r'/(?:status|statuses)/(\d+)').firstMatch(url);
    return match?.group(1);
  }

  String _normalizeLargeText(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// Mobile Safari HTML often includes a usable [og:image] where Googlebot pages do not.
  Future<LinkMetadata?> _fetchInstagramPageMetadata(
    String url,
    String domain,
  ) async {
    try {
      final response = await _safeGet(
        url,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 '
                '(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 12),
          sendTimeout: const Duration(seconds: 12),
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode != 200) return null;

      final html = response.data?.toString() ?? '';
      var meta = _parseOgTags(html, domain);
      meta = _cleanInstagramMetadata(meta, domain);

      final hasImage =
          meta.imageUrl != null && meta.imageUrl!.trim().isNotEmpty;
      if (!hasImage) return null;

      final t = meta.title.toLowerCase();
      if (_isGenericInstagramFetchedTitle(t)) {
        meta = LinkMetadata(
          title: meta.author != null && meta.author!.trim().isNotEmpty
              ? '${meta.author!.trim()} on Instagram'
              : domain,
          description: meta.description,
          imageUrl: meta.imageUrl,
          domain: domain,
          siteName: 'Instagram',
          author: meta.author,
          extractedTags: meta.extractedTags,
        );
      }
      return meta;
    } catch (e) {
      developer.log(
        'Instagram page metadata failed for $domain: $e',
        name: 'LinkPreview',
      );
      return null;
    }
  }

  bool _isGenericInstagramFetchedTitle(String lowerTitle) {
    return lowerTitle == 'instagram' ||
        lowerTitle.contains('log in to instagram') ||
        lowerTitle.contains('login • instagram') ||
        lowerTitle == 'instagram.com' ||
        lowerTitle.startsWith('instagram - ');
  }

  /// Protocol-relative URLs, relative paths, and larger CDN sizes when possible.
  String? _normalizeInstagramImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return url;
    var u = url.trim();
    if (u.startsWith('//')) u = 'https:$u';
    if (u.startsWith('/')) {
      u = Uri.parse('https://www.instagram.com').resolve(u).toString();
    }
    u = u.replaceAllMapped(RegExp(r'/s(\d+)x(\d+)/', caseSensitive: false), (
      m,
    ) {
      final w = int.tryParse(m.group(1) ?? '') ?? 0;
      final h = int.tryParse(m.group(2) ?? '') ?? 0;
      if (w > 0 && h > 0 && w < 1080 && h < 1080) {
        return '/s1080x1080/';
      }
      return m.group(0)!;
    });
    return u;
  }

  /// Cleans up Instagram OG metadata:
  /// - strips the quoted caption from titles like "username on Instagram: \"caption\""
  /// - strips the "N Likes, M Comments - " prefix from description
  LinkMetadata _cleanInstagramMetadata(LinkMetadata meta, String domain) {
    var title = meta.title;
    // Remove the quoted caption portion: "user on Instagram: \"...\"" → "user on Instagram"
    final patterns = [
      RegExp(
        r':[ ]*["\u201c].+["\u201d]\s*$',
        dotAll: true,
      ), // straight or curly quotes
      RegExp(r":\s*['.+']\s*\$", dotAll: true), // single quotes
    ];
    for (final p in patterns) {
      final cleaned = title.replaceFirst(p, '').trim();
      if (cleaned.isNotEmpty && cleaned.length < title.length) {
        title = cleaned;
        break;
      }
    }
    // Hard truncate if still too long
    if (title.length > 70) title = '${title.substring(0, 70)}\u2026';

    var description = meta.description;
    // Instagram desc often: "123 Likes, 45 Comments - caption text"
    final likesPattern = RegExp(r'^[\d,]+ [Ll]ikes?,.*? - ');
    description = description.replaceFirst(likesPattern, '');
    // Don't let description mirror the title
    if (description.trim().toLowerCase() == meta.title.trim().toLowerCase() ||
        description.trim().toLowerCase() == title.trim().toLowerCase()) {
      description = '';
    }
    return LinkMetadata(
      title: title,
      description: description,
      imageUrl: _normalizeInstagramImageUrl(meta.imageUrl),
      domain: domain,
      siteName: 'Instagram',
      author: meta.author,
      recipe: meta.recipe,
      extractedTags: meta.extractedTags,
      sourceEvidence: meta.sourceEvidence,
    );
  }

  LinkMetadata _copyMetadata(
    LinkMetadata metadata, {
    SourceEvidence? sourceEvidence,
  }) {
    return LinkMetadata(
      title: metadata.title,
      description: metadata.description,
      imageUrl: metadata.imageUrl,
      domain: metadata.domain,
      siteName: metadata.siteName,
      author: metadata.author,
      recipe: metadata.recipe,
      extractedTags: metadata.extractedTags,
      sourceEvidence: sourceEvidence ?? metadata.sourceEvidence,
    );
  }

  static SourceEvidence sourceEvidenceFromHtml(
    String rawHtml, {
    required String pageUrl,
  }) {
    if (rawHtml.trim().isEmpty) {
      return const SourceEvidence(readableText: '');
    }
    final pageUri = Uri.tryParse(pageUrl);
    if (pageUri == null) return const SourceEvidence(readableText: '');

    final document = html_parser.parse(rawHtml);
    final articleBody = _articleBodyFromJsonLd(document);
    final root =
        document.querySelector('article') ??
        document.querySelector('main') ??
        document.querySelector('[role="main"]') ??
        document.body;
    if (root == null && articleBody.isEmpty) {
      return const SourceEvidence(readableText: '');
    }

    final outboundLinks = <SourceReference>[];
    final seenLinks = <String>{};
    if (root != null) {
      for (final element in root.querySelectorAll(
        'script, style, nav, header, footer, aside, form, button, svg, noscript',
      )) {
        element.remove();
      }

      for (final anchor in root.querySelectorAll('a[href]')) {
        final href = anchor.attributes['href']?.trim() ?? '';
        if (href.isEmpty || href.startsWith('#')) continue;
        final resolved = pageUri.resolve(href);
        final normalized = resolved.toString().split('#').first;
        if (!UrlSecurityValidator.hasAllowedPublicUrlSyntax(normalized)) {
          continue;
        }
        if (!seenLinks.add(normalized)) continue;
        final label = _cleanEvidenceText(anchor.text);
        outboundLinks.add(
          SourceReference(
            label: label.isEmpty
                ? resolved.host.replaceFirst('www.', '')
                : label,
            url: normalized,
          ),
        );
        if (outboundLinks.length >= 24) break;
      }
    }

    final blocks =
        root
            ?.querySelectorAll('h1, h2, h3, p, li, blockquote')
            .map((element) => _cleanEvidenceText(element.text))
            .where((text) => text.isNotEmpty)
            .toList() ??
        const <String>[];
    final semanticText = blocks.isNotEmpty
        ? blocks.join('\n\n')
        : _cleanEvidenceText(root?.text ?? '');
    final readable = articleBody.isNotEmpty ? articleBody : semanticText;

    return SourceEvidence(
      readableText: _limitEvidence(readable),
      outboundLinks: outboundLinks,
    );
  }

  static String _articleBodyFromJsonLd(dom.Document document) {
    for (final script in document.querySelectorAll(
      'script[type="application/ld+json"]',
    )) {
      final raw = script.text.trim();
      if (raw.isEmpty) continue;
      try {
        final found = _findArticleBody(jsonDecode(raw));
        if (found.isNotEmpty) return _limitEvidence(found);
      } catch (_) {
        // Malformed structured data is common; semantic HTML remains usable.
      }
    }
    return '';
  }

  static String _findArticleBody(Object? value) {
    if (value is Map) {
      final body = value['articleBody'] ?? value['article_body'];
      final text = _cleanEvidenceText(body?.toString() ?? '');
      if (text.isNotEmpty) return text;
      for (final nested in value.values) {
        final found = _findArticleBody(nested);
        if (found.isNotEmpty) return found;
      }
    } else if (value is List) {
      for (final nested in value) {
        final found = _findArticleBody(nested);
        if (found.isNotEmpty) return found;
      }
    }
    return '';
  }

  static String _cleanEvidenceText(String value) {
    return value
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'[\t ]+'), ' ')
        .replaceAll(RegExp(r'\s*\n\s*'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String _limitEvidence(String text) {
    const maxCharacters = 20000;
    final cleaned = _cleanEvidenceText(text);
    if (cleaned.length <= maxCharacters) return cleaned;
    const marker =
        '\n[Source excerpt ends here; remaining text was not captured.]';
    final limit = maxCharacters - marker.length;
    final boundary = cleaned.lastIndexOf(' ', limit);
    return '${cleaned.substring(0, boundary > 16000 ? boundary : limit)}$marker';
  }

  static SourceEvidence sourceEvidenceFromXJson(
    Object? value, {
    String readableText = '',
  }) {
    return SourceEvidence(
      readableText: _limitEvidence(_cleanEvidenceText(readableText)),
      outboundLinks: _expandedReferencesFromJson(value),
    );
  }

  static List<SourceReference> _expandedReferencesFromJson(Object? value) {
    final references = <SourceReference>[];
    final seen = <String>{};

    void visit(Object? current) {
      if (references.length >= 24) return;
      if (current is Map) {
        final expanded =
            current['expanded_url'] ??
            current['expandedUrl'] ??
            current['unwound_url'] ??
            current['unwoundUrl'];
        final raw = expanded?.toString().trim() ?? '';
        if (raw.isNotEmpty &&
            UrlSecurityValidator.hasAllowedPublicUrlSyntax(raw) &&
            seen.add(raw)) {
          final label =
              (current['display_url'] ??
                      current['displayUrl'] ??
                      Uri.tryParse(raw)?.host ??
                      raw)
                  .toString()
                  .trim();
          references.add(SourceReference(label: label, url: raw));
        }
        for (final nested in current.values) {
          visit(nested);
        }
      } else if (current is List) {
        for (final nested in current) {
          visit(nested);
        }
      }
    }

    visit(value);
    return references;
  }

  /// Parses Open Graph and standard HTML meta-tags from raw [html].
  LinkMetadata _parseOgTags(String html, String domain) {
    String? ogTitle = _extractMeta(html, 'og:title');
    String? ogDesc = _extractMeta(html, 'og:description');
    String? ogImage = _extractMeta(html, 'og:image');
    ogImage ??= _extractMeta(html, 'og:image:secure_url');
    ogImage ??= _extractMeta(html, 'og:image:url');

    // Fallback to twitter card tags
    ogTitle ??= _extractMeta(html, 'twitter:title');
    ogDesc ??= _extractMeta(html, 'twitter:description');
    ogImage ??= _extractMeta(html, 'twitter:image');
    ogImage ??= _extractMeta(html, 'twitter:image:src');

    // Fallback to plain meta description
    ogDesc ??= _extractMetaByName(html, 'description');

    // Fallback to <title> tag
    ogTitle ??= _extractHtmlTitle(html);

    // Extract author / creator / site name for better search
    final siteName = _extractMeta(html, 'og:site_name');
    final author =
        _extractMetaByName(html, 'author') ??
        _extractMeta(html, 'article:author') ??
        _extractMeta(html, 'twitter:creator') ??
        _extractMetaByName(html, 'twitter:creator');

    final resolvedImage = _resolvePossiblyRelativeUrl(ogImage, domain);

    return LinkMetadata(
      title: ogTitle ?? domain,
      description: ogDesc ?? '',
      imageUrl: resolvedImage,
      domain: domain,
      siteName: siteName,
      author: author,
    );
  }

  String? _resolvePossiblyRelativeUrl(String? url, String domain) {
    if (url == null || url.trim().isEmpty) return null;
    var u = url.trim();
    if (u.startsWith('//')) return 'https:$u';
    if (u.startsWith('/')) {
      final hostOnly = domain.split(':').first;
      final base = Uri.parse('https://$hostOnly');
      return base.resolveUri(Uri.parse(u)).toString();
    }
    return u;
  }

  /// Extracts content from `<meta property="[property]" content="..."/>`.
  String? _extractMeta(String html, String property) {
    // Matches both property="..." and name="..." variants
    final patterns = [
      RegExp(
        '<meta[^>]+property=["\']$property["\'][^>]+content=["\']([^"\']*)["\']',
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]+content=["\']([^"\']*)["\'][^>]+property=["\']$property["\']',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        final value = match.group(1)?.trim();
        if (value != null && value.isNotEmpty) {
          return _decodeHtmlEntities(value);
        }
      }
    }
    return null;
  }

  /// Extracts content from `<meta name="[name]" content="..."/>`.
  String? _extractMetaByName(String html, String name) {
    final patterns = [
      RegExp(
        '<meta[^>]+name=["\']$name["\'][^>]+content=["\']([^"\']*)["\']',
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]+content=["\']([^"\']*)["\'][^>]+name=["\']$name["\']',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        final value = match.group(1)?.trim();
        if (value != null && value.isNotEmpty) {
          return _decodeHtmlEntities(value);
        }
      }
    }
    return null;
  }

  /// Extracts text from `<title>...</title>`.
  String? _extractHtmlTitle(String html) {
    final match = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    final value = match?.group(1)?.trim();
    if (value != null && value.isNotEmpty) return _decodeHtmlEntities(value);
    return null;
  }

  /// Basic HTML entity decoding.
  String _decodeHtmlEntities(String text) {
    return TextCleaner.clean(text);
  }

  /// Validates whether a string is a valid URL.
  static bool isValidUrl(String url) {
    final normalized = normalizeUrl(url);
    return UrlSecurityValidator.hasAllowedPublicUrlSyntax(normalized) &&
        AnyLinkPreview.isValidLink(normalized);
  }
}
