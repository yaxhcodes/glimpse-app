import 'package:shared_preferences/shared_preferences.dart';

import '../../notifications/gemini_copywriter.dart';
import '../models/saved_url.dart';
import 'link_scorer.dart';
import 'summary_trimmer.dart';
import 'tag_analyzer.dart';
import 'title_resolver.dart';
import 'user_fingerprint.dart';

/// Generates notification copy for all 6 types using real data.
/// Templates rotate via a stored index per type.
class NotificationTemplates {
  NotificationTemplates._();

  /// Whether this type would produce a notification (no side effects, no index rotation).
  static bool isEligible(String type, UserFingerprint fp) {
    switch (type) {
      case 'G':
        return fp.queuedDueLinks.isNotEmpty;
      case 'A':
        return fp.geographySpread.length >= 3 && fp.unreadGeoCount >= 5;
      case 'B':
        if (fp.newTagsThisWeek.isEmpty) return false;
        for (final tag in fp.newTagsThisWeek) {
          if (fp.savesWithNewTag(tag) >= 2) return true;
        }
        return false;
      case 'C':
        if (fp.topClusters.isEmpty) return false;
        final cluster = fp.topClusters.first;
        if (cluster.unreadCount < 6) return false;
        final catLink = fp.topUnreadByCategory[cluster.name];
        final oldestDays = catLink != null
            ? DateTime.now().difference(catLink.savedAt).inDays
            : 0;
        return oldestDays >= 3;
      case 'D':
        return fp.savingStreakDays >= 3 && fp.unreadStreak >= 3;
      case 'E':
        final link = fp.topUnreadLink;
        return fp.oldestUnreadDays >= 10 &&
            link != null &&
            LinkScorer.isEligible(link);
      case 'F':
        return fp.weeklyDigestReady;
      default:
        return false;
    }
  }

  static const _indexPrefix = 'last_template_index_';

  static Future<int> _nextIndex(String type, int poolSize) async {
    final p = await SharedPreferences.getInstance();
    final key = '$_indexPrefix$type';
    final current = p.getInt(key) ?? -1;
    final next = (current + 1) % poolSize;
    await p.setInt(key, next);
    return next;
  }

  static Map<String, int> _tagCounts(List<SavedUrl> urls) {
    final counts = <String, int>{};
    for (final u in urls) {
      for (final t in u.tags) {
        final k = t.toLowerCase().trim();
        if (k.isEmpty) continue;
        counts[k] = (counts[k] ?? 0) + 1;
      }
    }
    return counts;
  }

  static String _relativeDay(DateTime d) {
    final diff = DateTime.now().difference(d).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    if (diff < 7) return days[d.weekday - 1];
    if (diff < 14) return 'last ${days[d.weekday - 1]}';
    return '$diff days ago';
  }

  static String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  // ─── Type A: Geography collector ───────────────────────────────────

  static Future<NotifCopy?> geographyCollector(UserFingerprint fp) async {
    if (fp.geographySpread.length < 3) return null;
    if (fp.unreadGeoCount < 5) return null;

    final n = fp.geographySpread.length;
    final topGeo = _titleCase(fp.geographySpread.first);
    final topCount = fp.geoSaveCounts[fp.geographySpread.first] ?? 0;
    final unreadGeo = fp.unreadGeoCount;
    final geo1 = _titleCase(fp.geographySpread[0]);
    final geo2 = _titleCase(fp.geographySpread.length > 1 ? fp.geographySpread[1] : fp.geographySpread[0]);
    final geo3 = _titleCase(fp.geographySpread.length > 2 ? fp.geographySpread[2] : geo2);

    final templates = <NotifCopy>[
      NotifCopy(
        title: 'Trails from $n countries. $topGeo is leading.',
        body: "You've saved $topCount links there and haven't opened one.",
      ),
      NotifCopy(
        title: '$geo1, $geo2, $geo3 — all in your unread list.',
        body: 'Building a bucket list or just collecting?',
      ),
      NotifCopy(
        title: 'Your most saved destination: $topGeo',
        body: '$topCount links saved. $unreadGeo still unread.',
      ),
      NotifCopy(
        title: '$n countries in your saves this week.',
        body: 'Where are you actually going first?',
      ),
      NotifCopy(
        title: "You've been saving from $geo1 to $geo2.",
        body: '$unreadGeo unread links across all of them.',
      ),
    ];

    final idx = await _nextIndex('A', templates.length);
    return templates[idx];
  }

