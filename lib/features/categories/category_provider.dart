import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';

/// Provider for URLs filtered by a specific category.
final categoryUrlsProvider =
    FutureProvider.family<List<SavedUrl>, String>((ref, category) async {
  final isarService = ref.watch(isarServiceProvider);
  return isarService.getUrlsByCategory(category);
});
