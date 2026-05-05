import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../home/home_provider.dart';
import '../mindmap/cluster_theme.dart';
import '../mindmap/interest_clusters_provider.dart';

/// One empty-state suggestion: [display] includes emoji; [promptText] fills the composer.
class AskSuggestionChipData {
  const AskSuggestionChipData({
    required this.display,
    required this.promptText,
  });

  final String display;
  final String promptText;
}

/// Legacy v1 cache (category-based) — removed on [clearAskSuggestionsCache].
const _kLegacyJsonKey = 'glimpse_ask_suggestions_cache_json';
const _kLegacyTsKey = 'glimpse_ask_suggestions_timestamp';
const _kLegacyFpKey = 'glimpse_ask_suggestions_fingerprint';

/// Personal suggestions (recent URLs → Gemini) — 24h TTL; cleared on new save.
const _kV2JsonKey = 'glimpse_suggestions_v2';
const _kV2TsKey = 'glimpse_suggestions_timestamp_v2';

/// Cluster-theme suggestions (semantic interest map) — 24h TTL; cleared on new save.
const _kClusterSuggestionsJsonKey = 'glimpse_suggestions_clusters_v4';
const _kClusterSuggestionsTsKey = 'glimpse_suggestions_clusters_ts_v4';

/// Previous cluster-suggestion keys (invalidate on clear / migration).
const _kV3JsonKey = 'glimpse_suggestions_v3_clusters';
const _kV3TsKey = 'glimpse_suggestions_timestamp_v3';

const _suggestionsTtl = Duration(hours: 24);

/// No saves yet, or UI fallback when suggestion load fails.
const kAskOnboardingSuggestionChips = <AskSuggestionChipData>[
  AskSuggestionChipData(
    display: 'Save your first link',
    promptText: 'How do I save a link?',
  ),
  AskSuggestionChipData(
    display: 'Paste something to start',
    promptText: 'How do I save a link?',
  ),
  AskSuggestionChipData(
    display: 'Try a quick save',
    promptText: 'How do I save a link?',
  ),
];

String _buildSuggestionContext(List<SavedUrl> urls) {
  return urls
      .map((u) {
        var host = u.domain.trim();
        if (host.isEmpty) {
          try {
            host = Uri.parse(u.rawUrl).host.replaceFirst(RegExp(r'^www\.'), '');
          } catch (_) {
            host = 'link';
          }
        } else {
          host = host.replaceFirst(RegExp(r'^www\.'), '');
        }
        final tags = u.tags.isEmpty ? '—' : u.tags.join(', ');
        final title = u.title.replaceAll('"', "'");
        return '- "$title" ($host) [$tags]';
      })
      .join('\n');
}

List<AskSuggestionChipData> _chipsFromClusterThemesHeuristic(
  List<ClusterTheme> themes,
) {
  if (themes.isEmpty) return const [];
  final fromThemes = themes.take(3).map((t) {
    final q = 'What did I save about ${t.label}?';
    return AskSuggestionChipData(display: q, promptText: q);
  }).toList();
  if (fromThemes.length >= 3) return fromThemes;
  return [
    ...fromThemes,
    ...kAskOnboardingSuggestionChips.take(3 - fromThemes.length),
  ];
}

List<AskSuggestionChipData> _heuristicChipsFromRecent(List<SavedUrl> recent) {
  if (recent.isEmpty)
    return List<AskSuggestionChipData>.of(kAskOnboardingSuggestionChips);
  final fromUrls = recent.take(3).map((u) {
    final short = u.title.length > 28
        ? '${u.title.substring(0, 28)}…'
        : u.title;
    final q = 'What did I save about "$short"?';
    return AskSuggestionChipData(display: q, promptText: q);
  }).toList();
  if (fromUrls.length >= 3) return fromUrls;
  return [
    ...fromUrls,
    ...kAskOnboardingSuggestionChips.take(3 - fromUrls.length),
  ];
}

List<AskSuggestionChipData>? _readCachedV2(SharedPreferences prefs) {
  final ts = prefs.getInt(_kV2TsKey);
  final raw = prefs.getString(_kV2JsonKey);
  if (ts == null || raw == null || raw.isEmpty) return null;
  final age = DateTime.now().millisecondsSinceEpoch - ts;
  if (age > _suggestionsTtl.inMilliseconds) return null;
  try {
    final list = json.decode(raw) as List<dynamic>;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return AskSuggestionChipData(
        display: m['d'] as String,
        promptText: m['p'] as String,
      );
    }).toList();
  } catch (_) {
    return null;
  }
}

Future<void> _writeCachedV2(
  SharedPreferences prefs,
  List<AskSuggestionChipData> chips,
) async {
  final payload = chips
      .map((c) => {'d': c.display, 'p': c.promptText})
      .toList();
  await prefs.setString(_kV2JsonKey, jsonEncode(payload));
  await prefs.setInt(_kV2TsKey, DateTime.now().millisecondsSinceEpoch);
}