  // ─── Type B: New interest detected ─────────────────────────────────

  static Future<NotifCopy?> newInterest(UserFingerprint fp) async {
    if (fp.newTagsThisWeek.isEmpty) return null;

    String? bestTag;
    int bestCount = 0;
    for (final tag in fp.newTagsThisWeek) {
      final c = fp.savesWithNewTag(tag);
      if (c >= 2 && c > bestCount) {
        bestCount = c;
        bestTag = tag;
      }
    }
    if (bestTag == null) return null;

    final tag = _titleCase(bestTag);
    final count = bestCount;

    final templates = <NotifCopy>[
      NotifCopy(
        title: "First time you've saved anything about $tag.",
        body: '$count links already. New rabbit hole unlocked.',
      ),
      NotifCopy(
        title: '$tag just showed up in your saves.',
        body: "You've saved $count of these in the last few days.",
      ),
      NotifCopy(
        title: 'New topic alert: $tag',
        body: '$count saves this week. Looks like something clicked.',
      ),
      NotifCopy(
        title: "You hadn't saved anything about $tag before.",
        body: 'Now you have $count. Worth a look while it\'s fresh.',
      ),
    ];

    final idx = await _nextIndex('B', templates.length);
    return templates[idx];
  }

  // ─── Type C: Deep collector nudge ──────────────────────────────────

  static Future<NotifCopy?> deepCollector(UserFingerprint fp) async {
    if (fp.topClusters.isEmpty) return null;
    final cluster = fp.topClusters.first;
    if (cluster.unreadCount < 6) return null;

    final catLink = fp.topUnreadByCategory[cluster.name];
    final oldestDays = catLink != null
        ? DateTime.now().difference(catLink.savedAt).inDays
        : 0;
    if (oldestDays < 3) return null;

    final name = _titleCase(cluster.name);
    final count = cluster.unreadCount;

    final templates = <NotifCopy>[
      NotifCopy(
        title: 'You clearly know a lot about $name.',
        body: "$count links saved. Still haven't opened one.",
      ),
      NotifCopy(
        title: '$name — $count saves, 0 reads.',
        body: 'Classic. Want to change that today?',
      ),
      NotifCopy(
        title: 'Your $name collection is getting serious.',
        body: '$count unread. Maybe start with the oldest one?',
      ),
      NotifCopy(
        title: 'You keep adding to $name.',
        body: '$count links saved over $oldestDays days. All unread.',
      ),
      NotifCopy(
        title: '$count $name links sitting unread.',
        body: 'Your future self saved these for a reason.',
      ),
    ];

    final idx = await _nextIndex('C', templates.length);
    return templates[idx];
  }

  // ─── Type D: Saving streak, not reading ────────────────────────────

  static Future<NotifCopy?> streakNoReading(UserFingerprint fp) async {
    if (fp.savingStreakDays < 3) return null;
    if (fp.unreadStreak < 3) return null;

    final days = fp.savingStreakDays;
    final dc = _titleCase(fp.dominantCluster);
    final totalSaved = fp.totalSavedThisWeek;
    final totalTags = fp.allUrls
        .expand((u) => u.tags)
        .map((t) => t.toLowerCase().trim())
        .toSet()
        .length;

    final templates = <NotifCopy>[
      NotifCopy(
        title: '$days days of saving. 0 days of reading.',
        body: 'Your most saved topic: $dc. Time to open one?',
      ),
      NotifCopy(
        title: "You're on a saving streak.",
        body: '$totalSaved links in $days days. All unread. Impressive.',
      ),
      NotifCopy(
        title: '$totalSaved links saved this week.',
        body: '$dc is taking over. Want to start there?',
      ),
      NotifCopy(
        title: 'Great week for saving. Less great for reading.',
        body: '$days days, $totalSaved links, $totalTags tags. All yours.',
      ),
    ];

    final idx = await _nextIndex('D', templates.length);
    return templates[idx];
  }

