import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/embedding_service.dart';
import '../../core/services/bundled_keys.dart';
import '../../core/services/subscription_service.dart';

/// Whether the last search used semantic (vector) mode or keyword (fuzzy) mode.
enum SearchMode { semantic, keyword }

/// Result of running a search: URLs plus which strategy produced them.
class SearchOutcome {
  final List<SavedUrl> urls;
  final SearchMode mode;

  const SearchOutcome({
    required this.urls,
    required this.mode,
  });

  static const empty = SearchOutcome(urls: [], mode: SearchMode.keyword);
}

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchOutcomeProvider = FutureProvider<SearchOutcome>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return SearchOutcome.empty;

  final isarService = ref.watch(isarServiceProvider);

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
          return SearchOutcome(urls: results, mode: SearchMode.semantic);
        }
      }
    }
  } catch (_) {
    // Semantic search failed — fall through to keyword search
  }

  final fuzzy = await isarService.fuzzySearchUrls(query);
  return SearchOutcome(urls: fuzzy, mode: SearchMode.keyword);
});
