import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/category_order_provider.dart';

/// Provider for the home screen — all URLs grouped by category.
final allUrlsProvider = FutureProvider<List<SavedUrl>>((ref) async {
  final isarService = ref.watch(isarServiceProvider);
  return isarService.getAllUrls();
});

/// Provider for the list of categories (with emoji and count).
final categoriesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final isarService = ref.watch(isarServiceProvider);
  return isarService.getCategories();
});

/// Categories sorted by user-defined order.
final orderedCategoriesProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
  final order = ref.watch(categoryOrderProvider);
  if (order.isEmpty) return categories;
  final byName = <String, Map<String, dynamic>>{
    for (final c in categories) c['category'] as String: c,
  };
  return [
    for (final name in order)
      if (byName.containsKey(name)) byName[name]!,
    for (final c in categories)
      if (!order.contains(c['category'] as String)) c,
  ];
});

/// Provider to stream all URLs for real-time updates.
final urlStreamProvider = StreamProvider<List<SavedUrl>>((ref) {
  final isarService = ref.watch(isarServiceProvider);
  return isarService.watchAllUrls();
});

/// Lowercase tag → occurrence count across the library (specificity / ordering).
final tagOccurrenceMapProvider = Provider<Map<String, int>>((ref) {
  final urls = ref.watch(urlStreamProvider).valueOrNull;
  if (urls == null || urls.isEmpty) return {};
  final counts = <String, int>{};
  for (final u in urls) {
    for (final t in u.tags) {
      final k = t.toLowerCase().trim();
      if (k.isEmpty) continue;
      counts[k] = (counts[k] ?? 0) + 1;
    }
  }
  return counts;
});
