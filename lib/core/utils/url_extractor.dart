import '../services/link_preview_service.dart';

/// Result of extracting URLs from arbitrary text.
class ExtractedUrls {
  final List<String> urls;
  final bool hasMultiple;

  const ExtractedUrls({required this.urls, required this.hasMultiple});
}

/// Robust URL extraction from arbitrary text (shared intents, pasted notes,
/// browser tab groups, etc).
class UrlExtractor {
  UrlExtractor._();

  /// Main regex for http(s) URLs.
  static final _urlRegex = RegExp(
    r'https?://[^\s<>"{}|\\^`\[\]]+',
    caseSensitive: false,
  );

  /// Extracts all valid, unique URLs from [text], preserving original order.
  static ExtractedUrls extract(String text) {
    final rawMatches = _urlRegex.allMatches(text);
    final seen = <String>{};
    final urls = <String>[];

    for (final match in rawMatches) {
      var url = match.group(0);
      if (url == null || url.trim().isEmpty) continue;

      // Trim trailing punctuation that often gets caught
      url = url.trim();
      url = _trimTrailingNoise(url);

      // Normalize
      final normalized = LinkPreviewService.normalizeUrl(url);

      // Validate
      if (!LinkPreviewService.isValidUrl(normalized)) continue;

      // Deduplicate (case-insensitive)
      final lower = normalized.toLowerCase();
      if (seen.contains(lower)) continue;
      seen.add(lower);
      urls.add(normalized);
    }

    return ExtractedUrls(urls: urls, hasMultiple: urls.length > 1);
  }

  /// Extracts a single URL from text (fallback for simple shares).
  static String? extractFirst(String text) {
    final result = extract(text);
    return result.urls.isNotEmpty ? result.urls.first : null;
  }

  /// Strips common trailing punctuation / noise characters.
  static String _trimTrailingNoise(String url) {
    const noise = <String>[
      '.',
      ',',
      ';',
      ':',
      ')',
      ']',
      '}',
      '>',
      '"',
      "'",
    ];
    var cleaned = url;
    while (cleaned.isNotEmpty && noise.contains(cleaned[cleaned.length - 1])) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }
}
