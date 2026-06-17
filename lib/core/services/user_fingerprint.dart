import '../database/isar_service.dart';
import '../models/saved_url.dart';
import 'link_scorer.dart';
import 'tag_analyzer.dart';

class UserFingerprint {
  final double saveVelocity;
  final String dominantCluster;
  final List<TagCluster> topClusters;

  /// The "deep collector" group worth nudging: a topical pile with enough
  /// unread to revisit. Prefers a tag cluster, but falls back to a category so
  /// a large library always has one even when tags don't cluster cleanly.
  final String? deepDiveName;
  final int deepDiveUnread;
  final int deepDiveOldestDays;

  /// How to collect the deep-dive group's links: by [deepDiveCategory] (when
  /// category-based) or by matching [deepDiveTags] (when cluster-based).
  final String? deepDiveCategory;
  final Set<String> deepDiveTags;

  final List<String> geographySpread;
  final Map<String, int> geoSaveCounts;

  /// The single place to feature in a geography notification — the one with the
  /// most UNREAD saves, so the headline and the linked saves always match.
  final String? featuredGeo;
  final int featuredGeoUnreadCount;
  final List<String> newTagsThisWeek;
  final double readingRatio;
  final int unreadStreak;
  final int savingStreakDays;
  final int oldestUnreadDays;
  final SavedUrl? topUnreadLink;
  final Map<String, SavedUrl> topUnreadByCategory;
  final bool weeklyDigestReady;

  final int totalSavedThisWeek;
  final int totalUnread;
  final List<SavedUrl> allUrls;

  /// Saves the user explicitly bookmarked to return to and whose [revisitAfter]
  /// moment has arrived — the trigger for the revisit-due notification.
  final List<SavedUrl> queuedDueLinks;

  /// Total saves currently queued for revisit (due or not).
  final int queuedCount;

  const UserFingerprint({
    required this.saveVelocity,
    required this.dominantCluster,
    required this.topClusters,
    required this.deepDiveName,
    required this.deepDiveUnread,
    required this.deepDiveOldestDays,
    required this.deepDiveCategory,
    required this.deepDiveTags,
    required this.geographySpread,
    required this.geoSaveCounts,
    required this.featuredGeo,
    required this.featuredGeoUnreadCount,
    required this.newTagsThisWeek,
    required this.readingRatio,
    required this.unreadStreak,
    required this.savingStreakDays,
    required this.oldestUnreadDays,
    required this.topUnreadLink,
    required this.topUnreadByCategory,
    required this.weeklyDigestReady,
    required this.totalSavedThisWeek,
    required this.totalUnread,
    required this.allUrls,
    required this.queuedDueLinks,
    required this.queuedCount,
  });

