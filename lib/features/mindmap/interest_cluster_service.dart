import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/clustering/embedding_clustering.dart';
import '../../core/database/isar_service.dart';
import '../../core/models/saved_url.dart';
import '../../core/services/gemini_service.dart';
import '../../core/services/title_resolver.dart';
import 'cluster_theme.dart';

/// Persisted cluster snapshot — bump version to invalidate stale caches.
const kInterestClustersJsonKey = 'glimpse_clusters_v8';
const kInterestClusterUrlCountKey = 'glimpse_cluster_url_count_v8';

/// Max top-level clusters shown in the map.
const _maxDisplayClusters = 8;

/// How many URLs must change before we force a full rebuild.
const _clusterRebuildThreshold = 5;

// ─── Isolate row helpers ──────────────────────────────────────────────────────

List<Map<String, dynamic>> _rowsForIsolate(List<SavedUrl> urls) {
  return urls
      .map(
        (u) => <String, dynamic>{
          'id': u.id,
          'title': u.title,
          'rawUrl': u.rawUrl,
          'category': u.category,
          'tags': u.tags,
          'embedding': u.embedding!,
        },
      )
      .toList();
}

/// Extracts embeddings from rows as a flat list-of-lists.
/// Each inner list is already a List<double> from the Isar model.
List<List<double>> _embeddingsFromRows(List<Map<String, dynamic>> rows) {
  return rows.map((r) {
    final raw = r['embedding'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => (e as num).toDouble()).toList();
    }
    return <double>[];
  }).toList();
}

// ─── Tag frequency ────────────────────────────────────────────────────────────

Map<String, int> _tagCountsForClusters(List<List<SavedUrl>> clusters) {
  final counts = <String, int>{};
  for (final c in clusters) {
    for (final u in c) {
      for (final t in u.tags) {
        final k = t.toLowerCase().trim();
        if (k.isEmpty) continue;
        counts[k] = (counts[k] ?? 0) + 1;
      }
    }
  }
  return counts;
}

// ─── Heuristic (no-Gemini) theme builders ────────────────────────────────────

ClusterTheme _singletonClusterTheme(List<SavedUrl> c, int index) {
  final u = c.first;
  var label = u.category.trim();
  if (label.isEmpty) label = TitleResolver.resolve(u, tagFrequency: null);
  if (label.isEmpty) label = 'Saved link';
  final summary = TitleResolver.resolve(u, tagFrequency: null);
  return ClusterTheme(
    index: index,
    label: label,
    summary: summary,
    urls: c,
    subClusters: const [],
  );
}

List<ClusterTheme> _heuristicThemes(List<List<SavedUrl>> clusters) {
  final tagFreq = _tagCountsForClusters(clusters);
  return List<ClusterTheme>.generate(clusters.length, (i) {
    final urls = clusters[i];
    if (urls.length == 1) return _singletonClusterTheme(urls, i);
    final first = urls.first;
    var label = TitleResolver.resolve(first, tagFrequency: tagFreq);
    if (label.isEmpty) label = 'Saved links';
    final summary = '${urls.length} bookmarks on similar topics.';
    return ClusterTheme(
      index: i,
      label: label,
      summary: summary,
      urls: urls,
      subClusters: const [],
    );
  });
}

// ─── Gemini description block builder ────────────────────────────────────────

String _titlesBlock(List<SavedUrl> urls, {int take = 5}) {
  return urls
      .take(take)
      .map((u) {
        final safe = TitleResolver.resolve(
          u,
          tagFrequency: null,
        ).replaceAll('"', "'");
        return '"$safe"';
      })
      .join(', ');
}

