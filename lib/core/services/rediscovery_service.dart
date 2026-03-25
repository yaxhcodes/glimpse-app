import '../database/isar_service.dart';
import '../models/saved_url.dart';

/// Surfaces old, never-opened links for the home screen.
class RediscoveryService {
  RediscoveryService(this.isarService);

  final IsarService isarService;

  /// Saved 7+ days ago, never opened, not resurfaced in the last 14 days.
  Future<List<SavedUrl>> getRediscoveryLinks({int limit = 3}) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final resurfaceCutoff = DateTime.now().subtract(const Duration(days: 14));

    return isarService.getUnreadLinks(
      savedBefore: cutoff,
      notResurfacedSince: resurfaceCutoff,
      limit: limit,
    );
  }

  Future<void> markOpened(int urlId) async {
    await isarService.updateOpenedAt(urlId, DateTime.now());
  }

  Future<void> markResurfaced(int urlId) async {
    await isarService.updateResurfacedAt(urlId, DateTime.now());
  }
}
