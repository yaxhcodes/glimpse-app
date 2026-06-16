import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_url.dart';

class TagCluster {
  final String name;
  final Set<String> tags;
  final int saveCount;
  final int unreadCount;

  const TagCluster({
    required this.name,
    required this.tags,
    required this.saveCount,
    required this.unreadCount,
  });
}

class TagAnalyzer {
  TagAnalyzer._();

  static const geoKeywords = [
    'india', 'new zealand', 'switzerland', 'kyrgyzstan', 'nepal',
    'iceland', 'japan', 'italy', 'peru', 'norway', 'canada',
    'scotland', 'morocco', 'georgia', 'vietnam', 'indonesia',
    'thailand', 'mexico', 'colombia', 'argentina', 'chile',
    'turkey', 'greece', 'spain', 'portugal', 'france', 'germany',
    'austria', 'australia', 'kenya', 'tanzania', 'south africa',
    'egypt', 'brazil', 'costa rica', 'patagonia', 'ladakh',
    'himalayas', 'alps', 'andes', 'dolomites', 'sahara',
  ];

  /// Groups of tags that co-occur across 3+ saves.
  static List<TagCluster> computeClusters(List<SavedUrl> urls) {
    // Build co-occurrence counts for tag pairs.
    final pairCount = <String, int>{};
    final tagFreq = <String, int>{};
    final tagUrls = <String, List<SavedUrl>>{};

    for (final u in urls) {
      final tags = u.tags.map((t) => t.toLowerCase().trim()).where((t) => t.isNotEmpty).toSet();
      for (final t in tags) {
        tagFreq[t] = (tagFreq[t] ?? 0) + 1;
        (tagUrls[t] ??= []).add(u);
      }
      final sorted = tags.toList()..sort();
      for (var i = 0; i < sorted.length; i++) {
        for (var j = i + 1; j < sorted.length; j++) {
          final key = '${sorted[i]}|||${sorted[j]}';
          pairCount[key] = (pairCount[key] ?? 0) + 1;
        }
      }
    }

    // Find pairs with co-occurrence >= 3 and merge into clusters.
    final adj = <String, Set<String>>{};
    for (final e in pairCount.entries) {
      if (e.value < 3) continue;
      final parts = e.key.split('|||');
      (adj[parts[0]] ??= {}).add(parts[1]);
      (adj[parts[1]] ??= {}).add(parts[0]);
    }

    // BFS to find connected components.
    final visited = <String>{};
    final clusters = <TagCluster>[];

    for (final start in adj.keys) {
      if (visited.contains(start)) continue;
      final component = <String>{};
      final queue = [start];
      while (queue.isNotEmpty) {
        final node = queue.removeLast();
        if (!component.add(node)) continue;
        visited.add(node);
        for (final neighbor in adj[node] ?? <String>{}) {
          if (!component.contains(neighbor)) queue.add(neighbor);
        }
      }

      // Name after most frequent tag in the cluster.
      String? bestTag;
      int bestFreq = 0;
      for (final t in component) {
        final f = tagFreq[t] ?? 0;
        if (f > bestFreq) {
          bestFreq = f;
          bestTag = t;
        }
      }

      // Count unique saves and unread saves touching this cluster.
      final clusterUrls = <int>{};
      int unread = 0;
      for (final t in component) {
        for (final u in tagUrls[t] ?? <SavedUrl>[]) {
          if (clusterUrls.add(u.id)) {
            if (u.openedAt == null) unread++;
          }
        }
      }

      if (bestTag != null) {
        clusters.add(TagCluster(
          name: bestTag,
          tags: component,
          saveCount: clusterUrls.length,
          unreadCount: unread,
        ));
      }
    }

    clusters.sort((a, b) => b.unreadCount.compareTo(a.unreadCount));
    return clusters;
  }