/// Builds the descriptionsBlock for [nameHierarchicalClusters].
/// [subLocalGroups[i]] contains local indices (0-based within clusters[i])
/// for each sub-group, or null when no sub-structure was found.
///
/// Sub-group items include their local URL index so the LLM can reference
/// them in the "reassignments" field of its combined response.
String _buildDescriptionsBlock(
  List<List<SavedUrl>> clusters,
  List<List<List<int>>?> subLocalGroups,
) {
  final buffer = StringBuffer();
  for (var i = 0; i < clusters.length; i++) {
    final c = clusters[i];
    buffer.writeln('Cluster ${i + 1} (${c.length} links): ${_titlesBlock(c)}');

    final subGroups = subLocalGroups[i];
    if (subGroups != null && subGroups.isNotEmpty) {
      for (var si = 0; si < subGroups.length; si++) {
        final group = subGroups[si];
        final subUrls = group.map((li) => c[li]).toList();
        final indexed = group.take(4).map((li) {
          final safe = TitleResolver.resolve(c[li], tagFrequency: null)
              .replaceAll('"', "'");
          return 'url $li: "$safe"';
        }).join(', ');
        buffer.writeln(
          '  Sub-group $si (${subUrls.length} links): $indexed',
        );
      }
    }
  }
  return buffer.toString().trimRight();
}

// ─── Sub-cluster theme assembly ───────────────────────────────────────────────

/// Converts raw sub-cluster local-index groups into [SubClusterTheme] objects.
/// [subLocalGroups] has local indices (0-based into [parentUrls]).
List<SubClusterTheme> _buildSubClusters(
  List<SavedUrl> parentUrls,
  List<List<int>> subLocalGroups,
  List<Map<String, String>> subLabels,
) {
  final result = <SubClusterTheme>[];
  for (var i = 0; i < subLocalGroups.length; i++) {
    final group = subLocalGroups[i];
    final subUrls = group
        .where((li) => li >= 0 && li < parentUrls.length)
        .map((li) => parentUrls[li])
        .toList();
    if (subUrls.isEmpty) continue;

    String label;
    String summary;
    if (i < subLabels.length) {
      label = subLabels[i]['label']?.trim() ?? '';
      summary = subLabels[i]['summary']?.trim() ?? '';
    } else {
      label = '';
      summary = '';
    }
    if (label.isEmpty) label = subUrls.first.category.trim();
    if (label.isEmpty) label = 'Group ${i + 1}';
    if (summary.isEmpty) summary = '${subUrls.length} related links.';

    result.add(SubClusterTheme(label: label, summary: summary, urls: subUrls));
  }
  return result;
}

// ─── Cache read / write ───────────────────────────────────────────────────────

Future<void> _writeClusterCache(
  SharedPreferences prefs,
  int urlCount,
  List<ClusterTheme> themes,
) async {
  final payload = <String, dynamic>{
    'version': 5,
    'themes': themes.map((t) {
      return {
        'label': t.label,
        'summary': t.summary,
        'ids': t.urls.map((u) => u.id).toList(),
        'subClusters': t.subClusters.map((s) {
          return {
            'label': s.label,
            'summary': s.summary,
            'ids': s.urls.map((u) => u.id).toList(),
          };
        }).toList(),
      };
    }).toList(),
  };
  await prefs.setString(kInterestClustersJsonKey, jsonEncode(payload));
  await prefs.setInt(kInterestClusterUrlCountKey, urlCount);
}

