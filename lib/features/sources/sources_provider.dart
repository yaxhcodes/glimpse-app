import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/source_membership.dart';
import '../home/home_provider.dart';

/// "Done" (archived) saves — the saves a user marked finished from Details.
/// Hidden from every other library surface; this backs the Archive view.
final archivedUrlsProvider = FutureProvider<List<SavedUrl>>((ref) async {
  // Refresh whenever the library changes (a save archived/restored).
  ref.watch(
    urlStreamProvider.select(
      (async) => async.whenOrNull(data: (urls) => urls.length),
    ),
  );
  final isar = ref.read(isarServiceProvider);
  return isar.getArchivedUrls();
});

/// Enriched source data for the dedicated sources page.
class SourceCluster {
  final String name;
  final int count;
  final List<String> mostlyAbout;
  final int themeCount;
  final List<String> memoryStripUrls;
  final int savesThisWeek;
  final DateTime? lastSavedAt;
  final DateTime? mostResurfacedAt;
  final String? topDomain;
  final String? faviconUrl;

  const SourceCluster({
    required this.name,
    required this.count,
    required this.mostlyAbout,
    required this.themeCount,
    required this.memoryStripUrls,
    required this.savesThisWeek,
    this.lastSavedAt,
    this.mostResurfacedAt,
    this.topDomain,
    this.faviconUrl,
  });

  bool get isActiveThisWeek => savesThisWeek > 0;
  bool get isGrowing => savesThisWeek >= 3;
  bool get isEmpty => count == 0;
}

const topSourceCount = 5;

/// Returns the most-saved sources in a stable order for shared library surfaces.
List<SourceCluster> topSourceClusters(
  Iterable<SourceCluster> clusters, {
  int limit = topSourceCount,
}) {
  if (limit <= 0) return const [];

  final ranked = clusters.where((cluster) => !cluster.isEmpty).toList()
    ..sort((a, b) {
      final countComparison = b.count.compareTo(a.count);
      if (countComparison != 0) return countComparison;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return ranked.take(limit).toList(growable: false);
}

/// Fetches all URLs and builds enriched knowledge-cluster metadata.
final sourceClustersProvider = FutureProvider<List<SourceCluster>>((ref) async {
  final isar = ref.read(isarServiceProvider);
  // Exclude "done" (archived) saves from the Sources library view.
  final all = (await isar.getAllUrls()).where((u) => !u.isDone).toList();

  final weekAgo = DateTime.now().subtract(const Duration(days: 7));

  final Map<String, List<SavedUrl>> urlsBySource = {};
  for (final url in all) {
    final source = SourceMembership.originFor(url);
    if (source.trim().isEmpty) continue;
    (urlsBySource[source] ??= []).add(url);
  }

  return urlsBySource.entries.map((e) {
    final name = e.key;
    final urls = e.value;

    // Semantic signals: top tags by frequency within this source
    final tagCounts = <String, int>{};
    final domainCounts = <String, int>{};
    for (final url in urls) {
      for (final tag in url.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
      domainCounts[url.domain] = (domainCounts[url.domain] ?? 0) + 1;
    }
    final sortedTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final mostlyAbout = sortedTags.take(7).map((t) => t.key).toList();

    // Top domain in this source
    final sortedDomains = domainCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topDomain = sortedDomains.isNotEmpty ? sortedDomains.first.key : null;
    final faviconUrl = topDomain == null || topDomain.trim().isEmpty
        ? null
        : 'https://www.google.com/s2/favicons?domain=${Uri.encodeComponent(topDomain)}&sz=128';

    // Recent saves
    final savesThisWeek = urls.where((u) => u.savedAt.isAfter(weekAgo)).length;

    // Last saved
    final lastSaved = urls.isEmpty
        ? null
        : urls.map((u) => u.savedAt).reduce((a, b) => a.isAfter(b) ? a : b);

    // Most resurfaced
    final resurfaced = urls.where((u) => u.resurfacedAt != null).toList();
    DateTime? mostResurfaced;
    if (resurfaced.isNotEmpty) {
      mostResurfaced = resurfaced
          .map((u) => u.resurfacedAt!)
          .reduce((a, b) => a.isAfter(b) ? a : b);
    }

    // Memory strip: up to 5 recent thumbnails
    final strip = urls
        .where((u) => u.thumbnailUrl != null && u.thumbnailUrl!.isNotEmpty)
        .take(5)
        .map((u) => u.thumbnailUrl!)
        .toList();

    return SourceCluster(
      name: name,
      count: urls.length,
      mostlyAbout: mostlyAbout,
      themeCount: sortedTags.length,
      memoryStripUrls: strip,
      savesThisWeek: savesThisWeek,
      lastSavedAt: lastSaved,
      mostResurfacedAt: mostResurfaced,
      topDomain: topDomain,
      faviconUrl: faviconUrl,
    );
  }).toList();
});

final sourceUrlsProvider = FutureProvider.family<List<SavedUrl>, String>((
  ref,
  source,
) async {
  ref.watch(
    urlStreamProvider.select(
      (async) => async.whenOrNull(data: (urls) => urls.length),
    ),
  );

  final isar = ref.read(isarServiceProvider);
  final all = await isar.getAllUrls();
  return all
      .where(
        (url) => !url.isDone && SourceMembership.containsOrigin(url, source),
      )
      .toList()
    ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
});

/// Filtered clusters based on search query.
final filteredClustersProvider =
    Provider.family<AsyncValue<List<SourceCluster>>, String>((ref, query) {
      final async = ref.watch(sourceClustersProvider);
      final q = query.trim().toLowerCase();
      if (q.isEmpty) return async;
      return async.when(
        data: (list) => AsyncValue.data(
          list.where((s) => s.name.toLowerCase().contains(q)).toList(),
        ),
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    });
