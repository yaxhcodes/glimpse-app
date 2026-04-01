import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/models/saved_url.dart';
import '../../core/database/isar_service.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/bundled_keys.dart';
import '../../core/services/embedding_service.dart';
import '../../core/services/subscription_service.dart';

part 'search_provider.g.dart';

/// Whether the last search used semantic (vector) mode or keyword (fuzzy) mode.
enum SearchMode { semantic, keyword }

final searchModeProvider = StateProvider<SearchMode>(
  (ref) => SearchMode.keyword,
);

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
      final tier = await SubscriptionService().getTier();
      final canSemantic = BundledKeys.hasVoyage &&
          SubscriptionService.isAvailable(PremiumFeature.semanticSearch, tier);

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
          final embeddingService = EmbeddingService(BundledKeys.voyageKey);
          final queryEmbedding = await embeddingService.generateEmbedding(query);
          if (id != _requestId) return;
          if (queryEmbedding.isNotEmpty) {
            final allUrls = await isar.getUrlsWithEmbeddings();
            if (id != _requestId) return;
            final scored = <SearchResult>[];
            for (final url in allUrls) {
              final emb = url.embedding;
              if (emb == null || emb.isEmpty) continue;
              final score = IsarService.cosineSimilarity(queryEmbedding, emb);
              scored.add(SearchResult(url: url, score: score));
            }
            scored.sort((a, b) => b.score.compareTo(a.score));
            // Slightly stricter than before to reduce loosely related vector hits.
            final results = scored
                .where((r) => r.score > 0.52)
                .take(15)
                .toList();
            if (results.isNotEmpty) {
              if (id != _requestId) return;
              ref.read(searchModeProvider.notifier).state = SearchMode.semantic;
              state = AsyncValue.data(results);
              return;
            }
          }
        } catch (_) {
          final scored = await isar.keywordSearchWithScores(query);
          applyKeywordResults(scored);
          return;
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
