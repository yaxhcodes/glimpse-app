import '../database/isar_service.dart';
import '../models/saved_url.dart';

/// Surfaces older saved links that are topically related to what the user
/// has been saving recently — "you cared about this before too".
class RediscoveryService {
  RediscoveryService(this.isarService);

  final IsarService isarService;

  /// Returns older links that are semantically or topically similar to the
  /// user's most recent saves.
  ///
  /// Strategy (in order of preference):
  ///   1. Embedding cosine similarity — most accurate.
  ///   2. Category + tag overlap — works without Voyage key.
  ///   3. Plain oldest-unread fallback — when library is too small or all new.
  Future<List<SavedUrl>> getRediscoveryLinks({int limit = 5}) async {
    final all = await isarService.getAllUrls(); // newest first
    if (all.length < 4) return [];

    // Seeds = the 5 most recently saved URLs (current interest signal).
    final seeds = all.take(5).toList();
    final seedIds = seeds.map((u) => u.id).toSet();

    // Candidates = everything outside the seed window, not resurfaced recently
    // and not dismissed from rediscovery by the user.
    final resurfaceCutoff = DateTime.now().subtract(const Duration(days: 14));
    final candidates = all.where((u) {
      if (seedIds.contains(u.id)) return false;
      if (u.rediscoverDismissedAt != null) return false;
      final r = u.resurfacedAt;
      return r == null || r.isBefore(resurfaceCutoff);
    }).toList();

    if (candidates.isEmpty) return [];

    // ── 1. Embedding-based similarity ────────────────────────────────────────
    final seedsWithEmb = seeds
        .where((u) => u.embedding != null && u.embedding!.isNotEmpty)
        .toList();
    final candidatesWithEmb = candidates
        .where((u) => u.embedding != null && u.embedding!.isNotEmpty)
        .toList();

    if (seedsWithEmb.isNotEmpty && candidatesWithEmb.isNotEmpty) {
      final scored = <MapEntry<SavedUrl, double>>[];
      for (final c in candidatesWithEmb) {
        double maxSim = 0;
        for (final s in seedsWithEmb) {
          final sim = IsarService.cosineSimilarity(s.embedding!, c.embedding!);
          if (sim > maxSim) maxSim = sim;
        }
        if (maxSim >= 0.45) scored.add(MapEntry(c, maxSim));
      }

      if (scored.isNotEmpty) {
        scored.sort((a, b) => b.value.compareTo(a.value));
        return scored.take(limit).map((e) => e.key).toList();
      }
    }

    // ── 2. Category + tag overlap ────────────────────────────────────────────
    final seedCategories =
        seeds.expand((u) => u.effectiveCategories).toSet();
    final seedTags =
        seeds.expand((u) => u.tags).map((t) => t.toLowerCase()).toSet();

    if (seedCategories.isNotEmpty || seedTags.isNotEmpty) {
      final scored = <MapEntry<SavedUrl, double>>[];
      for (final c in candidates) {
        double score = 0;
        for (final cat in c.effectiveCategories) {
          if (seedCategories.contains(cat)) score += 2.0;
        }
        for (final tag in c.tags) {
          if (seedTags.contains(tag.toLowerCase())) score += 1.0;
        }
        if (score > 0) scored.add(MapEntry(c, score));
      }

      if (scored.isNotEmpty) {
        scored.sort((a, b) => b.value.compareTo(a.value));
        return scored.take(limit).map((e) => e.key).toList();
      }
    }

    // ── 3. Fallback: oldest unread candidates ────────────────────────────────
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final oldUnread = candidates
        .where((u) => u.savedAt.isBefore(cutoff) && u.openedAt == null)
        .take(limit)
        .toList();
    if (oldUnread.isNotEmpty) return oldUnread;

    return candidates.take(limit).toList();
  }

  Future<void> markOpened(int urlId) async {
    await isarService.updateOpenedAt(urlId, DateTime.now());
  }

  Future<void> markResurfaced(int urlId) async {
    await isarService.updateResurfacedAt(urlId, DateTime.now());
  }

  /// Hide a link from Rediscovery ("not now").
  Future<void> markDismissed(int urlId) async {
    await isarService.updateRediscoverDismissedAt(urlId, DateTime.now());
  }

  /// Undo a dismissal.
  Future<void> restoreDismissed(int urlId) async {
    await isarService.updateRediscoverDismissedAt(urlId, null);
  }
}