  static Future<UserFingerprint> compute(IsarService isar) async {
    final allUrls = await isar.getAllUrls();
    if (allUrls.isEmpty) return _empty(allUrls);

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // ── Save velocity ──
    final thisWeekSaves = allUrls.where((u) => u.savedAt.isAfter(weekAgo)).length;
    final lastWeekSaves = allUrls.where((u) =>
      u.savedAt.isAfter(twoWeeksAgo) && u.savedAt.isBefore(weekAgo),
    ).length;
    final velocityThisWeek = thisWeekSaves / 7.0;
    final velocityLastWeek = lastWeekSaves / 7.0;
    final saveVelocity = velocityLastWeek > 0
        ? velocityThisWeek / velocityLastWeek
        : velocityThisWeek;

    // ── Tag clusters ──
    final clusters = TagAnalyzer.computeClusters(allUrls);
    final topClusters = clusters.take(3).toList();
    final dominantCluster = clusters.isNotEmpty ? clusters.first.name : 'General';

    // ── Deep-dive group (the "deep collector" nudge) ──
    final deepDive = selectDeepDive(allUrls, topClusters, now);
    final deepDiveName = deepDive.name;
    final deepDiveCategory = deepDive.category;
    final deepDiveTags = deepDive.tags;
    final deepDiveUnread = deepDive.unread;
    final deepDiveOldestDays = deepDive.oldestDays;

    // ── Geography ──
    final geoSaveCounts = TagAnalyzer.detectGeography(allUrls);
    final geographySpread = geoSaveCounts.keys.toList()
      ..sort((a, b) => (geoSaveCounts[b] ?? 0).compareTo(geoSaveCounts[a] ?? 0));

    // Feature the place with the most UNREAD saves so a geography notification's
    // headline and its linked saves never disagree.
    String? featuredGeo;
    var featuredGeoUnreadCount = 0;
    for (final geo in geographySpread) {
      final n = TagAnalyzer.unreadLinksForGeo(allUrls, geo).length;
      if (n > featuredGeoUnreadCount) {
        featuredGeoUnreadCount = n;
        featuredGeo = geo;
      }
    }

    // ── New tags this week ──
    final newTagsThisWeek = TagAnalyzer.findNewTags(allUrls);

    // ── Reading ratio (last 30 days) ──
    final last30 = allUrls.where((u) => u.savedAt.isAfter(thirtyDaysAgo)).toList();
    final reads30 = last30.where((u) => u.openedAt != null).length;
    final readingRatio = last30.isNotEmpty ? reads30 / last30.length : 0.0;

    // ── Unread streak (consecutive days saving but reading nothing) ──
    int unreadStreak = 0;
    {
      final today = DateTime(now.year, now.month, now.day);
      for (var d = 0; d <= 365; d++) {
        final day = today.subtract(Duration(days: d));
        final dayEnd = day.add(const Duration(days: 1));
        final savedThatDay = allUrls.any(
          (u) => u.savedAt.isAfter(day) && u.savedAt.isBefore(dayEnd),
        );
        final readThatDay = allUrls.any(
          (u) => u.openedAt != null &&
                 u.openedAt!.isAfter(day) && u.openedAt!.isBefore(dayEnd),
        );
        if (savedThatDay && !readThatDay) {
          unreadStreak++;
        } else {
          break;
        }
      }
    }

    // ── Queued-for-revisit (explicit intent from Details chips) ──
    final queued = allUrls.where((u) => u.isQueued).toList();
    final queuedDueLinks = queued.where((u) => u.isRevisitDue).toList()
      ..sort((a, b) => (a.revisitAfter ?? a.savedAt)
          .compareTo(b.revisitAfter ?? b.savedAt));

    // ── Saving streak days ──
    final savingStreakDays = await isar.getSavingStreakDays();

    // ── Oldest unread (non-social shortlink) ──
    final unreadSorted = allUrls
        .where((u) => u.openedAt == null && !u.isDone)
        .toList()
      ..sort((a, b) => a.savedAt.compareTo(b.savedAt));
    final oldestUnread = unreadSorted.isNotEmpty ? unreadSorted.first : null;
    final oldestUnreadDays = oldestUnread != null
        ? now.difference(oldestUnread.savedAt).inDays
        : 0;

    // ── Top unread link (highest score) ──
    SavedUrl? topUnreadLink;
    int topScore = 0;
    for (final u in unreadSorted) {
      final s = LinkScorer.score(u);
      if (s > topScore) {
        topScore = s;
        topUnreadLink = u;
      }
    }

    // ── Top unread by category ──
    final topUnreadByCategory = <String, SavedUrl>{};
    for (final u in unreadSorted) {
      final cat = u.effectiveCategories.first;
      if (!topUnreadByCategory.containsKey(cat)) {
        topUnreadByCategory[cat] = u;
      } else {
        final existing = topUnreadByCategory[cat]!;
        if (LinkScorer.score(u) > LinkScorer.score(existing)) {
          topUnreadByCategory[cat] = u;
        }
      }
    }

    return UserFingerprint(
      saveVelocity: saveVelocity,
      dominantCluster: dominantCluster,
      topClusters: topClusters,
      deepDiveName: deepDiveName,
      deepDiveUnread: deepDiveUnread,
      deepDiveOldestDays: deepDiveOldestDays,
      deepDiveCategory: deepDiveCategory,
      deepDiveTags: deepDiveTags,
      geographySpread: geographySpread,
      geoSaveCounts: geoSaveCounts,
      featuredGeo: featuredGeo,
      featuredGeoUnreadCount: featuredGeoUnreadCount,
      newTagsThisWeek: newTagsThisWeek,
      readingRatio: readingRatio,
      unreadStreak: unreadStreak,
      savingStreakDays: savingStreakDays,
      oldestUnreadDays: oldestUnreadDays,
      topUnreadLink: topUnreadLink,
      topUnreadByCategory: topUnreadByCategory,
      weeklyDigestReady: thisWeekSaves >= 5,
      totalSavedThisWeek: thisWeekSaves,
      totalUnread: unreadSorted.length,
      allUrls: allUrls,
      queuedDueLinks: queuedDueLinks,
      queuedCount: queued.length,
    );
  }

