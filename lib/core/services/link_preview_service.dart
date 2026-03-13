import 'package:any_link_preview/any_link_preview.dart';
import 'package:dio/dio.dart';

/// Metadata extracted from a URL's Open Graph tags.
class LinkMetadata {
  final String title;
  final String description;
  final String? imageUrl;
  final String domain;
  final String? siteName;
  final String? author;
  /// Tags extracted by platform-specific parsers (e.g. Instagram hashtags).
  final List<String>? extractedTags;

  const LinkMetadata({
    required this.title,
    required this.description,
    this.imageUrl,
    required this.domain,
    this.siteName,
    this.author,
    this.extractedTags,
  });
}

/// Service for fetching Open Graph metadata from URLs.
class LinkPreviewService {
  final Dio _dio;

  LinkPreviewService({Dio? dio}) : _dio = dio ?? Dio();

  /// Normalise a raw URL to ensure it has a scheme.
  static String normalizeUrl(String url) {
    var trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }
    return trimmed;
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

    // ---- Reddit: use their JSON API ----
    if (host == 'reddit.com' || host.endsWith('.reddit.com') ||
        host == 'redd.it') {
      final result = await _fetchReddit(normalized, domain);
      if (result != null) return result;
    }

    // ---- Instagram: run cleaning pipeline ----
    // (Also catches instagr.am short links and subdomains)
    final isInstagram = host == 'instagram.com' ||
        host.endsWith('.instagram.com') ||
        host == 'instagr.am';

    // ---- X / Twitter: use oEmbed endpoint ----
    if (host == 'x.com' || host == 'twitter.com' ||
        host == 'mobile.x.com' || host == 'mobile.twitter.com') {
      final result = await _fetchXEmbed(normalized, domain);
      if (result != null) return result;
    }

    // ---- Attempt 1: any_link_preview ----
    try {
      final metadata = await AnyLinkPreview.getMetadata(
        link: normalized,
      );

      if (metadata != null &&
          (metadata.title != null && metadata.title!.isNotEmpty)) {
        // Reject generic site-level titles
        final t = metadata.title!.trim().toLowerCase();
        if (!_isGenericTitle(t, host)) {
          var result = LinkMetadata(
            title: metadata.title ?? domain,
            description: metadata.desc ?? '',
            imageUrl: metadata.image,
            domain: domain,
          );
          if (isInstagram) {
            result = _cleanInstagramMetadata(result, domain);
          }
          return result;
        }
      }
    } catch (_) {
      // fall through to manual attempt
    }

