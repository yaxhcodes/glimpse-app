import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/clustering/embedding_clustering.dart';
import '../../core/database/isar_service.dart';
import '../../core/models/saved_url.dart';
import '../../core/services/gemini_service.dart';
import 'cluster_theme.dart';

/// Persisted cluster snapshot (IDs only); rebuilt when library size shifts enough.
const kInterestClustersJsonKey = 'glimpse_clusters_v4';
const _maxDisplayClusters = 8;
const kInterestClusterUrlCountKey = 'glimpse_cluster_url_count';

const _clusterRebuildThreshold = 1;

List<Map<String, dynamic>> _rowsForIsolate(List<SavedUrl> urls) {
  return urls
      .map(
        (u) => <String, dynamic>{
          'id': u.id,
          'title': u.title,
          'rawUrl': u.rawUrl,
          'category': u.category,
          'categoryEmoji': u.categoryEmoji,
          'tags': u.tags,
          'embedding': u.embedding!,
        },
      )
      .toList();
}

ClusterTheme _singletonClusterTheme(List<SavedUrl> c, int index) {
  final u = c.first;
  var label = u.category.trim();
  if (label.isEmpty) {
    label = u.title.trim().isNotEmpty ? u.title.trim() : u.domain;
  }
  if (label.isEmpty) label = 'Saved link';
  final em = u.categoryEmoji.trim().isNotEmpty ? u.categoryEmoji : '🔖';
  final summary =
      u.title.trim().isNotEmpty ? u.title.trim() : u.domain;
  return ClusterTheme(
    index: index,
    label: label,
    emoji: em,
    summary: summary,
    urls: c,
  );
}

List<ClusterTheme> _heuristicThemes(List<List<SavedUrl>> clusters) {
  return List<ClusterTheme>.generate(clusters.length, (i) {
    final urls = clusters[i];
    if (urls.length == 1) return _singletonClusterTheme(urls, i);

    final first = urls.first;
    final title = first.title.trim();
    var label = title.split(RegExp(r'\s+')).take(4).join(' ');
    if (label.isEmpty) label = 'Saved links';
    final em = first.categoryEmoji.trim().isNotEmpty ? first.categoryEmoji : '🔖';
    final summary =
        '${urls.length} bookmarks on similar topics (auto-grouped).';
    return ClusterTheme(
      index: i,
      label: label,
      emoji: em,
      summary: summary,
      urls: urls,
    );
  });
}

Future<List<Map<String, String>>> _nameClustersWithGemini(
  GeminiService gemini,
  List<List<SavedUrl>> clusters,
) async {
  final block = clusters.asMap().entries.map((e) {
    final i = e.key;
    final c = e.value;
    final titles = c.take(5).map((u) {
      final safe = u.title.replaceAll('"', "'");
      return '"$safe"';
    }).join(', ');
    return 'Cluster ${i + 1} (${c.length} links): $titles';
  }).join('\n');

  return gemini.nameInterestClusters(
    clusterDescriptionsBlock: block,
    clusterCount: clusters.length,
  );
}

Future<void> _writeClusterCache(
  SharedPreferences prefs,
  int urlCount,
  List<ClusterTheme> themes,
) async {
  final payload = <String, dynamic>{
    'version': 1,
    'themes': themes
        .map(
          (t) => {
            'label': t.label,
            'emoji': t.emoji,
            'summary': t.summary,
            'ids': t.urls.map((u) => u.id).toList(),
          },
        )
        .toList(),
  };
  await prefs.setString(kInterestClustersJsonKey, jsonEncode(payload));
  await prefs.setInt(kInterestClusterUrlCountKey, urlCount);
}

/// Returns hydrated themes, or `null` if cache is missing/invalid/stale.
Future<List<ClusterTheme>?> tryHydrateClustersFromPrefs({
  required SharedPreferences prefs,
  required List<SavedUrl> embeddedUrls,
  required int currentEmbeddedCount,
}) async {
  final cachedCount = prefs.getInt(kInterestClusterUrlCountKey) ?? 0;
  if ((currentEmbeddedCount - cachedCount).abs() >= _clusterRebuildThreshold) {
    return null;
  }
  final raw = prefs.getString(kInterestClustersJsonKey);
  if (raw == null || raw.isEmpty) return null;

  try {
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final list = decoded['themes'] as List<dynamic>?;
    if (list == null || list.isEmpty) return null;
    final byId = {for (final u in embeddedUrls) u.id: u};
    final out = <ClusterTheme>[];
    for (var i = 0; i < list.length; i++) {
      final m = list[i] as Map<String, dynamic>;
      final ids = (m['ids'] as List<dynamic>).map((e) => e as int).toList();
      final urls = ids.map((id) => byId[id]).whereType<SavedUrl>().toList();
      if (urls.isEmpty) continue;
      out.add(
        ClusterTheme(
          index: out.length,
          label: m['label'] as String? ?? 'Cluster',
          emoji: m['emoji'] as String? ?? '🔖',
          summary: m['summary'] as String? ?? '',
          urls: urls,
        ),
      );
    }
    return out.isEmpty ? null : out;
  } catch (_) {
    return null;
  }
}

/// Loads cached clusters or recomputes (isolate clustering + optional Gemini naming).
Future<List<ClusterTheme>> loadOrBuildInterestClusterThemes({
  required IsarService isar,
  required SharedPreferences prefs,
  GeminiService? gemini,
}) async {
  final urls = await isar.getUrlsWithEmbeddings();
  if (urls.length < 3) return const [];

  final hydrated = await tryHydrateClustersFromPrefs(
    prefs: prefs,
    embeddedUrls: urls,
    currentEmbeddedCount: urls.length,
  );
  if (hydrated != null) return hydrated;

  final rows = _rowsForIsolate(urls);
  final indexClusters = await compute(clusterUrlIndicesByCosine, rows);
  if (indexClusters.isEmpty) return const [];

  final clusters = indexClusters
      .take(_maxDisplayClusters)
      .map((indices) => indices.map((i) => urls[i]).toList())
      .toList();

  List<ClusterTheme> themes;
  if (gemini != null) {
    try {
      final multi = clusters.where((c) => c.length > 1).toList();
      List<Map<String, String>> names = const [];
      if (multi.isNotEmpty) {
        names = await _nameClustersWithGemini(gemini, multi);
      }
      var multiIdx = 0;
      themes = List<ClusterTheme>.generate(clusters.length, (i) {
        final c = clusters[i];
        if (c.length == 1) {
          return _singletonClusterTheme(c, i);
        }
        Map<String, String> row;
        if (multiIdx < names.length) {
          row = names[multiIdx];
        } else {
          row = {
            'label': 'Interest group ${i + 1}',
            'emoji': c.first.categoryEmoji.trim().isNotEmpty
                ? c.first.categoryEmoji
                : '🔖',
            'summary': '${c.length} related bookmarks.',
          };
        }
        multiIdx++;
        return ClusterTheme(
          index: i,
          label: row['label'] ?? 'Cluster',
          emoji: row['emoji'] ?? '🔖',
          summary: row['summary'] ?? '',
          urls: c,
        );
      });
    } catch (_) {
      themes = _heuristicThemes(clusters);
    }
  } else {
    themes = _heuristicThemes(clusters);
  }

  await _writeClusterCache(prefs, urls.length, themes);
  return themes;
}
