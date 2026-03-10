import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/link_preview_service.dart';
import '../../core/services/domain_categorizer.dart';
import '../../core/services/gemini_service.dart';
import '../../core/services/embedding_service.dart';

/// State for the Add URL flow.
enum AddUrlStatus {
  idle,
  fetchingMetadata,
  categorizing,
  generatingEmbedding,
  saving,
  done,
  error,
}

class AddUrlState {
  final AddUrlStatus status;
  final String? errorMessage;
  final String url;
  final LinkMetadata? metadata;
  /// Non-null when a similar URL was already saved (for duplicate warning).
  final int? similarUrlCount;

  const AddUrlState({
    this.status = AddUrlStatus.idle,
    this.errorMessage,
    this.url = '',
    this.metadata,
    this.similarUrlCount,
  });

  AddUrlState copyWith({
    AddUrlStatus? status,
    String? errorMessage,
    String? url,
    LinkMetadata? metadata,
    int? similarUrlCount,
  }) {
    return AddUrlState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      url: url ?? this.url,
      metadata: metadata ?? this.metadata,
      similarUrlCount: similarUrlCount ?? this.similarUrlCount,
    );
  }
}

/// Orchestrates: fetch metadata → AI categorize/summarize → embed → save.
/// Falls back to domain-based categorization when no Gemini key is set.
class AddUrlNotifier extends StateNotifier<AddUrlState> {
  final Ref _ref;
  bool _isSaving = false;

  AddUrlNotifier(this._ref) : super(const AddUrlState());

  Future<bool> saveUrl(String rawUrl, {String? notes}) async {
    if (_isSaving) return false;
    _isSaving = true;

    final linkService = _ref.read(linkPreviewServiceProvider);
    final isarService = _ref.read(isarServiceProvider);
    final apiKeyService = _ref.read(apiKeyServiceProvider);

    final normalizedUrl = LinkPreviewService.normalizeUrl(rawUrl);

    try {
      if (!LinkPreviewService.isValidUrl(normalizedUrl)) {
        _isSaving = false;
        state = state.copyWith(
          status: AddUrlStatus.error,
          errorMessage: 'Please enter a valid URL',
        );
        return false;
      }

      // Exact duplicate check
      final existing = await isarService.findByRawUrl(normalizedUrl);
      if (existing != null) {
        _isSaving = false;
        state = state.copyWith(
          status: AddUrlStatus.error,
          errorMessage: 'This URL has already been saved',
        );
        return false;
      }

      // Step 1: Fetch OG metadata
      state = state.copyWith(
        status: AddUrlStatus.fetchingMetadata,
        url: normalizedUrl,
      );
      final metadata = await linkService.fetchMetadata(normalizedUrl);

      // Step 2: Categorize — AI if key available, otherwise domain heuristic
      state = state.copyWith(
        status: AddUrlStatus.categorizing,
        metadata: metadata,
      );

      String category;
      String emoji;
      List<String> tags;
      String? summary;

      final geminiKey = await apiKeyService.getGeminiKey();
      if (geminiKey != null && geminiKey.isNotEmpty) {
        try {
          final geminiService = GeminiService(geminiKey);
          final result = await geminiService.categorize(
            title: metadata.title,
            description: metadata.description,
            url: normalizedUrl,
          );
          category = result.category;
          emoji = result.emoji;
          tags = result.tags;
          summary = result.summary.isNotEmpty ? result.summary : null;
        } catch (_) {
          // AI failed — fall through to domain heuristic
          final fallback = DomainCategorizer.categorize(normalizedUrl);
          category = fallback.category;
          emoji = fallback.emoji;
          tags = fallback.tags;
          summary = null;
        }
      } else {
        final fallback = DomainCategorizer.categorize(normalizedUrl);
        category = fallback.category;
        emoji = fallback.emoji;
        tags = fallback.tags;
        summary = null;
      }

      // Enrich tags with author/site info
      final enrichedTags = [...tags];
      if (metadata.author != null && metadata.author!.isNotEmpty) {
        enrichedTags.add(metadata.author!);
      }
      if (metadata.siteName != null &&
          metadata.siteName!.isNotEmpty &&
          metadata.siteName!.toLowerCase() != category.toLowerCase()) {
        enrichedTags.add(metadata.siteName!);
      }

      // Step 3: Generate embedding — Voyage AI if key available
      state = state.copyWith(status: AddUrlStatus.generatingEmbedding);
      List<double> embedding = [];

      final voyageKey = await apiKeyService.getVoyageKey();
      if (voyageKey != null && voyageKey.isNotEmpty) {
        try {
          final embeddingService = EmbeddingService(voyageKey);
          final textToEmbed =
              '${metadata.title} ${summary ?? metadata.description}';
          embedding = await embeddingService.generateEmbedding(textToEmbed);
        } catch (_) {
          embedding = [];
        }
      }

      // Step 4: Duplicate similarity check (if we have embeddings)
      int similarCount = 0;
      if (embedding.isNotEmpty) {
        similarCount = await isarService.countSimilarUrls(
          embedding: embedding,
          threshold: 0.88,
        );
      }

      // Step 5: Save to DB
      state = state.copyWith(
        status: AddUrlStatus.saving,
        similarUrlCount: similarCount > 0 ? similarCount : null,
      );

      final savedUrl = SavedUrl()
        ..rawUrl = normalizedUrl
        ..domain = metadata.domain
        ..title = metadata.title
        ..description = metadata.description
        ..thumbnailUrl = metadata.imageUrl
        ..category = category
        ..categoryEmoji = emoji
        ..tags = enrichedTags
        ..summary = summary
        ..userNotes = notes
        ..savedAt = DateTime.now()
        ..embedding = embedding;

      await isarService.saveUrl(savedUrl);

      state = state.copyWith(status: AddUrlStatus.done);
      _isSaving = false;
      return true;
    } catch (e) {
      _isSaving = false;
      state = state.copyWith(
        status: AddUrlStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  void reset() {
    _isSaving = false;
    state = const AddUrlState();
  }
}

final addUrlProvider =
    StateNotifierProvider<AddUrlNotifier, AddUrlState>((ref) {
  return AddUrlNotifier(ref);
});