/// Returns hydrated themes from cache, or `null` if cache is absent / stale.
Future<List<ClusterTheme>?> tryHydrateClustersFromPrefs({
  required SharedPreferences prefs,
  required List<SavedUrl> embeddedUrls,
  required int currentEmbeddedCount,
}) async {
  final raw = prefs.getString(kInterestClustersJsonKey);

  // No cache at all — always rebuild (covers the manual refresh path).
  if (raw == null || raw.isEmpty) {
    developer.log('No cluster cache found — will rebuild.', name: 'Mindmap');
    return null;
  }

  // Cache exists — check if the library has changed significantly.
  final cachedCount = prefs.getInt(kInterestClusterUrlCountKey) ?? 0;
  if ((currentEmbeddedCount - cachedCount).abs() >= _clusterRebuildThreshold) {
    developer.log(
      'Cluster cache stale (cached=$cachedCount, current=$currentEmbeddedCount) — rebuilding.',
      name: 'Mindmap',
    );
    return null;
  }

  try {
    final decoded = json.decode(raw) as Map<String, dynamic>;

    // Reject caches from old schema versions.
    final version = decoded['version'] as int? ?? 0;
    if (version < 5) {
      developer.log(
        'Cluster cache version $version < 5 — rebuilding.',
        name: 'Mindmap',
      );
      return null;
    }

    final list = decoded['themes'] as List<dynamic>?;
    if (list == null || list.isEmpty) return null;

    final byId = {for (final u in embeddedUrls) u.id: u};
    final out = <ClusterTheme>[];

    for (var i = 0; i < list.length; i++) {
      final m = list[i] as Map<String, dynamic>;
      final ids = (m['ids'] as List<dynamic>).map((e) => e as int).toList();
      final urls = ids.map((id) => byId[id]).whereType<SavedUrl>().toList();
      if (urls.isEmpty) continue;

      final rawSubs = m['subClusters'] as List<dynamic>? ?? const [];
      final subClusters = <SubClusterTheme>[];
      for (final rs in rawSubs) {
        final sm = rs as Map<String, dynamic>;
        final sIds = (sm['ids'] as List<dynamic>).map((e) => e as int).toList();
        final sUrls = sIds.map((id) => byId[id]).whereType<SavedUrl>().toList();
        if (sUrls.isEmpty) continue;
        subClusters.add(
          SubClusterTheme(
            label: sm['label'] as String? ?? 'Group',
            summary: sm['summary'] as String? ?? '',
            urls: sUrls,
          ),
        );
      }

      out.add(
        ClusterTheme(
          index: out.length,
          label: m['label'] as String? ?? 'Cluster',
          summary: m['summary'] as String? ?? '',
          urls: urls,
          subClusters: subClusters,
        ),
      );
    }

    developer.log(
      'Hydrated ${out.length} clusters from cache (${out.where((t) => t.hasSubClusters).length} with sub-clusters).',
      name: 'Mindmap',
    );
    return out.isEmpty ? null : out;
  } catch (e, stack) {
    developer.log(
      'Failed to hydrate cluster cache: $e',
      name: 'Mindmap',
      stackTrace: stack,
    );
    return null;
  }
}

// ─── Isolate payload helpers ──────────────────────────────────────────────────

/// Packages top-level cluster global indices + all embeddings into a plain
/// Map so Flutter's compute() can send it across the isolate port safely.
///
/// Embeddings are stored as a flat list-of-lists of doubles. Dart's isolate
/// message passing handles List<List<double>> fine as long as the inner lists
/// only contain Dart primitives — which they do here.
Map<String, dynamic> _buildSubClusterPayload(
  List<List<int>> clusterGlobalIndices,
  List<List<double>> embeddings,
) {
  return <String, dynamic>{
    // We encode each embedding as a plain List<double> — isolate-safe.
    'embeddings': embeddings,
    'clusters': clusterGlobalIndices,
  };
}

// ─── Main entry point ─────────────────────────────────────────────────────────

