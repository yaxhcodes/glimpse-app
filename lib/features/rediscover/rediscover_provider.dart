import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/category_resolver.dart';
import '../../core/services/rediscovery_service.dart';
import '../../core/services/revisit_scorer.dart';
import '../../core/services/title_resolver.dart';
import '../goals/memory_goals_provider.dart';
import '../home/home_provider.dart';
import 'rediscover_memory_prefs.dart';

/// A rediscovery item enriched with a "why now" reason and relative time.
class RediscoveryItem {
  final SavedUrl url;
  final String reason;
  final String timeAgo;

  const RediscoveryItem({
    required this.url,
    required this.reason,
    required this.timeAgo,
  });
}

/// Headline stats that give the page a sense of purpose.
typedef RediscoveryStats = ({int total, int unopened});

enum RediscoverRecapCadence { daily, weekly, monthly }

class RediscoverRecap {
  const RediscoverRecap({
    required this.cadence,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.generatedAt,
    required this.reason,
  });

  final RediscoverRecapCadence cadence;
  final String title;
  final String subtitle;
  final List<RediscoveryItem> items;
  final DateTime generatedAt;
  final String reason;
}

/// Watches the library so every rediscovery surface refreshes on save/delete/
/// dismiss, then returns all non-dismissed URLs newest-first.
Future<List<SavedUrl>> _liveUrls(Ref ref) async {
  ref.watch(
    urlStreamProvider.select(
      (async) => async.whenOrNull(data: (urls) => urls.length),
    ),
  );
  final isar = ref.read(isarServiceProvider);
  final all = await isar.getAllUrls(); // newest first
  // Exclude dismissed and "done" (archived) saves from every rediscovery surface.
  return all
      .where((u) => u.rediscoverDismissedAt == null && !u.isDone)
      .toList();
}

/// The headline shelf: saves the user explicitly bookmarked to return to
/// ("Watch Later", "Try This Weekend", …) whose moment has arrived.
final revisitQueueProvider = FutureProvider<List<RediscoveryItem>>((ref) async {
  final live = await _liveUrls(ref);
  final due = live.where((u) => u.isRevisitDue).toList()
    // Soonest-promised first (oldest revisitAfter / fallback to savedAt).
    ..sort((a, b) {
      final ra = a.revisitAfter ?? a.savedAt;
      final rb = b.revisitAfter ?? b.savedAt;
      return ra.compareTo(rb);
    });
  return due
      .take(12)
      .map(
        (u) => RediscoveryItem(
          url: u,
          reason: RevisitScorer.score(u, seeds: const []).reason,
          timeAgo: _formatTimeAgo(u.savedAt),
        ),
      )
      .toList();
});

final rediscoveryStatsProvider = FutureProvider<RediscoveryStats>((ref) async {
  final live = await _liveUrls(ref);
  final unopened = live.where((u) => u.openedAt == null).length;
  return (total: live.length, unopened: unopened);
});

final rediscoverRecapsProvider = FutureProvider<List<RediscoverRecap>>((
  ref,
) async {
  final live = await _liveUrls(ref);
  final recaps = buildRediscoverRecaps(live);
  final visible = <RediscoverRecap>[];
  for (final recap in recaps) {
    final canShow = await RediscoverMemoryPrefs.canShowRecap(
      cadence: recap.cadence.name,
      itemIds: recap.items.map((item) => item.url.id).toList(),
    );
    if (canShow) visible.add(recap);
  }
  return visible;
});

final recentlyResurfacedProvider = FutureProvider<List<RediscoveryItem>>((
  ref,
) async {
  final live = await _liveUrls(ref);
  final cutoff = DateTime.now().subtract(const Duration(days: 30));
  final resurfaced =
      live
          .where(
            (u) => u.resurfacedAt != null && u.resurfacedAt!.isAfter(cutoff),
          )
          .toList()
        ..sort((a, b) => b.resurfacedAt!.compareTo(a.resurfacedAt!));

  return resurfaced
      .take(8)
      .map(
        (u) => RediscoveryItem(
          url: u,
          reason: _resurfacedReason(u),
          timeAgo: _formatTimeAgo(u.resurfacedAt ?? u.savedAt),
        ),
      )
      .toList();
});

