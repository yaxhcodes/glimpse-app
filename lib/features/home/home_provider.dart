import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';

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

/// Provider to stream all URLs for real-time updates.
final urlStreamProvider = StreamProvider<List<SavedUrl>>((ref) {
  final isarService = ref.watch(isarServiceProvider);
  return isarService.watchAllUrls();
});
