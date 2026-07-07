import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/clustering/embedding_clustering.dart';
import '../../core/database/isar_service.dart';
import '../../core/models/saved_url.dart';
import '../../core/services/category_taxonomy.dart';
import '../../core/services/gemini_service.dart';
import '../../core/services/tag_noise_filter.dart';
import '../../core/services/title_resolver.dart';
import 'cluster_theme.dart';

/// Persisted cluster snapshot — bump version to invalidate stale caches.
const kInterestClustersJsonKey = 'glimpse_clusters_v15';
const kInterestClusterUrlCountKey = 'glimpse_cluster_url_count_v15';

/// How many URLs must change before we force a full rebuild.
const _clusterRebuildThreshold = 5;
const _smallLibraryCacheThreshold = 12;

// ─── Isolate row helpers ──────────────────────────────────────────────────────

List<Map<String, dynamic>> _rowsForIsolate(List<SavedUrl> urls) {
  return urls
      .map(
        (u) => <String, dynamic>{
          'id': u.id,
          'title': u.title,
          'rawUrl': u.rawUrl,
          'category': u.category,
          'categoryBucket': _broadCategoryBucket(u),
          'tags': u.tags,
          'embedding': u.embedding!,
        },
      )
      .toList();
}

/// The broad topic category used as a hard clustering boundary, so unrelated
/// topics (Food & Cooking vs Technology) never share a cluster. Maps any raw /
/// platform category onto one of the 16 [CategoryTaxonomy] buckets.
String _broadCategoryBucket(SavedUrl u) {
  try {
    return CategoryTaxonomy.normalize(category: u.category, tags: u.tags).name;
  } catch (_) {
    final c = u.category.trim();
    return c.isEmpty ? 'Other' : c;
  }
}

/// Extracts embeddings from rows as a flat list-of-lists.
/// Each inner list is already a `List<double>` from the Isar model.
List<List<double>> _embeddingsFromRows(List<Map<String, dynamic>> rows) {
  return rows.map((r) {
    final raw = r['embedding'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => (e as num).toDouble()).toList();
    }
    return <double>[];
  }).toList();
}

const _genericTopicWords = <String>{
  'ai',
  'article',
  'bookmark',
  'bookmarks',
  'design tools',
  'general',
  'google',
  'instagram',
  'link',
  'links',
  'other',
  'reddit',
  'saved',
  'social',
  'unclassified',
  'technology',
  'travel',
  'video',
  'web',
  'website',
  'x',
  'youtube',
};

bool _isWeakClusterLabel(String label) {
  final l = label.trim().toLowerCase();
  if (l.isEmpty) return true;
  if (l.startsWith('interest group')) return true;
  if (l == 'cluster' || l == 'saved links' || l == 'related bookmarks') {
    return true;
  }
  return _genericTopicWords.contains(l);
}

String _titleCaseTopic(String value) {
  return value
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) {
        final lower = w.toLowerCase();
        const keepUpper = {'ai', 'ml', 'ui', 'ux', 'seo', 'saas', 'api'};
        if (keepUpper.contains(lower)) return lower.toUpperCase();
        if (w.length == 1) return w.toUpperCase();
        return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
      })
      .join(' ');
}

String _textForUrls(List<SavedUrl> urls) {
  return urls
      .map(
        (u) => [
          u.title,
          u.description,
          u.summary ?? '',
          u.tags.join(' '),
          u.category,
          u.domain,
        ].join(' '),
      )
      .join(' ')
      .toLowerCase();
}

bool _isTrekLike(List<SavedUrl> urls, [String label = '']) {
  final text = '${label.toLowerCase()} ${_textForUrls(urls)}';
  return text.contains('trek') ||
      text.contains('trail') ||
      text.contains('himalaya') ||
      text.contains('kanchenjunga') ||
      text.contains('te araroa') ||
      text.contains('iceland') ||
      text.contains('mountain route');
}

String _trekRegionLabel(List<SavedUrl> urls) {
  final text = _textForUrls(urls);
  if (text.contains('iceland')) return 'Iceland';
  if (text.contains('new zealand') || text.contains('te araroa')) {
    return 'New Zealand';
  }
  if (text.contains('rajasthan')) return 'Rajasthan';
  if (text.contains('nepal') ||
      text.contains('himalaya') ||
      text.contains('kanchenjunga')) {
    return 'Himalayan';
  }
  return 'Mountain routes';
}

