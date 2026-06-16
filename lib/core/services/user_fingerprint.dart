import '../database/isar_service.dart';
import '../models/saved_url.dart';
import 'link_scorer.dart';
import 'tag_analyzer.dart';

class UserFingerprint {
  final double saveVelocity;
  final String dominantCluster;
  final List<TagCluster> topClusters;
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

  static UserFingerprint _empty(List<SavedUrl> urls) => UserFingerprint(
        saveVelocity: 0,
        dominantCluster: 'General',
        topClusters: [],
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