/// The hero queue: a small, finite, curated set of picks to triage today.
/// Blends forgotten gems, on-this-day memories and interest matches.
final todaysPicksProvider = FutureProvider<List<RediscoveryItem>>((ref) async {
  final live = await _liveUrls(ref);
  if (live.length < 4) return [];

  // Items the user explicitly bookmarked to return to, now due — these lead.
  final due = live.where((u) => u.isRevisitDue).toList()
    ..sort(
      (a, b) =>
          (a.revisitAfter ?? a.savedAt).compareTo(b.revisitAfter ?? b.savedAt),
    );
  final gems = _forgottenGems(live).take(3);
  final onThisDay = _onThisDay(live).take(2);

  final isar = ref.read(isarServiceProvider);
  final interest = await RediscoveryService(isar).getRediscoveryLinks(limit: 6);

  final picks = <SavedUrl>[];
  final seen = <int>{};
  void add(Iterable<SavedUrl> urls) {
    for (final u in urls) {
      if (seen.add(u.id)) picks.add(u);
    }
  }

  add(due.take(3));
  add(gems);
  add(onThisDay);
  add(interest);

  return picks
      .take(7)
      .map(
        (u) => RediscoveryItem(
          url: u,
          reason: _reasonFor(u, live),
          timeAgo: _formatTimeAgo(u.savedAt),
        ),
      )
      .toList();
});

/// Saves whose age lands on a memory anniversary (≈1mo / 3mo / 6mo / 1yr ago).
final onThisDayProvider = FutureProvider<List<RediscoveryItem>>((ref) async {
  final live = await _liveUrls(ref);
  return _onThisDay(live)
      .take(10)
      .map(
        (u) => RediscoveryItem(
          url: u,
          reason: _onThisDayLabel(u) ?? 'A while ago',
          timeAgo: _formatTimeAgo(u.savedAt),
        ),
      )
      .toList();
});

/// Older saves the user never opened — the real backlog worth clearing.
final forgottenGemsProvider = FutureProvider<List<RediscoveryItem>>((
  ref,
) async {
  final live = await _liveUrls(ref);
  return _forgottenGems(live)
      .take(12)
      .map(
        (u) => RediscoveryItem(
          url: u,
          reason: 'Never opened',
          timeAgo: _formatTimeAgo(u.savedAt),
        ),
      )
      .toList();
});

final neverOpenedProvider = FutureProvider<List<RediscoveryItem>>((ref) async {
  final live = await _liveUrls(ref);
  return live
      .where((u) => u.openedAt == null)
      .take(12)
      .map(
        (u) => RediscoveryItem(
          url: u,
          reason: 'Never opened',
          timeAgo: _formatTimeAgo(u.savedAt),
        ),
      )
      .toList();
});

/// Related saves, titled after the topic that ties the picks together. This is
/// supporting evidence for Rediscover, not the primary Interests surface.
typedef RelatedSavesShelf = ({String title, List<RediscoveryItem> items});
typedef InterestShelf = RelatedSavesShelf;
typedef GoalShelf = ({String title, List<RediscoveryItem> items});

final goalShelfProvider = FutureProvider<GoalShelf?>((ref) async {
  final live = await _liveUrls(ref);
  if (live.length < 3) return null;

  final goals = await ref.watch(memoryGoalsProvider.future);
  if (goals.isEmpty) return null;

  final liveIds = {for (final url in live) url.id};
  final ranked =
      goals.where((goal) {
        return goal.urls.any((url) => liveIds.contains(url.id));
      }).toList()..sort((a, b) {
        final statusRank = _goalStatusRank(
          b.status,
        ).compareTo(_goalStatusRank(a.status));
        if (statusRank != 0) return statusRank;
        return b.strength.compareTo(a.strength);
      });

  if (ranked.isEmpty) return null;
  final goal = ranked.first;
  final items = goal.urls
      .where((url) => liveIds.contains(url.id))
      .take(10)
      .map(
        (url) => RediscoveryItem(
          url: url,
          reason: _goalReason(goal.status),
          timeAgo: _formatTimeAgo(url.savedAt),
        ),
      )
      .toList();
  if (items.isEmpty) return null;
  return (title: goal.name, items: items);
});

final relatedSavesProvider = FutureProvider<RelatedSavesShelf>((ref) async {
  ref.watch(
    urlStreamProvider.select(
      (async) => async.whenOrNull(data: (urls) => urls.length),
    ),
  );
  final isar = ref.read(isarServiceProvider);
  final live = (await isar.getAllUrls())
      .where((u) => u.rediscoverDismissedAt == null)
      .toList();
  final urls = await RediscoveryService(isar).getRediscoveryLinks(limit: 12);

  final topic = _dominantCategory(urls);
  final title = topic == null
      ? 'Related saves'
      : 'More worth reopening in $topic';

  final items = urls
      .map(
        (u) => RediscoveryItem(
          url: u,
          reason: _reasonFor(u, live),
          timeAgo: _formatTimeAgo(u.savedAt),
        ),
      )
      .toList();
  return (title: title, items: items);
});

final interestShelfProvider = relatedSavesProvider;

