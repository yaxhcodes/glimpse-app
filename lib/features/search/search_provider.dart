import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/embedding_service.dart';

/// Whether the last search used semantic (vector) mode or keyword (fuzzy) mode.
enum SearchMode { semantic, keyword }

final searchQueryProvider = StateProvider<String>((ref) => '');

/// Holds the mode used in the most recent search execution.
final searchModeProvider = StateProvider<SearchMode>((ref) => SearchMode.keyword);

final searchResultsProvider = FutureProvider<List<SavedUrl>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];

  final isarService = ref.watch(isarServiceProvider);
  final apiKeyService = ref.watch(apiKeyServiceProvider);

  // Try semantic search first if Voyage key is configured
  final voyageKey = await apiKeyService.getVoyageKey();
  if (voyageKey != null && voyageKey.isNotEmpty) {
    try {
      final embeddingService = EmbeddingService(voyageKey);
      final queryEmbedding = await embeddingService.generateEmbedding(query);
      if (queryEmbedding.isNotEmpty) {
        final results =
            await isarService.semanticSearchUrls(queryEmbedding, limit: 20);
        if (results.isNotEmpty) {
          return results;
        }
      }
    } catch (_) {
      // Fall through to keyword search
    }
  }

  // Keyword/fuzzy fallback
  return isarService.fuzzySearchUrls(query);
});