  /// Selects the "deep collector" pile worth nudging. Prefers a tag cluster
  /// with real unread depth; otherwise falls back to the category with the most
  /// unread, so a large library always has a pile to revisit even when its tags
  /// don't cluster. Pure — unit-testable without a database.
  static ({
    String? name,
    int unread,
    int oldestDays,
    String? category,
    Set<String> tags,
  }) selectDeepDive(
    List<SavedUrl> allUrls,
    List<TagCluster> topClusters,
    DateTime now,
  ) {
    String? name;
    String? category;
    var tags = <String>{};
    var unread = 0;

    final bestCluster = topClusters.isNotEmpty ? topClusters.first : null;
    if (bestCluster != null && bestCluster.unreadCount >= 6) {
      name = bestCluster.name;
      tags = bestCluster.tags;
      unread = bestCluster.unreadCount;
    } else {
      final catUnread = <String, int>{};
      for (final u in allUrls) {
        if (u.openedAt != null || u.isDone) continue;
        final cat = u.effectiveCategories.first;
        if (cat == 'Other') continue;
        catUnread[cat] = (catUnread[cat] ?? 0) + 1;
      }
      String? bestCat;
      var bestN = 0;
      for (final e in catUnread.entries) {
        if (e.value > bestN) {
          bestN = e.value;
          bestCat = e.key;
        }
      }
      if (bestCat != null) {
        name = bestCat;
        category = bestCat;
        unread = bestN;
      }
    }

    var oldestDays = 0;
    if (name != null) {
      DateTime? oldest;
      for (final u in allUrls) {
        if (u.openedAt != null || u.isDone) continue;
        final inGroup = category != null
            ? u.effectiveCategories.first == category
            : u.tags.any((t) => tags.contains(t.toLowerCase().trim()));
        if (!inGroup) continue;
        if (oldest == null || u.savedAt.isBefore(oldest)) oldest = u.savedAt;
      }
      if (oldest != null) oldestDays = now.difference(oldest).inDays;
    }

    return (
      name: name,
      unread: unread,
      oldestDays: oldestDays,
      category: category,
      tags: tags,
    );
  }

  static UserFingerprint _empty(List<SavedUrl> urls) => UserFingerprint(
        saveVelocity: 0,
        dominantCluster: 'General',
        topClusters: [],
        deepDiveName: null,
        deepDiveUnread: 0,
        deepDiveOldestDays: 0,
        deepDiveCategory: null,
        deepDiveTags: const {},
        geographySpread: [],
        geoSaveCounts: {},
        featuredGeo: null,
        featuredGeoUnreadCount: 0,
        newTagsThisWeek: [],
        readingRatio: 0,
        unreadStreak: 0,
        savingStreakDays: 0,
        oldestUnreadDays: 0,
        topUnreadLink: null,
        topUnreadByCategory: {},
        weeklyDigestReady: false,
        totalSavedThisWeek: 0,
        totalUnread: 0,
        allUrls: urls,
        queuedDueLinks: const [],
        queuedCount: 0,
      );

  /// Count of unread geo-tagged links.
  int get unreadGeoCount => TagAnalyzer.unreadGeoLinks(allUrls).length;

  /// Count of saves carrying a new tag this week.
  int savesWithNewTag(String tag) =>
      TagAnalyzer.countSavesWithTag(allUrls, tag);
}