  // ─── Type E: Resurface a specific link ─────────────────────────────

  static Future<NotifCopy?> resurface(UserFingerprint fp) async {
    if (fp.oldestUnreadDays < 10) return null;
    final link = fp.topUnreadLink;
    if (link == null) return null;
    if (!LinkScorer.isEligible(link)) return null;

    final daysAgo = DateTime.now().difference(link.savedAt).inDays;
    final tagCounts = _tagCounts(fp.allUrls);
    final rawSnippet = (link.summary ?? '').trim().isNotEmpty
        ? link.summary!.trim()
        : TitleResolver.resolve(link, tagFrequency: tagCounts);
    final summary = SummaryTrimmer.trim(rawSnippet, maxLength: 70);
    final relDay = _relativeDay(link.savedAt);

    final templates = <NotifCopy>[
      NotifCopy(title: 'You saved this $daysAgo days ago.', body: summary),
      NotifCopy(title: 'Still unread from $relDay:', body: summary),
      NotifCopy(title: "This one's been waiting $daysAgo days.", body: summary),
      NotifCopy(title: 'You thought this was worth saving.', body: '$summary — still relevant?'),
    ];

    final idx = await _nextIndex('E', templates.length);
    return templates[idx];
  }

  // ─── Type F: Weekly digest ─────────────────────────────────────────

  static Future<NotifCopy?> weeklyDigest(UserFingerprint fp) async {
    if (!fp.weeklyDigestReady) return null;

    final hookLink = fp.topUnreadLink;
    final tagCounts = _tagCounts(fp.allUrls);
    final hook = hookLink == null
        ? 'Your weekly reading roundup'
        : SummaryTrimmer.trim(
            (hookLink.summary ?? '').trim().isNotEmpty
                ? hookLink.summary!.trim()
                : TitleResolver.resolve(hookLink, tagFrequency: tagCounts),
            maxLength: 50,
          );

    final n = fp.totalSavedThisWeek;
    final dc = _titleCase(fp.dominantCluster);
    final unread = fp.totalUnread;
    final distinctTags = fp.allUrls
        .where((u) => u.savedAt.isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .expand((u) => u.tags)
        .map((t) => t.toLowerCase().trim())
        .toSet()
        .length;

    // Find quietest category this week.
    final catCounts = <String, int>{};
    for (final u in fp.allUrls) {
      if (!u.savedAt.isAfter(DateTime.now().subtract(const Duration(days: 7)))) continue;
      final cat = u.effectiveCategories.first;
      catCounts[cat] = (catCounts[cat] ?? 0) + 1;
    }
    String? quietest;
    int qCount = 999;
    for (final e in catCounts.entries) {
      if (e.value < qCount) {
        qCount = e.value;
        quietest = e.key;
      }
    }

    final hasNewGeo = fp.newTagsThisWeek.any(
      (t) => TagAnalyzer.geoKeywords.any((kw) => t.toLowerCase().contains(kw)),
    );
    final newGeo = hasNewGeo
        ? fp.newTagsThisWeek.firstWhere(
            (t) => TagAnalyzer.geoKeywords.any((kw) => t.toLowerCase().contains(kw)),
          )
        : null;

    final title = hook;
    final bodies = <String>[
      'Plus ${n - 1} more from this week. Busiest topic: $dc.',
      if (quietest != null) 'Your quietest category: $quietest. Busiest: $dc.',
      if (newGeo != null) 'First ${_titleCase(newGeo)} save this week — and ${n - 1} others.',
      '$n saves, $distinctTags topics, $unread unread. Good week.',
    ];

    final idx = await _nextIndex('F', bodies.length);
    return NotifCopy(title: title, body: bodies[idx % bodies.length]);
  }
}