List<AskSuggestionChipData>? _readCachedClusterSuggestions(
  SharedPreferences prefs,
) {
  final ts = prefs.getInt(_kClusterSuggestionsTsKey);
  final raw = prefs.getString(_kClusterSuggestionsJsonKey);
  if (ts == null || raw == null || raw.isEmpty) return null;
  final age = DateTime.now().millisecondsSinceEpoch - ts;
  if (age > _suggestionsTtl.inMilliseconds) return null;
  try {
    final list = json.decode(raw) as List<dynamic>;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return AskSuggestionChipData(
        display: m['d'] as String,
        promptText: m['p'] as String,
      );
    }).toList();
  } catch (_) {
    return null;
  }
}

Future<void> _writeCachedClusterSuggestions(
  SharedPreferences prefs,
  List<AskSuggestionChipData> chips,
) async {
  final payload = chips
      .map((c) => {'d': c.display, 'p': c.promptText})
      .toList();
  await prefs.setString(_kClusterSuggestionsJsonKey, jsonEncode(payload));
  await prefs.setInt(
    _kClusterSuggestionsTsKey,
    DateTime.now().millisecondsSinceEpoch,
  );
}

/// Clears LLM suggestion cache (legacy v1 + personal v2; e.g. after “Clear all data”).
Future<void> clearAskSuggestionsCache() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kLegacyJsonKey);
  await prefs.remove(_kLegacyTsKey);
  await prefs.remove(_kLegacyFpKey);
  await prefs.remove(_kV2JsonKey);
  await prefs.remove(_kV2TsKey);
  await prefs.remove(_kV3JsonKey);
  await prefs.remove(_kV3TsKey);
  await prefs.remove(_kClusterSuggestionsJsonKey);
  await prefs.remove(_kClusterSuggestionsTsKey);
}

Future<List<AskSuggestionChipData>> _resolveSuggestions(Ref ref) async {
  final isar = ref.read(isarServiceProvider);
  final displayedUrls = ref.watch(displayedUrlsProvider).valueOrNull;

  // Respect dev-only first-time UX simulation.
  if (displayedUrls != null && displayedUrls.isEmpty) {
    return List<AskSuggestionChipData>.of(kAskOnboardingSuggestionChips);
  }

  final recent = await isar.getRecentUrls(limit: 15);
  if (recent.isEmpty) {
    return List<AskSuggestionChipData>.of(kAskOnboardingSuggestionChips);
  }

  final prefs = await SharedPreferences.getInstance();
  final embedded = await isar.getUrlsWithEmbeddings();

  if (embedded.length >= 3) {
    final clusterCacheHit = _readCachedClusterSuggestions(prefs);
    if (clusterCacheHit != null && clusterCacheHit.length >= 3) {
      return clusterCacheHit;
    }

    final themes = await ref.read(interestClusterThemesProvider.future);
    if (themes.isNotEmpty) {
      final gemini = ref.read(geminiServiceProvider);
      if (gemini != null) {
        try {
          final themeLines = themes
              .take(6)
              .map(
                (t) => '- "${t.label}" — ${t.summary} (${t.urls.length} links)',
              )
              .join('\n');
          var questions = await gemini.generateAskSuggestionsFromClusterThemes(
            themeLines,
          );
          final safeQs = questions.take(3).toList();
          while (safeQs.length < 3) {
            safeQs.add('What themes run through my bookmarks?');
          }
          final chips = List<AskSuggestionChipData>.generate(3, (i) {
            final q = safeQs[i];
            return AskSuggestionChipData(display: q, promptText: q);
          });
          await _writeCachedClusterSuggestions(prefs, chips);
          return chips;
        } catch (_) {
          return _chipsFromClusterThemesHeuristic(themes);
        }
      }

      return _chipsFromClusterThemesHeuristic(themes);
    }
  }

  final cached = _readCachedV2(prefs);
  if (cached != null && cached.length >= 3) {
    return cached;
  }

  final gemini = ref.read(geminiServiceProvider);
  if (gemini == null) {
    return _heuristicChipsFromRecent(recent);
  }

  try {
    final context = _buildSuggestionContext(recent);
    final questions = await gemini.generatePersonalAskSuggestions(context);
    final chips = questions
        .take(3)
        .map((q) => AskSuggestionChipData(display: q, promptText: q))
        .toList();
    await _writeCachedV2(prefs, chips);
    return chips;
  } catch (_) {
    return _heuristicChipsFromRecent(recent);
  }
}

/// Dynamic Ask empty-state chips (cached 24h; refreshed after new saves).
final askEmptySuggestionsProvider =
    FutureProvider.autoDispose<List<AskSuggestionChipData>>((ref) async {
      return _resolveSuggestions(ref);
    });
