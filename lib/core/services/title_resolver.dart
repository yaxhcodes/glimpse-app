import '../models/saved_url.dart';
import 'tag_noise_filter.dart';

/// Picks a human-facing title for cards and lists (skips creator-handle scrap titles).
class TitleResolver {
  TitleResolver._();

  static final _nameThenSep = RegExp(r'^[A-Z][a-z]+\s[\|•·]');
  static final _ampersandName = RegExp(r'\b&\s+[A-Z][a-z]+\b');

  static String resolve(
    SavedUrl link, {
    Map<String, int>? tagFrequency,
  }) {
    final rawTitle = link.title.trim();

    var candidateTitle = rawTitle;
    if (_isTwitterUrl(link.rawUrl) && rawTitle.isNotEmpty) {
      final parts = rawTitle.split(RegExp(r'\n\s*\n'));
      if (parts.length >= 2 && link.summary == null) {
        link.summary = parts.skip(1).join(' ').trim();
      }
      candidateTitle = _extractTweetTitle(rawTitle);
    }

    if (candidateTitle.isNotEmpty && !isCreatorHandle(candidateTitle)) {
      return candidateTitle;
    }

    final fromTags = _titleFromTags(link.tags, tagFrequency);
    if (fromTags != null) return fromTags;

    final fromSummary = _summaryTitleFallback(link.summary);
    if (fromSummary != null) return fromSummary;

    return _cleanDomain(link.domain);
  }

  static bool isCreatorHandle(String title) {
    final t = title.trim();
    if (t.isEmpty) return false;
    if (t.contains(' | ') || t.contains(' • ') || t.contains(' · ')) return true;

    final lower = t.toLowerCase();
    if (lower.endsWith('on instagram') ||
        lower.endsWith('on youtube') ||
        lower.endsWith('on twitter') ||
        lower.endsWith('on tiktok')) {
      return true;
    }
    if (lower.contains('| youtube')) return true;

    if (_nameThenSep.hasMatch(t)) return true;
    if (_ampersandName.hasMatch(t)) return true;

    return false;
  }

  static String? _titleFromTags(
    List<String> tags,
    Map<String, int>? tagFrequency,
  ) {
    final filtered = TagNoiseFilter.filterTags(tags);
    if (filtered.isEmpty) return null;

    final freq = tagFrequency ?? {};
    List<String> ordered;
    if (freq.isEmpty) {
      ordered = List<String>.from(filtered)
        ..sort((a, b) => b.length.compareTo(a.length));
    } else {
      ordered = TagNoiseFilter.orderByRarity(filtered, freq);
    }

    final top2 = ordered.take(2).map(_titleCaseWords).toList();
    if (top2.isEmpty) return null;
    return top2.join(' · ');
  }

  static String? _summaryTitleFallback(String? summary) {
    if (summary == null || summary.trim().isEmpty) return null;
    final full = summary.trim();
    final words =
        full.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return null;
    if (words.length <= 6) return full;
    return '${words.take(6).join(' ')}…';
  }

  static String _titleCaseWords(String phrase) {
    return phrase.split(RegExp(r'\s+')).map((w) {
      if (w.isEmpty) return w;
      if (w.length == 1) return w.toUpperCase();
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  static String _cleanDomain(String domain) {
    var d = domain.trim().toLowerCase();
    if (d.startsWith('www.')) d = d.substring(4);
    if (d == 'instagram.com' || d.endsWith('.instagram.com')) {
      return 'Instagram Reel';
    }
    if (d == 'youtube.com' || d.endsWith('.youtube.com')) return 'YouTube';
    if (d == 'tiktok.com' || d.endsWith('.tiktok.com')) return 'TikTok';
    if (d == 'twitter.com' ||
        d == 'x.com' ||
        d.endsWith('.twitter.com') ||
        d.endsWith('.x.com')) {
      return 'X';
    }
    if (d.isEmpty) return 'Link';
    final host = d.split('/').first;
    if (host.isEmpty) return 'Link';
    final parts = host.split('.');
    final label = parts.length >= 2 ? parts[parts.length - 2] : parts.first;
    if (label.isEmpty) return 'Link';
    return '${label[0].toUpperCase()}${label.length > 1 ? label.substring(1) : ''}';
  }

  static bool _isTwitterUrl(String rawUrl) {
    String host;
    try {
      host = Uri.parse(rawUrl).host.toLowerCase();
    } catch (_) {
      return false;
    }
    if (host.startsWith('www.')) host = host.substring(4);
    return host == 'twitter.com' ||
        host == 'x.com' ||
        host.endsWith('.twitter.com') ||
        host.endsWith('.x.com');
  }

  /// X/Twitter: headline before a blank line, else first sentence / truncation.
  static String _extractTweetTitle(String rawText) {
    final parts = rawText.split(RegExp(r'\n\s*\n'));

    if (parts.length >= 2) {
      final firstLine = parts[0].trim();
      if (firstLine.length <= 80 && firstLine.isNotEmpty) {
        return truncateTitle(firstLine, isTweet: true);
      }
    }

    RegExpMatch? firstSentence;
    for (final m in RegExp(r'[.!?]').allMatches(rawText)) {
      if (m.end > 20 && m.end <= 80) {
        firstSentence = m;
        break;
      }
    }
    if (firstSentence != null) {
      return rawText.substring(0, firstSentence.end);
    }

    return truncateTitle(rawText, isTweet: true);
  }

  /// Collapses newlines and repeated whitespace so scraped titles don't add
  /// blank lines on compact cards.
  static String collapseWhitespace(String text) {
    final t = text.trim();
    if (t.isEmpty) return '';
    return t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');
  }

  /// Word-aware truncation for compact cards (avoids mid-word cuts).
  static String truncateTitle(String title, {int maxLength = 60, bool isTweet = false}) {
    final cap = isTweet ? 80 : maxLength;
    if (title.length <= cap) return title;

    var cutAt = title.lastIndexOf(' ', cap);
    if (cutAt < (cap * 0.6).floor()) cutAt = cap;

    var truncated = title.substring(0, cutAt).trimRight();
    truncated = truncated.replaceAll(RegExp(r'[,;:\-–—]$'), '');

    final words = truncated.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length > 1 && words.last.length == 1) {
      truncated = words.sublist(0, words.length - 1).join(' ');
    }

    if (truncated.isEmpty || truncated.length >= title.length - 3) {
      return title;
    }
    return '$truncated...';
  }

  /// For X/Twitter copy, prefer the first sentence when it is a tight summary.
  static String maybeTwitterFirstSentence(String title, String rawUrl) {
    String host;
    try {
      host = Uri.parse(rawUrl).host.toLowerCase();
    } catch (_) {
      return title;
    }
    if (host.startsWith('www.')) host = host.substring(4);
    final isTwitter = host == 'twitter.com' ||
        host == 'x.com' ||
        host.endsWith('.twitter.com') ||
        host.endsWith('.x.com');
    if (!isTwitter) return title;

    final match = RegExp(r'[.!?]').firstMatch(title);
    if (match == null) return title;
    final sentenceEnd = match.start;
    if (sentenceEnd > 20 && sentenceEnd < 80) {
      return title.substring(0, sentenceEnd + 1);
    }
    return title;
  }

  /// After [resolve] + [collapseWhitespace], apply tweet sentence trim + [truncateTitle].
  static String formatForCompactCard(SavedUrl link, String resolvedCollapsed) {
    final t = maybeTwitterFirstSentence(resolvedCollapsed, link.rawUrl);
    return truncateTitle(t);
  }
}
