import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';

/// Provider for keyword-based search results with fuzzy matching.
final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider =
    FutureProvider<List<SavedUrl>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];

  final isarService = ref.watch(isarServiceProvider);
  return isarService.fuzzySearchUrls(query);
});