List<SubClusterTheme> _trekSubClustersForUrls(List<SavedUrl> urls) {
  final byRegion = <String, List<SavedUrl>>{};
  for (final url in urls) {
    final label = _trekRegionLabel([url]);
    byRegion.putIfAbsent(label, () => <SavedUrl>[]).add(url);
  }

  final result = byRegion.entries.map((entry) {
    return SubClusterTheme(
      label: entry.key,
      summary: _heuristicSummaryForUrls(entry.value, '${entry.key} treks'),
      urls: entry.value,
    );
  }).toList()..sort((a, b) => b.urls.length.compareTo(a.urls.length));

  return result;
}

String? _ruleBasedTopicLabel(List<SavedUrl> urls) {
  final text = _textForUrls(urls);
  final scores = <String, int>{
    'AI Agents': _keywordScore(text, [
      'agent',
      'genai',
      'openai',
      'anthropic',
      'claude',
      'llm',
      'prompt',
      'ai engineer',
      'aimaxing',
    ]),
    'Dev Tools & OSS': _keywordScore(text, [
      'github',
      'repo',
      'oss',
      'open source',
      'react',
      'next.js',
      'vercel',
      'linear',
      'code',
      'backend',
      'linux',
      'cybersecurity',
      'software engineering',
    ]),
    'Website Growth': _keywordScore(text, [
      'seo',
      'search console',
      'website optimization',
      'traffic',
      'conversion',
      'growth',
      'revenue',
    ]),
    'Startup Building': _keywordScore(text, [
      'startup',
      'founder',
      'first 100 users',
      'credits',
      'money',
      'saas',
    ]),
    'Design Systems': _keywordScore(text, [
      'design system',
      'ui tools',
      'patterns',
      'refero',
      'figma',
      'ux',
      'designiti',
      'design inspiration',
    ]),
    'Typography Tools': _keywordScore(text, [
      'font',
      'fontjoy',
      'typography',
      'typeface',
    ]),
    'Modern Agriculture': _keywordScore(text, [
      'agriculture',
      'farming',
      'farm',
      'agribusiness',
      'agritech',
    ]),
  };

  final hasTrek =
      text.contains('trek') ||
      text.contains('himalaya') ||
      text.contains('kanchenjunga') ||
      text.contains('te araroa') ||
      text.contains('trail');
  if (hasTrek) {
    return 'Treks';
  }

  final ranked = scores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (ranked.isNotEmpty && ranked.first.value >= 2) {
    return ranked.first.key;
  }

  return null;
}

int _keywordScore(String text, List<String> keywords) {
  var score = 0;
  for (final keyword in keywords) {
    var start = 0;
    while (true) {
      final index = text.indexOf(keyword, start);
      if (index < 0) break;
      score++;
      start = index + keyword.length;
    }
  }
  return score;
}

Map<String, int> _topicCountsForUrls(List<SavedUrl> urls) {
  final counts = <String, int>{};
  for (final u in urls) {
    final filteredTags = TagNoiseFilter.filterTags(u.tags);
    for (final tag in filteredTags) {
      final k = tag.toLowerCase().trim();
      if (k.isEmpty || _genericTopicWords.contains(k)) continue;
      counts[k] = (counts[k] ?? 0) + 1;
    }
  }
  return counts;
}

String _heuristicLabelForUrls(
  List<SavedUrl> urls, {
  String fallback = 'Saved links',
}) {
  if (urls.isEmpty) return fallback;

  final ruleLabel = _ruleBasedTopicLabel(urls);
  if (ruleLabel != null) return ruleLabel;

  final counts = _topicCountsForUrls(urls).entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return b.key.length.compareTo(a.key.length);
    });

  if (counts.isNotEmpty) {
    final first = counts.first;
    final second = counts.length > 1 ? counts[1] : null;
    if (second != null &&
        second.value >= first.value - 1 &&
        '${first.key} ${second.key}'.length <= 26) {
      return '${_titleCaseTopic(first.key)} + ${_titleCaseTopic(second.key)}';
    }
    return _titleCaseTopic(first.key);
  }

  final nonGenericCategories = urls
      .map((u) => u.category.trim())
      .where(
        (c) => c.isNotEmpty && !_genericTopicWords.contains(c.toLowerCase()),
      )
      .toList();
  if (nonGenericCategories.isNotEmpty) {
    return _titleCaseTopic(nonGenericCategories.first);
  }

  final resolved = TitleResolver.resolve(urls.first, tagFrequency: null);
  if (resolved.trim().isNotEmpty) return TitleResolver.truncateTitle(resolved);
  return fallback;
}

