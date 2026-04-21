import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/embedding_service.dart';
import '../../core/services/subscription_service.dart';

part 'search_provider.g.dart';

/// Whether the last search used semantic (vector) mode or keyword (fuzzy) mode.
enum SearchMode { semantic, keyword }

final searchModeProvider = StateProvider<SearchMode>(
  (ref) => SearchMode.keyword,
);

/// Bumped when the user re-taps Search on the main shell bottom nav so the
/// embedded [SearchScreen] can focus the field and show the keyboard again.
final searchShellRefocusProvider = StateProvider<int>((ref) => 0);

/// One search hit with optional relevance score (semantic) or 0 (keyword).
class SearchResult {
  final SavedUrl url;
  final double score;

  const SearchResult({
    required this.url,
    required this.score,
  });
}

@riverpod
class Search extends _$Search {
  int _requestId = 0;

  @override
  AsyncValue<List<SearchResult>> build() => const AsyncValue.data([]);

  Future<void> search(String query) async {
    final id = ++_requestId;
    state = const AsyncValue.loading();

    try {
      final isar = ref.read(isarServiceProvider);
      final embeddings = ref.read(embeddingServiceProvider);
      // Reactive tier from Riverpod — SubscriptionService.instance.getTier()
      // would serve a stale RC cache for up to 5 min after purchase.
      final tier = await ref.read(subscriptionTierProvider.future);
      final canSemantic = embeddings != null &&
          SubscriptionService.isAvailable(
            PremiumFeature.semanticSearch,
            tier,
          );

      void applyKeywordResults(List<MapEntry<SavedUrl, double>> scored) {
        if (id != _requestId) return;
        ref.read(searchModeProvider.notifier).state = SearchMode.keyword;
        state = AsyncValue.data(
          scored
              .map((e) => SearchResult(url: e.key, score: e.value))
              .toList(),
        );
      }

      if (canSemantic) {
        try {
          final queryEmbedding = await embeddings.generateEmbedding(query);
          if (id != _requestId) return;
          if (queryEmbedding.isNotEmpty) {
            final scored = await isar.semanticSearchScored(
              queryEmbedding,
              limit: 15,
              minScore: 0.52,
            );
            if (id != _requestId) return;
            if (scored.isNotEmpty) {
              ref.read(searchModeProvider.notifier).state =
                  SearchMode.semantic;
              state = AsyncValue.data(
                scored
                    .map((e) => SearchResult(url: e.key, score: e.value))
                    .toList(),
              );
              return;
            }
          }
        } on EmbeddingException {
          // Semantic unavailable — fall through to keyword.
        }
      }

      final scored = await isar.keywordSearchWithScores(query);
      applyKeywordResults(scored);
    } catch (e, st) {
      if (id == _requestId) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  void clear() => state = const AsyncValue.data([]);
}