/// Loads cached clusters or recomputes from scratch.
///
/// Pipeline:
///   1. Try cache (skipped when JSON is absent, i.e. after manual refresh).
///   2. Top-level cosine clustering in an isolate.
///   3. k-means sub-clustering in an isolate.
///   4. Gemini hierarchical naming (one API call covers main + sub labels).
///   5. Persist to cache.
Future<List<ClusterTheme>> loadOrBuildInterestClusterThemes({
  required IsarService isar,
  required SharedPreferences prefs,
  GeminiService? gemini,
}) async {
  final urls = await isar.getUrlsWithEmbeddings();
  developer.log('URLs with embeddings: ${urls.length}', name: 'Mindmap');
  if (urls.length < 3) return const [];

  final hydrated = await tryHydrateClustersFromPrefs(
    prefs: prefs,
    embeddedUrls: urls,
    currentEmbeddedCount: urls.length,
  );
  if (hydrated != null) return hydrated;

  developer.log('Building clusters from scratch…', name: 'Mindmap');

  // ── Step 1: top-level clustering ───────────────────────────────────────
  final rows = _rowsForIsolate(urls);
  final indexClusters = await compute(clusterUrlIndicesByCosine, rows);
  if (indexClusters.isEmpty) {
    developer.log('Top-level clustering returned 0 clusters.', name: 'Mindmap');
    return const [];
  }

  final topClusters = indexClusters
      .take(_maxDisplayClusters)
      .map((indices) => indices.map((i) => urls[i]).toList())
      .toList();

  developer.log(
    'Top-level clusters: ${topClusters.length}, sizes: '
    '${topClusters.map((c) => c.length).toList()}',
    name: 'Mindmap',
  );

  // ── Step 2: sub-clustering ─────────────────────────────────────────────
  final embeddings = _embeddingsFromRows(rows);

  // Build global-index lists for each top-level cluster.
  // urlIndexById maps url.id -> position in the `urls` list.
  final urlIndexById = {for (var i = 0; i < urls.length; i++) urls[i].id: i};
  final clusterGlobalIndices = topClusters.map((cluster) {
    return cluster.map((u) => urlIndexById[u.id]).whereType<int>().toList();
  }).toList();

  // Run sub-clustering in the isolate.
  final subPayload = _buildSubClusterPayload(clusterGlobalIndices, embeddings);
  final rawSubGroups = await compute(computeSubClusters, subPayload);

  // rawSubGroups[i] is a list of groups of GLOBAL indices (or null).
  // Convert to LOCAL indices (0-based within topClusters[i]) for downstream use.
  final subLocalGroups = <List<List<int>>?>[];
  for (var i = 0; i < topClusters.length; i++) {
    final globalGroups = rawSubGroups[i];
    if (globalGroups == null) {
      subLocalGroups.add(null);
      continue;
    }
    // Build global -> local mapping for this cluster.
    final globalToLocal = <int, int>{};
    for (var li = 0; li < clusterGlobalIndices[i].length; li++) {
      globalToLocal[clusterGlobalIndices[i][li]] = li;
    }
    final localGroups = <List<int>>[];
    for (final globalGroup in globalGroups) {
      final localGroup = globalGroup
          .map((gi) => globalToLocal[gi])
          .whereType<int>()
          .toList();
      if (localGroup.isNotEmpty) localGroups.add(localGroup);
    }
    subLocalGroups.add(localGroups.isEmpty ? null : localGroups);
  }

  final subClusterCount = subLocalGroups.where((g) => g != null).length;
  developer.log(
    'Sub-clustering done: $subClusterCount / ${topClusters.length} clusters '
    'have sub-structure.',
    name: 'Mindmap',
  );

  // ── Step 3: naming ─────────────────────────────────────────────────────
  List<ClusterTheme> themes;

  if (gemini != null) {
    try {
      // Only pass multi-URL clusters to Gemini; singletons use heuristic labels.
      final multiIndices = <int>[];
      final multiClusters = <List<SavedUrl>>[];
      final multiSubGroups = <List<List<int>>?>[];

      for (var i = 0; i < topClusters.length; i++) {
        if (topClusters[i].length > 1) {
          multiIndices.add(i);
          multiClusters.add(topClusters[i]);
          multiSubGroups.add(subLocalGroups[i]);
        }
      }

      List<Map<String, dynamic>> names = const [];
      if (multiClusters.isNotEmpty) {
        final block = _buildDescriptionsBlock(multiClusters, multiSubGroups);
        developer.log(
          'Sending ${multiClusters.length} clusters to Gemini for naming.',
          name: 'Mindmap',
        );
        developer.log('Descriptions block:\n$block', name: 'Mindmap');
        names = await gemini.nameHierarchicalClusters(
          descriptionsBlock: block,
          mainClusterCount: multiClusters.length,
        );
        developer.log(
          'Gemini returned ${names.length} names; '
          'sub-labels counts: ${names.map((n) => (n['subLabels'] as List?)?.length ?? 0).toList()}',
          name: 'Mindmap',
        );
      }

      // ── Step 3b: apply outlier reassignments from the combined response ────
      for (var mi = 0; mi < multiIndices.length; mi++) {
        final ci = multiIndices[mi];
        final localGroups = subLocalGroups[ci];
        if (localGroups == null || localGroups.length < 2) continue;

        final nameRow = mi < names.length ? names[mi] : null;
        final rawReassign =
            (nameRow?['reassignments'] as Map<dynamic, dynamic>?) ?? const {};
        if (rawReassign.isEmpty) continue;

        final mutableGroups =
            localGroups.map((g) => List<int>.from(g)).toList();
        var moved = 0;

        for (final entry in rawReassign.entries) {
          final localIdx = int.tryParse(entry.key.toString());
          final targetSub = (entry.value as num?)?.toInt();
          if (localIdx == null || targetSub == null) continue;
          if (targetSub < 0 || targetSub >= mutableGroups.length) continue;

          for (final g in mutableGroups) {
            g.remove(localIdx);
          }
          mutableGroups[targetSub].add(localIdx);
          moved++;
        }

        if (moved > 0) {
          final valid = mutableGroups
              .where((g) => g.length >= kMinSubClusterSize)
              .toList();
          subLocalGroups[ci] =
              valid.length >= kMinSubClusterCount ? valid : null;

          developer.log(
            'Cluster[$ci]: reassigned $moved URL(s) across sub-clusters.',
            name: 'Mindmap',
          );
        }
      }

      // ── Step 3c: build ClusterTheme objects ────────────────────────────────
      var multiNameIdx = 0;
      themes = List<ClusterTheme>.generate(topClusters.length, (i) {
        final c = topClusters[i];

        if (c.length == 1) return _singletonClusterTheme(c, i);

        // Find the Gemini name row for this cluster.
        Map<String, dynamic> row;
        final namePos = multiIndices.indexOf(i);
        if (namePos >= 0 && namePos < names.length) {
          row = names[namePos];
        } else {
          row = {
            'label': 'Interest group ${multiNameIdx + 1}',
            'summary': '${c.length} related bookmarks.',
            'subLabels': <Map<String, String>>[],
          };
        }
        multiNameIdx++;

        // Parse Gemini sub-labels.
        final rawSubLabels = (row['subLabels'] as List<dynamic>?) ?? const [];
        final subLabels = rawSubLabels
            .whereType<Map>()
            .map(
              (m) => <String, String>{
                'label': m['label']?.toString().trim() ?? '',
                'summary': m['summary']?.toString().trim() ?? '',
              },
            )
            .toList();

        final localGroups = subLocalGroups[i];
        final subClusters = localGroups != null && localGroups.isNotEmpty
            ? _buildSubClusters(c, localGroups, subLabels)
            : const <SubClusterTheme>[];

        developer.log(
          'Cluster[$i] "${row['label']}": ${c.length} URLs, '
          '${subClusters.length} sub-clusters.',
          name: 'Mindmap',
        );

        return ClusterTheme(
          index: i,
          label: row['label'] as String? ?? 'Cluster',
          summary: row['summary'] as String? ?? '',
          urls: c,
          subClusters: subClusters,
        );
      });
    } catch (e, stack) {
      developer.log(
        'Gemini naming failed, falling back to heuristics: $e',
        name: 'Mindmap',
        stackTrace: stack,
      );
      // Heuristic fallback still wires up sub-clusters without labels.
      final heuristic = _heuristicThemes(topClusters);
      themes = List<ClusterTheme>.generate(heuristic.length, (i) {
        final h = heuristic[i];
        final localGroups = subLocalGroups[i];
        if (localGroups == null || localGroups.isEmpty) return h;
        final subClusters = _buildSubClusters(
          topClusters[i],
          localGroups,
          const [],
        );
        return ClusterTheme(
          index: h.index,
          label: h.label,
          summary: h.summary,
          urls: h.urls,
          subClusters: subClusters,
        );
      });
    }
  } else {
    // No Gemini: heuristic labels + wire up sub-clusters.
    final heuristic = _heuristicThemes(topClusters);
    themes = List<ClusterTheme>.generate(heuristic.length, (i) {
      final h = heuristic[i];
      final localGroups = subLocalGroups[i];
      if (localGroups == null || localGroups.isEmpty) return h;
      final subClusters = _buildSubClusters(
        topClusters[i],
        localGroups,
        const [],
      );
      return ClusterTheme(
        index: h.index,
        label: h.label,
        summary: h.summary,
        urls: h.urls,
        subClusters: subClusters,
      );
    });
  }

  await _writeClusterCache(prefs, urls.length, themes);
  developer.log(
    'Cluster build complete. ${themes.length} themes, '
    '${themes.where((t) => t.hasSubClusters).length} with sub-clusters.',
    name: 'Mindmap',
  );
  return themes;
}