String _heuristicSummaryForUrls(List<SavedUrl> urls, String label) {
  final count = urls.length;
  final noun = count == 1 ? 'save' : 'saves';
  return '$count related $noun around ${label.toLowerCase()}.';
}

String _canonicalThemeKey(ClusterTheme theme) {
  final label = theme.label.trim().toLowerCase();
  if (_isTrekLike(theme.urls, label)) return 'treks';
  if (!_isWeakClusterLabel(label)) return label;
  return _heuristicLabelForUrls(theme.urls).trim().toLowerCase();
}

List<SubClusterTheme> _mergeSubClusters(List<SubClusterTheme> subClusters) {
  final byKey = <String, List<SavedUrl>>{};
  for (final sub in subClusters) {
    final label = _isWeakClusterLabel(sub.label)
        ? _heuristicLabelForUrls(sub.urls, fallback: 'Related')
        : sub.label;
    final key = label.trim().toLowerCase();
    final bucket = byKey.putIfAbsent(key, () => <SavedUrl>[]);
    final seen = bucket.map((u) => u.id).toSet();
    for (final url in sub.urls) {
      if (seen.add(url.id)) bucket.add(url);
    }
  }

  final merged = byKey.entries.map((entry) {
    final label = _titleCaseTopic(entry.key);
    return SubClusterTheme(
      label: label,
      summary: _heuristicSummaryForUrls(entry.value, label),
      urls: entry.value,
    );
  }).toList()..sort((a, b) => b.urls.length.compareTo(a.urls.length));

  return merged;
}

List<ClusterTheme> _mergeDuplicateThemes(List<ClusterTheme> themes) {
  final grouped = <String, List<ClusterTheme>>{};
  for (final theme in themes) {
    grouped.putIfAbsent(_canonicalThemeKey(theme), () => []).add(theme);
  }

  final merged = <ClusterTheme>[];
  for (final entry in grouped.entries) {
    final group = entry.value;
    final urlsById = <int, SavedUrl>{};
    final allSubs = <SubClusterTheme>[];

    for (final theme in group) {
      for (final url in theme.urls) {
        urlsById[url.id] = url;
      }
      allSubs.addAll(theme.subClusters);
    }

    final urls = urlsById.values.toList();
    final label = _heuristicLabelForUrls(urls, fallback: group.first.label);
    final subClusters = label == 'Treks' || _isTrekLike(urls, label)
        ? _trekSubClustersForUrls(urls)
        : _mergeSubClusters(allSubs);

    merged.add(
      ClusterTheme(
        index: merged.length,
        label: label,
        summary: _heuristicSummaryForUrls(urls, label),
        urls: urls,
        subClusters: subClusters,
      ),
    );
  }

  merged.sort((a, b) => b.urls.length.compareTo(a.urls.length));
  return List<ClusterTheme>.generate(merged.length, (i) {
    final theme = merged[i];
    return ClusterTheme(
      index: i,
      label: theme.label,
      summary: theme.summary,
      urls: theme.urls,
      subClusters: theme.subClusters,
    );
  });
}

