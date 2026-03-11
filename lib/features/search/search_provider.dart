import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/embedding_service.dart';
import '../../core/services/bundled_keys.dart';
import '../../core/services/subscription_service.dart';

/// Whether the last search used semantic (vector) mode or keyword (fuzzy) mode.
enum SearchMode { semantic, keyword }

final searchQueryProvider = StateProvider<String>((ref) => '');

/// Holds the mode used in the most recent search execution.
final searchModeProvider = StateProvider<SearchMode>((ref) => SearchMode.keyword);

final searchResultsProvider = FutureProvider<List<SavedUrl>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];

  final isarService = ref.watch(isarServiceProvider);

  // Semantic search only for premium users with Voyage key bundled
  try {
    final tier = await SubscriptionService().getTier();
    if (BundledKeys.hasVoyage &&
        SubscriptionService.isAvailable(PremiumFeature.semanticSearch, tier)) {
      final embeddingService = EmbeddingService(BundledKeys.voyageKey);
      final queryEmbedding = await embeddingService.generateEmbedding(query);
      if (queryEmbedding.isNotEmpty) {
        final results =
            await isarService.semanticSearchUrls(queryEmbedding, limit: 20);
        if (results.isNotEmpty) {
          return results;
        }
      }
    }
  } catch (_) {
    // Semantic search failed — fall through to keyword search
  }

  // Keyword/fuzzy fallback (free for everyone)
  return isarService.fuzzySearchUrls(query);
});