  /// Scan tags against geo keywords. Returns geo → save count.
  static Map<String, int> detectGeography(List<SavedUrl> urls) {
    final geo = <String, int>{};
    for (final u in urls) {
      for (final tag in u.tags) {
        final lower = tag.toLowerCase().trim();
        for (final kw in geoKeywords) {
          if (lower.contains(kw)) {
            geo[kw] = (geo[kw] ?? 0) + 1;
            break;
          }
        }
      }
    }
    return geo;
  }

  /// Unread links that have a geo tag.
  static List<SavedUrl> unreadGeoLinks(List<SavedUrl> urls) {
    final out = <SavedUrl>[];
    for (final u in urls) {
      if (u.openedAt != null || u.isDone) continue;
      for (final tag in u.tags) {
        final lower = tag.toLowerCase().trim();
        if (geoKeywords.any((kw) => lower.contains(kw))) {
          out.add(u);
          break;
        }
      }
    }
    return out;
  }

  /// Unread links tagged with one specific place [geo] (a [geoKeywords] entry).
  /// Used to keep a geography notification's headline and its linked saves in
  /// sync — "your Kerala saves" must only contain Kerala saves.
  static List<SavedUrl> unreadLinksForGeo(List<SavedUrl> urls, String geo) {
    final needle = geo.toLowerCase().trim();
    if (needle.isEmpty) return const [];
    final out = <SavedUrl>[];
    for (final u in urls) {
      if (u.openedAt != null || u.isDone) continue;
      if (u.tags.any((t) => t.toLowerCase().contains(needle))) {
        out.add(u);
      }
    }
    return out;
  }

  /// Tags that appear this week but never before.
  static List<String> findNewTags(List<SavedUrl> urls) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day);

    final oldTags = <String>{};
    final newTags = <String>{};

    for (final u in urls) {
      final tags = u.tags.map((t) => t.toLowerCase().trim()).where((t) => t.isNotEmpty);
      if (u.savedAt.isBefore(weekStart)) {
        oldTags.addAll(tags);
      } else {
        newTags.addAll(tags);
      }
    }

    return newTags.difference(oldTags).toList();
  }

  /// Count of saves carrying a specific tag (case-insensitive).
  static int countSavesWithTag(List<SavedUrl> urls, String tag) {
    final lower = tag.toLowerCase();
    return urls.where((u) =>
      u.tags.any((t) => t.toLowerCase().trim() == lower) &&
      u.savedAt.isAfter(DateTime.now().subtract(const Duration(days: 7)))
    ).length;
  }

  /// Dominant topic = cluster with highest unread count.
  static TagCluster? dominantTopic(List<SavedUrl> urls) {
    final clusters = computeClusters(urls);
    return clusters.isNotEmpty ? clusters.first : null;
  }

  /// Which days of the week the user most commonly saves (1=Mon, 7=Sun).
  static Map<int, int> saveDistribution(List<SavedUrl> urls) {
    final dist = <int, int>{};
    for (final u in urls) {
      final wd = u.savedAt.weekday;
      dist[wd] = (dist[wd] ?? 0) + 1;
    }
    return dist;
  }

  // ── Peak open hour tracking ──

  static const _histogramKey = 'open_hour_histogram';

  static Future<void> recordAppOpen() async {
    final p = await SharedPreferences.getInstance();
    final histogram = await _loadHistogram(p);
    final hour = DateTime.now().hour;
    histogram[hour] = (histogram[hour] ?? 0) + 1;
    await p.setString(_histogramKey, jsonEncode(
      histogram.map((k, v) => MapEntry(k.toString(), v)),
    ));
  }

  static Future<int> peakOpenHour() async {
    final p = await SharedPreferences.getInstance();
    final histogram = await _loadHistogram(p);
    if (histogram.isEmpty) return 20; // default 8pm
    int bestHour = 20;
    int bestCount = 0;
    for (final e in histogram.entries) {
      if (e.value > bestCount) {
        bestCount = e.value;
        bestHour = e.key;
      }
    }
    return bestHour;
  }

  static Future<Map<int, int>> _loadHistogram(SharedPreferences p) async {
    final s = p.getString(_histogramKey);
    if (s == null) return {};
    try {
      final decoded = jsonDecode(s) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(int.parse(k), (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }
}