/// Promotes sub-clusters that are clearly a **different broad topic** than
/// their parent into their own top-level themes.
///
/// Why this is needed: category bucketing keeps unrelated topics apart *when
/// the per-URL category is correct*. But some saves carry a wrong category
/// (e.g. Indian-food Reels mis-tagged "Technology"), so they bucket — and
/// cluster — with Dev Tools, and the taxonomy's food keywords don't cover
/// "curry/keema/masala" to re-route them. The one reliable signal is that the
/// k-means sub-clustering isolates them and Gemini names that sub-group with a
/// real taxonomy category ("Food & Cooking"). That category name, different
/// from the parent's, is the tell that those saves were mis-grouped.
List<ClusterTheme> _promoteForeignSubClusters(List<ClusterTheme> themes) {
  final rebuilt = <ClusterTheme>[];

  for (final theme in themes) {
    final parentCat = _dominantBroadCategory(theme.urls);

    final promoted = <SubClusterTheme>[];
    for (final sub in theme.subClusters) {
      final subCat = CategoryTaxonomy.tryByName(sub.label.trim())?.name;
      if (subCat != null &&
          subCat != 'Other' &&
          subCat != parentCat &&
          sub.urls.length >= kMinSubClusterSize) {
        promoted.add(sub);
      }
    }

    if (promoted.isEmpty) {
      rebuilt.add(theme);
      continue;
    }

    final promotedIds = {
      for (final sub in promoted)
        for (final url in sub.urls) url.id,
    };
    final remaining = theme.urls
        .where((u) => !promotedIds.contains(u.id))
        .toList();

    // Re-label the parent now that the foreign topic is gone.
    if (remaining.isNotEmpty) {
      final label = _heuristicLabelForUrls(remaining, fallback: theme.label);
      rebuilt.add(
        ClusterTheme(
          index: 0,
          label: label,
          summary: _heuristicSummaryForUrls(remaining, label),
          urls: remaining,
          subClusters: [
            for (final sub in theme.subClusters)
              if (!promoted.contains(sub)) sub,
          ],
        ),
      );
    }

    // Each promoted sub-cluster becomes its own theme, keeping Gemini's label.
    for (final sub in promoted) {
      rebuilt.add(
        ClusterTheme(
          index: 0,
          label: sub.label.trim(),
          summary: _heuristicSummaryForUrls(sub.urls, sub.label.trim()),
          urls: sub.urls,
          subClusters: const [],
        ),
      );
    }
  }

  return _mergeThemesByLabel(rebuilt);
}

/// Most common broad [CategoryTaxonomy] bucket among a theme's URLs.
String _dominantBroadCategory(List<SavedUrl> urls) {
  final counts = <String, int>{};
  for (final u in urls) {
    final bucket = _broadCategoryBucket(u);
    counts[bucket] = (counts[bucket] ?? 0) + 1;
  }
  var best = '';
  var bestCount = -1;
  counts.forEach((key, value) {
    if (value > bestCount) {
      bestCount = value;
      best = key;
    }
  });
  return best;
}

/// Merges themes that share a label (e.g. food promoted out of two parents),
/// preserving the label rather than re-deriving it, then re-indexes by size.
List<ClusterTheme> _mergeThemesByLabel(List<ClusterTheme> themes) {
  final byKey = <String, List<ClusterTheme>>{};
  for (final theme in themes) {
    byKey.putIfAbsent(theme.label.trim().toLowerCase(), () => []).add(theme);
  }

  final merged = <ClusterTheme>[];
  for (final group in byKey.values) {
    if (group.length == 1) {
      merged.add(group.first);
      continue;
    }
    final urlsById = <int, SavedUrl>{};
    final subs = <SubClusterTheme>[];
    for (final theme in group) {
      for (final url in theme.urls) {
        urlsById[url.id] = url;
      }
      subs.addAll(theme.subClusters);
    }
    final urls = urlsById.values.toList();
    merged.add(
      ClusterTheme(
        index: 0,
        label: group.first.label,
        summary: _heuristicSummaryForUrls(urls, group.first.label),
        urls: urls,
        subClusters: _mergeSubClusters(subs),
      ),
    );
  }

  merged.sort((a, b) => b.urls.length.compareTo(a.urls.length));
  return List<ClusterTheme>.generate(merged.length, (i) {
    final theme = merged[i];
    return ClusterTheme(
      index: i,
      label: theme.label,
      summary: theme.summary,
      urls: theme.urls,
      subClusters: theme.subClusters,
    );
  });
}

// ─── Heuristic (no-Gemini) theme builders ────────────────────────────────────

ClusterTheme _singletonClusterTheme(List<SavedUrl> c, int index) {
  final label = _heuristicLabelForUrls(c, fallback: 'Saved link');
  final summary = _heuristicSummaryForUrls(c, label);
  return ClusterTheme(
    index: index,
    label: label,
    summary: summary,
    urls: c,
    subClusters: const [],
  );
}

