import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/rediscovery_service.dart';
import '../home/home_provider.dart';

/// A rediscovery item enriched with emotional context / resurfacing reason.
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

/// Recently resurfaced links (shown in rediscovery within last 30 days).
final recentlyResurfacingProvider = FutureProvider<List<RediscoveryItem>>((ref) async {
  final isar = ref.read(isarServiceProvider);
  final all = await isar.getAllUrls();
  final cutoff = DateTime.now().subtract(const Duration(days: 30));
  final urls = all
      .where((u) => u.resurfacedAt != null && u.resurfacedAt!.isAfter(cutoff))
      .toList()
    ..sort((a, b) => b.resurfacedAt!.compareTo(a.resurfacedAt!));

  return urls.map((u) => RediscoveryItem(
    url: u,
    reason: 'Resurfaced',
    timeAgo: _formatTimeAgo(u.savedAt),
  )).toList();
});

/// Oldest unread links saved more than 14 days ago.
final worthRevisitingProvider = FutureProvider<List<RediscoveryItem>>((ref) async {
  final isar = ref.read(isarServiceProvider);
  final all = await isar.getAllUrls();
  final cutoff = DateTime.now().subtract(const Duration(days: 14));
  final urls = all
      .where((u) => u.openedAt == null && u.savedAt.isBefore(cutoff))
      .toList()
    ..sort((a, b) => a.savedAt.compareTo(b.savedAt));

  return urls.map((u) {
    final reason = _resurfacingReason(u, all);
    return RediscoveryItem(
      url: u,
      reason: reason,
      timeAgo: _formatTimeAgo(u.savedAt),
    );
  }).toList();
});

/// Interest-based rediscovery with a larger limit for the dedicated page.
final interestBasedRediscoveryProvider = FutureProvider<List<RediscoveryItem>>((ref) async {
  ref.watch(
    urlStreamProvider.select(
      (async) => async.whenOrNull(data: (urls) => urls.length),
    ),
  );
  final isar = ref.read(isarServiceProvider);
  final all = await isar.getAllUrls();
  final service = RediscoveryService(isar);
  final urls = await service.getRediscoveryLinks(limit: 20);

  return urls.map((u) {
    final reason = _resurfacingReason(u, all);
    return RediscoveryItem(
      url: u,
      reason: reason,
      timeAgo: _formatTimeAgo(u.savedAt),
    );
  }).toList();
});

String _resurfacingReason(SavedUrl url, List<SavedUrl> all) {
  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));

  // Check if recent saves share categories/tags
  final recent = all.where((u) => u.savedAt.isAfter(weekAgo) && u.id != url.id).toList();
  if (recent.isNotEmpty) {
    final recentTags = recent.expand((u) => u.tags).map((t) => t.toLowerCase()).toSet();
    final recentCats = recent.expand((u) => u.effectiveCategories).map((c) => c.toLowerCase()).toSet();

    final sharedTags = url.tags.where((t) => recentTags.contains(t.toLowerCase())).toList();
    final sharedCats = url.effectiveCategories.where((c) => recentCats.contains(c.toLowerCase())).toList();

    if (sharedTags.isNotEmpty) {
      return 'From recent saves';
    }
    if (sharedCats.isNotEmpty) {
      return 'Based on recent activity';
    }
  }

  // Never opened
  if (url.openedAt == null) {
    return 'Unopened';
  }

  // Time-based context
  final age = now.difference(url.savedAt);
  if (age.inDays > 90) {
    return 'From months ago';
  }
  if (age.inDays > 30) {
    return 'From last month';
  }

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
