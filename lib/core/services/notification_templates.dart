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
        // Need a clearly-featured place with real unread depth to revisit.
        return fp.featuredGeo != null && fp.featuredGeoUnreadCount >= 3;
      case 'B':
        if (fp.newTagsThisWeek.isEmpty) return false;
        for (final tag in fp.newTagsThisWeek) {
          if (fp.savesWithNewTag(tag) >= 2) return true;
        }
        return false;
      case 'C':
        // Deep-dive pile (tag cluster or category fallback) with real depth.
        return fp.deepDiveName != null &&
            fp.deepDiveUnread >= 6 &&
            fp.deepDiveOldestDays >= 3;
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
    final rawGeo = fp.featuredGeo;
    if (rawGeo == null || fp.featuredGeoUnreadCount < 3) return null;

    // Every line is about ONE place and ONLY that place's unread saves.
    final geo = _titleCase(rawGeo);
    final unread = fp.featuredGeoUnreadCount;

    final templates = <NotifCopy>[
      NotifCopy(
        title: 'Planning around $geo again?',
        body: '$unread saved ideas are ready to revisit.',
      ),
      NotifCopy(
        title: '$geo is back on the map',
        body: '$unread saves could help you pick up the thread.',
      ),
      NotifCopy(
        title: "$geo keeps pulling you in",
        body: '$unread saved spots are still worth a look.',
      ),
      NotifCopy(
        title: 'Still curious about $geo?',
        body: '$unread saves are waiting for the right moment.',
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
        title: '$tag just became a thread.',
        body: '$count saves already. Worth following while it is fresh.',
      ),
      NotifCopy(
        title: 'Your $tag curiosity is growing.',
        body: '$count saves in the last few days.',
      ),
      NotifCopy(
        title: '$tag keeps showing up.',
        body: '$count saves this week. Something clicked.',
      ),
      NotifCopy(
        title: 'A new $tag trail is forming.',
        body: 'You have $count saves. Start with one.',
      ),
    ];

    final idx = await _nextIndex('B', templates.length);
    return templates[idx];
  }

  // ─── Type C: Deep collector nudge ──────────────────────────────────

  static Future<NotifCopy?> deepCollector(UserFingerprint fp) async {
    final rawName = fp.deepDiveName;
    if (rawName == null || fp.deepDiveUnread < 6 || fp.deepDiveOldestDays < 3) {
      return null;
    }

    final name = _titleCase(rawName);
    final count = fp.deepDiveUnread;
    final oldestDays = fp.deepDiveOldestDays;

    final templates = <NotifCopy>[
      NotifCopy(
        title: 'Continue your $name thread.',
        body: "$count saves are still waiting for a first read.",
      ),
      NotifCopy(
        title: '$name is ready when you are.',
        body: '$count unread saves. Start with the oldest one?',
      ),
      NotifCopy(
        title: '$name is becoming a real pattern.',
        body: '$count unread. Maybe start with the oldest one?',
      ),
      NotifCopy(
        title: 'You keep adding to $name.',
        body: '$count saves over $oldestDays days. All unread.',
      ),
      NotifCopy(
        title: '$count $name saves are waiting.',
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
        : TitleResolver.resolveDetailTitle(link, tagFrequency: tagCounts);
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
                : TitleResolver.resolveDetailTitle(hookLink, tagFrequency: tagCounts),
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