List<ClusterTheme> _heuristicThemes(List<List<SavedUrl>> clusters) {
  return List<ClusterTheme>.generate(clusters.length, (i) {
    final urls = clusters[i];
    if (urls.length == 1) return _singletonClusterTheme(urls, i);
    final label = _heuristicLabelForUrls(urls);
    final summary = _heuristicSummaryForUrls(urls, label);
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

String _titlesBlock(List<SavedUrl> urls, {int take = 8}) {
  return urls
      .take(take)
      .map((u) {
        final title = TitleResolver.resolveDetailTitle(
          u,
          tagFrequency: null,
        ).replaceAll('"', "'");
        final tags = TagNoiseFilter.filterTags(u.tags).take(5).join(', ');
        final summary = (u.summary ?? '').replaceAll('"', "'").trim();
        final bits = <String>[
          'title: "$title"',
          if (tags.isNotEmpty) 'tags: [$tags]',
          if (u.category.trim().isNotEmpty) 'category: ${u.category}',
          if (summary.isNotEmpty) 'summary: $summary',
        ];
        return '{${bits.join('; ')}}';
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
        final indexed = group
            .take(4)
            .map((li) {
              final u = c[li];
              final safe = TitleResolver.resolveDetailTitle(
                u,
                tagFrequency: null,
              ).replaceAll('"', "'");
              final tags = TagNoiseFilter.filterTags(u.tags).take(4).join(', ');
              final suffix = tags.isEmpty ? '' : ' tags: [$tags]';
              return 'url $li: "$safe"$suffix';
            })
            .join(', ');
        buffer.writeln('  Sub-group $si (${subUrls.length} links): $indexed');
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
    if (_isWeakClusterLabel(label)) {
      label = _heuristicLabelForUrls(subUrls, fallback: 'Group ${i + 1}');
    }
    if (summary.isEmpty || summary == 'Related bookmarks.') {
      summary = _heuristicSummaryForUrls(subUrls, label);
    }

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
    'version': 9,
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
  if ((cachedCount <= _smallLibraryCacheThreshold ||
          currentEmbeddedCount <= _smallLibraryCacheThreshold) &&
      cachedCount != currentEmbeddedCount) {
    developer.log(
      'Small library cluster cache stale (cached=$cachedCount, current=$currentEmbeddedCount) — rebuilding.',
      name: 'Mindmap',
    );
    return null;
  }

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
    if (version < 9) {
      developer.log(
        'Cluster cache version $version < 9 — rebuilding.',
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
/// message passing handles `List<List<double>>` fine as long as the inner lists
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

        final mutableGroups = localGroups
            .map((g) => List<int>.from(g))
            .toList();
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
          subLocalGroups[ci] = valid.length >= kMinSubClusterCount
              ? valid
              : null;

          developer.log(
            'Cluster[$ci]: reassigned $moved URL(s) across sub-clusters.',
            name: 'Mindmap',
          );
        }
      }

      // ── Step 3c: build ClusterTheme objects ────────────────────────────────
      themes = List<ClusterTheme>.generate(topClusters.length, (i) {
        final c = topClusters[i];

        if (c.length == 1) return _singletonClusterTheme(c, i);

        // Find the Gemini name row for this cluster.
        Map<String, dynamic> row;
        final namePos = multiIndices.indexOf(i);
        if (namePos >= 0 && namePos < names.length) {
          row = names[namePos];
        } else {
          final fallbackLabel = _heuristicLabelForUrls(c);
          row = {
            'label': fallbackLabel,
            'summary': _heuristicSummaryForUrls(c, fallbackLabel),
            'subLabels': <Map<String, String>>[],
          };
        }
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

        var label = row['label'] as String? ?? '';
        if (_isWeakClusterLabel(label)) {
          label = _heuristicLabelForUrls(c);
        }
        var summary = row['summary'] as String? ?? '';
        if (summary.trim().isEmpty || summary == 'Related bookmarks.') {
          summary = _heuristicSummaryForUrls(c, label);
        }

        developer.log(
          'Cluster[$i] "$label": ${c.length} URLs, '
          '${subClusters.length} sub-clusters.',
          name: 'Mindmap',
        );

        return ClusterTheme(
          index: i,
          label: label,
          summary: summary,
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

  themes = _mergeDuplicateThemes(themes);
  themes = _promoteForeignSubClusters(themes);

  await _writeClusterCache(prefs, urls.length, themes);
  developer.log(
    'Cluster build complete. ${themes.length} themes, '
    '${themes.where((t) => t.hasSubClusters).length} with sub-clusters.',
    name: 'Mindmap',
  );
  return themes;
}