List<RediscoverRecap> buildRediscoverRecaps(
  List<SavedUrl> live, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final recaps = <RediscoverRecap>[];
  final active = live
      .where((u) => !u.isDone && u.rediscoverDismissedAt == null)
      .toList();
  if (active.isEmpty) return const [];

  final dailyItems = _dailyRecapItems(active, clock);
  if (dailyItems.isNotEmpty) {
    recaps.add(
      RediscoverRecap(
        cadence: RediscoverRecapCadence.daily,
        title: 'Today in your saves',
        subtitle: _recapSubtitle(
          dailyItems,
          fallback: 'A few saves worth using today',
        ),
        items: dailyItems,
        generatedAt: clock,
        reason:
            'A short queue chosen from due, unopened, and time-relevant saves.',
      ),
    );
  }

  final weeklyItems = _windowRecapItems(
    active,
    clock.subtract(const Duration(days: 7)),
    clock,
    olderSupport: _forgottenGems(active).take(2),
  );
  if (weeklyItems.length >= 2) {
    final savedThisWeek = active
        .where(
          (u) => !u.savedAt.isBefore(clock.subtract(const Duration(days: 7))),
        )
        .length;
    final unopened = weeklyItems
        .where((item) => item.url.openedAt == null)
        .length;
    recaps.add(
      RediscoverRecap(
        cadence: RediscoverRecapCadence.weekly,
        title: 'Your week in saves',
        subtitle: '$savedThisWeek saved this week · $unopened waiting',
        items: weeklyItems,
        generatedAt: clock,
        reason:
            'What you captured this week, plus one older save that still fits.',
      ),
    );
  }

  final monthlyItems = _monthlyRecapItems(active, clock);
  if (monthlyItems.length >= 3) {
    final topic = _dominantCategory(
      monthlyItems.map((item) => item.url).toList(),
    );
    recaps.add(
      RediscoverRecap(
        cadence: RediscoverRecapCadence.monthly,
        title: topic == null
            ? 'Your month in memories'
            : '$topic kept showing up',
        subtitle: _recapSubtitle(
          monthlyItems,
          fallback: 'Patterns and older saves worth returning to',
        ),
        items: monthlyItems,
        generatedAt: clock,
        reason:
            'Recurring patterns from the last month, balanced with older useful saves.',
      ),
    );
  }

  return recaps;
}

List<RediscoveryItem> _dailyRecapItems(List<SavedUrl> live, DateTime now) {
  final due = live.where((u) => u.isRevisitDue).toList()
    ..sort(
      (a, b) =>
          (a.revisitAfter ?? a.savedAt).compareTo(b.revisitAfter ?? b.savedAt),
    );
  final anniversaries = _onThisDay(live);
  final forgotten = _forgottenGems(live);
  final stillWaiting = live.where((u) {
    final age = now.difference(u.savedAt).inDays;
    return u.openedAt == null && age >= 3 && age <= 21;
  }).toList()..sort((a, b) => a.savedAt.compareTo(b.savedAt));

  final picked = _uniqueUrls([
    ...due,
    ...stillWaiting,
    ...anniversaries,
    ...forgotten,
  ]).take(4);
  return picked.map((u) => _recapItem(u, live)).toList();
}

List<RediscoveryItem> _windowRecapItems(
  List<SavedUrl> live,
  DateTime start,
  DateTime end, {
  Iterable<SavedUrl> olderSupport = const [],
}) {
  final window =
      live
          .where((u) => !u.savedAt.isBefore(start) && !u.savedAt.isAfter(end))
          .toList()
        ..sort((a, b) {
          final ao = a.openedAt == null ? 0 : 1;
          final bo = b.openedAt == null ? 0 : 1;
          if (ao != bo) return ao - bo;
          return b.savedAt.compareTo(a.savedAt);
        });
  return _uniqueUrls([
    ...window,
    ...olderSupport,
  ]).take(6).map((u) => _recapItem(u, live)).toList();
}

List<RediscoveryItem> _monthlyRecapItems(List<SavedUrl> live, DateTime now) {
  final monthStart = now.subtract(const Duration(days: 30));
  final month = live.where((u) => !u.savedAt.isBefore(monthStart)).toList();
  final recurring = <SavedUrl>[];
  final categories = <String, List<SavedUrl>>{};
  for (final url in month) {
    final category = url.effectiveCategories.firstOrNull ?? url.category;
    if (CategoryResolver.isPlatformName(category) || category == 'Other') {
      continue;
    }
    (categories[category] ??= []).add(url);
  }
  final ranked = categories.entries.toList()
    ..sort((a, b) => b.value.length.compareTo(a.value.length));
  if (ranked.isNotEmpty && ranked.first.value.length >= 2) {
    recurring.addAll(ranked.first.value);
  }
  return _uniqueUrls([
    ...recurring,
    ..._forgottenGems(live),
  ]).take(6).map((u) => _recapItem(u, live)).toList();
}

Iterable<SavedUrl> _uniqueUrls(Iterable<SavedUrl> urls) sync* {
  final seen = <int>{};
  for (final url in urls) {
    if (seen.add(url.id)) yield url;
  }
}