    // ---- Attempt 2: Manual OG tag parsing via Dio ----
    try {
      final response = await _dio.get(
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
      // If title is still generic, fall through
      if (!_isGenericTitle(meta.title.toLowerCase(), host)) {
        if (isInstagram) {
          meta = _cleanInstagramMetadata(meta, domain);
        }
        return meta;
      }
    } catch (_) {}

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

  /// Fetches Reddit post metadata via their JSON API.
  Future<LinkMetadata?> _fetchReddit(String url, String domain) async {
    try {
      // Convert URL to .json endpoint
      var jsonUrl = url.split('?').first;
      if (jsonUrl.endsWith('/')) jsonUrl = jsonUrl.substring(0, jsonUrl.length - 1);
      jsonUrl = '$jsonUrl.json';

      final response = await _dio.get(
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
              imageUrl = (images[0]['source']?['url'] as String?)
                  ?.replaceAll('&amp;', '&');
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
    } catch (_) {}
    return null;
  }

  /// Fetches X/Twitter post metadata via the oEmbed endpoint.
  Future<LinkMetadata?> _fetchXEmbed(String url, String domain) async {
    try {
      final fullTweetFromApi = await _fetchFullXPostText(url);
      final embedUrl =
          'https://publish.twitter.com/oembed?url=${Uri.encodeComponent(url)}&omit_script=true';

      final response = await _dio.get(
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
        final resolvedTweetText = (fullTweetFromApi != null &&
            fullTweetFromApi.trim().isNotEmpty)
          ? _normalizeLargeText(fullTweetFromApi)
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
          final usernameMatch = RegExp(r'(?:twitter\.com|x\.com)/([^/?#]+)').firstMatch(authorUrl);
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
        );
      }
    } catch (_) {}

    // Fallback path for when oEmbed fails: still try to return full tweet text.
    final fallbackText = await _fetchFullXPostText(url);
    if (fallbackText != null && fallbackText.trim().isNotEmpty) {
      final normalized = _normalizeLargeText(fallbackText);
      final shortText = normalized.substring(0, normalized.length.clamp(0, 80)).trim();
      return LinkMetadata(
        title: shortText.isNotEmpty ? shortText : domain,
        description: normalized,
        domain: domain,
        siteName: 'X',
      );
    }

    return null;
  }

  Future<String?> _fetchFullXPostText(String url) async {
    final postId = _extractXPostId(url);
    if (postId == null) return null;

    final fromSyndication = await _fetchXTextFromSyndication(postId);
    if (fromSyndication != null && fromSyndication.trim().isNotEmpty) {
      return fromSyndication;
    }

    final fromFxTwitter = await _fetchXTextFromFxTwitter(postId);
    if (fromFxTwitter != null && fromFxTwitter.trim().isNotEmpty) {
      return fromFxTwitter;
    }

    final fromVxTwitter = await _fetchXTextFromVxTwitter(postId);
    if (fromVxTwitter != null && fromVxTwitter.trim().isNotEmpty) {
      return fromVxTwitter;
    }

    return null;
  }

  Future<String?> _fetchXTextFromSyndication(String postId) async {
    try {
      final response = await _dio.get(
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
      return _decodeHtmlEntities(text);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _fetchXTextFromFxTwitter(String postId) async {
    try {
      final response = await _dio.get(
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
      return _decodeHtmlEntities(text);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _fetchXTextFromVxTwitter(String postId) async {
    try {
      final response = await _dio.get(
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
      return _decodeHtmlEntities(text);
    } catch (_) {
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

  /// Cleans up Instagram OG metadata:
  /// - strips the quoted caption from titles like "username on Instagram: \"caption\"" 
  /// - strips the "N Likes, M Comments - " prefix from description
  LinkMetadata _cleanInstagramMetadata(LinkMetadata meta, String domain) {
    var title = meta.title;
    // Remove the quoted caption portion: "user on Instagram: \"...\"" → "user on Instagram"
    final patterns = [
      RegExp(r':[ ]*["\u201c].+["\u201d]\s*$', dotAll: true),  // straight or curly quotes
      RegExp(r":\s*['.+']\s*\$", dotAll: true),               // single quotes
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
      imageUrl: meta.imageUrl,
      domain: domain,
      siteName: 'Instagram',
      author: meta.author,
    );
  }


  /// Parses Open Graph and standard HTML meta-tags from raw [html].
  LinkMetadata _parseOgTags(String html, String domain) {
    String? ogTitle = _extractMeta(html, 'og:title');
    String? ogDesc = _extractMeta(html, 'og:description');
    String? ogImage = _extractMeta(html, 'og:image');

    // Fallback to twitter card tags
    ogTitle ??= _extractMeta(html, 'twitter:title');
    ogDesc ??= _extractMeta(html, 'twitter:description');
    ogImage ??= _extractMeta(html, 'twitter:image');

    // Fallback to plain meta description
    ogDesc ??= _extractMetaByName(html, 'description');

    // Fallback to <title> tag
    ogTitle ??= _extractHtmlTitle(html);

    // Extract author / creator / site name for better search
    final siteName = _extractMeta(html, 'og:site_name');
    final author = _extractMetaByName(html, 'author') ??
        _extractMeta(html, 'article:author') ??
        _extractMeta(html, 'twitter:creator') ??
        _extractMetaByName(html, 'twitter:creator');

    return LinkMetadata(
      title: ogTitle ?? domain,
      description: ogDesc ?? '',
      imageUrl: ogImage,
      domain: domain,
      siteName: siteName,
      author: author,
    );
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
        if (value != null && value.isNotEmpty) return _decodeHtmlEntities(value);
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
        if (value != null && value.isNotEmpty) return _decodeHtmlEntities(value);
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
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#x27;', "'")
        .replaceAll('&apos;', "'");
  }

  /// Validates whether a string is a valid URL.
  static bool isValidUrl(String url) {
    final normalized = normalizeUrl(url);
    return AnyLinkPreview.isValidLink(normalized);
  }
}
