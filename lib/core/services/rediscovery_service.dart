import '../database/isar_service.dart';
import '../models/saved_url.dart';
import 'revisit_scorer.dart';

/// Surfaces older saved links worth returning to — "you cared about this
/// before too". Ranking is delegated to [RevisitScorer], the single on-device
/// scoring core shared with the revisit-due notification, so explicit intent
/// (queued / done) and implicit signals (embeddings, overlap, age) stay in sync.
class RediscoveryService {
  RediscoveryService(this.isarService);

  final IsarService isarService;

  /// Returns older links worth resurfacing, ranked by [RevisitScorer].
  ///
  /// Queued-due items the user explicitly bookmarked float to the top; done
  /// and dismissed items are excluded; everything else is blended on embedding
  /// similarity, category/tag overlap, age and never-opened status.
  Future<List<SavedUrl>> getRediscoveryLinks({int limit = 5}) async {
    final all = await isarService.getAllUrls(); // newest first
    if (all.length < 4) return [];

    // Seeds = the 5 most recently saved URLs (current interest signal).
    final seeds = all.take(5).toList();
    final seedIds = seeds.map((u) => u.id).toSet();
    final now = DateTime.now();

    final scored = <MapEntry<SavedUrl, double>>[];
    for (final u in all) {
      if (seedIds.contains(u.id)) continue;
      final result = RevisitScorer.score(u, seeds: seeds, now: now);
      if (result.isExcluded) continue;
      scored.add(MapEntry(u, result.score));
    }

    if (scored.isEmpty) {
      // Library too small or all-new: oldest unread, non-done, non-dismissed.
      final cutoff = now.subtract(const Duration(days: 7));
      return all
          .where((u) =>
              !seedIds.contains(u.id) &&
              !u.isDone &&
              u.rediscoverDismissedAt == null &&
              u.openedAt == null &&
              u.savedAt.isBefore(cutoff))
          .take(limit)
          .toList();
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((e) => e.key).toList();
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