RediscoveryItem _recapItem(SavedUrl url, List<SavedUrl> live) {
  return RediscoveryItem(
    url: url,
    reason: _reasonFor(url, live),
    timeAgo: _formatTimeAgo(url.savedAt),
  );
}

String _recapSubtitle(List<RediscoveryItem> items, {required String fallback}) {
  if (items.isEmpty) return fallback;
  final unopened = items.where((item) => item.url.openedAt == null).length;
  if (unopened == items.length) return '${items.length} unopened saves';
  final first = TitleResolver.resolveDetailTitle(items.first.url);
  return '$first and ${items.length - 1} more';
}

String _resurfacedReason(SavedUrl url) {
  final age = DateTime.now().difference(url.savedAt).inDays;
  if (age <= 1) return 'Just captured';
  if (url.openedAt == null) return 'Brought back from your saves';
  return 'Connected to something new';
}

// ── Selection helpers ──────────────────────────────────────────────────────

List<SavedUrl> _forgottenGems(List<SavedUrl> live) {
  final now = DateTime.now();
  final cutoff = now.subtract(const Duration(days: 30));
  final resurfaceCutoff = now.subtract(const Duration(days: 14));
  final gems = live.where((u) {
    if (u.openedAt != null) return false;
    if (!u.savedAt.isBefore(cutoff)) return false;
    final r = u.resurfacedAt;
    if (r != null && r.isAfter(resurfaceCutoff)) return false;
    final hasSubstance =
        (u.thumbnailUrl?.isNotEmpty ?? false) ||
        (u.enrichmentJson?.isNotEmpty ?? false) ||
        (u.summary?.isNotEmpty ?? false);
    return hasSubstance;
  }).toList()..sort((a, b) => a.savedAt.compareTo(b.savedAt)); // oldest first
  return gems;
}

List<SavedUrl> _onThisDay(List<SavedUrl> live) {
  final dated = live.where((u) => _onThisDayLabel(u) != null).toList()
    ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  return dated;
}

String? _onThisDayLabel(SavedUrl u) {
  final days = DateTime.now().difference(u.savedAt).inDays;
  bool near(int anchor) => (days - anchor).abs() <= 3;
  if (near(365)) return 'A year ago today';
  if (near(180)) return '6 months ago';
  if (near(90)) return '3 months ago';
  if (near(30)) return 'A month ago';
  return null;
}

String? _dominantCategory(List<SavedUrl> urls) {
  final counts = <String, int>{};
  for (final u in urls) {
    for (final c in u.effectiveCategories) {
      // Skip non-content buckets and platform/source names ("Instagram", "X",
      // "Web") so the topic reflects what the saves are about, not where they
      // came from. See title-and-copy-consistency-spec.md §5.
      if (c == 'Other' || c == 'Web') continue;
      if (CategoryResolver.isPlatformName(c)) continue;
      counts[c] = (counts[c] ?? 0) + 1;
    }
  }
  if (counts.isEmpty) return null;
  final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
  return top.value >= 2 ? top.key : null;
}

int _goalStatusRank(String status) {
  return switch (status) {
    'dormant' => 4,
    'cooling' => 3,
    'queued' => 2,
    'active' => 1,
    _ => 0,
  };
}

String _goalReason(String status) {
  return switch (status) {
    'dormant' => 'Dormant goal',
    'cooling' => 'Cooling goal',
    'queued' => 'Saved goal',
    'active' => 'Growing goal',
    _ => 'Memory goal',
  };
}

String _reasonFor(SavedUrl url, List<SavedUrl> live) {
  if (url.isRevisitDue) return RevisitScorer.score(url, seeds: const []).reason;
  final onThisDay = _onThisDayLabel(url);
  if (onThisDay != null) return onThisDay;
  if (url.openedAt == null) return 'Never opened';

  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));
  final recent = live
      .where((u) => u.savedAt.isAfter(weekAgo) && u.id != url.id)
      .toList();
  if (recent.isNotEmpty) {
    final recentTags = recent
        .expand((u) => u.tags)
        .map((t) => t.toLowerCase())
        .toSet();
    final recentCats = recent
        .expand((u) => u.effectiveCategories)
        .map((c) => c.toLowerCase())
        .toSet();
    if (url.tags.any((t) => recentTags.contains(t.toLowerCase()))) {
      return 'Matches your recent saves';
    }
    if (url.effectiveCategories.any(
      (c) => recentCats.contains(c.toLowerCase()),
    )) {
      return 'Based on recent activity';
    }
  }

  final age = now.difference(url.savedAt);
  if (age.inDays > 90) return 'From months ago';
  if (age.inDays > 30) return 'From last month';
  return 'Worth revisiting';
}

String _formatTimeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}
