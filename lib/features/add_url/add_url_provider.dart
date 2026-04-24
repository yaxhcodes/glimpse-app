import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../ask/ask_empty_suggestions_provider.dart';
import '../home/home_provider.dart';
import '../../core/services/link_preview_service.dart';
import '../../core/services/domain_categorizer.dart';
import '../../core/providers/usage_providers.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/services/embedding_input.dart';
import '../../core/services/embedding_service.dart';
import '../../core/services/category_resolver.dart';
import '../../core/services/usage_service.dart';
import '../mindmap/interest_clusters_provider.dart';

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
  /// `true` when the AI categorization step was skipped because the monthly
  /// AI-save limit was reached (free tier).
  final bool usedAiFallback;

  const AddUrlState({
    this.status = AddUrlStatus.idle,
    this.errorMessage,
    this.url = '',
    this.metadata,
    this.similarUrlCount,
    this.usedAiFallback = false,
  });

  AddUrlState copyWith({
    AddUrlStatus? status,
    String? errorMessage,
    String? url,
    LinkMetadata? metadata,
    int? similarUrlCount,
    bool? usedAiFallback,
  }) {
    return AddUrlState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      url: url ?? this.url,
      metadata: metadata ?? this.metadata,
      similarUrlCount: similarUrlCount ?? this.similarUrlCount,
      usedAiFallback: usedAiFallback ?? this.usedAiFallback,
    );
  }
}

/// Orchestrates: fetch metadata → AI categorize/summarize → embed → save.
/// Falls back to domain-based categorization when Gemini is unavailable or fails.
class AddUrlNotifier extends StateNotifier<AddUrlState> {
  final Ref _ref;
  bool _isSaving = false;

  AddUrlNotifier(this._ref) : super(const AddUrlState());

  Future<bool> saveUrl(String rawUrl, {String? notes}) async {
    if (_isSaving) return false;
    _isSaving = true;

    final linkService = _ref.read(linkPreviewServiceProvider);
    final isarService = _ref.read(isarServiceProvider);
    final geminiService = _ref.read(geminiServiceProvider);
    final embeddingService = _ref.read(embeddingServiceProvider);

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
        usedAiFallback: false,
        errorMessage: null,
      );
      final metadata = await linkService.fetchMetadata(normalizedUrl);

      // Step 2: Categorize — Gemini for every URL when configured, else heuristic
      state = state.copyWith(
        status: AddUrlStatus.categorizing,
        metadata: metadata,
      );

      final platformCategorization = DomainCategorizer.categorize(normalizedUrl);

      String category;
      String emoji;
      List<String> tags;
      String? summary;

      // Check AI-save usage limit before calling Gemini.
      final isPro = _ref.read(isProUserProvider);
      final usageService = _ref.read(usageServiceProvider);
      final aiLimitReached = await usageService.hasReachedLimit(
        UsageFeature.aiSave,
        isPro,
      );

      if (geminiService != null && !aiLimitReached) {
        try {
          final result = await geminiService.categorize(
            title: metadata.title,
            description: metadata.description,
            url: normalizedUrl,
          );
          category = result.category;
          emoji = result.emoji;
          tags = result.tags;
          summary = result.summary.isNotEmpty ? result.summary : null;

          await usageService.incrementUsage(UsageFeature.aiSave);
          _ref.read(usageRevisionProvider.notifier).state++;
        } catch (e) {
          developer.log('Gemini categorize failed: $e', name: 'AddUrl');
          category = platformCategorization.category;
          emoji = platformCategorization.emoji;
          tags = platformCategorization.tags;
          summary = null;
        }
      } else {
        if (aiLimitReached) {
          developer.log('AI save limit reached — falling back to domain categorization', name: 'AddUrl');
          state = state.copyWith(usedAiFallback: true);
        }
        category = platformCategorization.category;
        emoji = platformCategorization.emoji;
        tags = platformCategorization.tags;
        summary = null;
      }

      // Enrich tags with platform-extracted tags (e.g. Instagram hashtags),
      // author, and site name — deduplicating against AI-generated tags.
      final enrichedTags = [...tags];
      if (metadata.extractedTags != null) {
        for (final t in metadata.extractedTags!) {
          if (!enrichedTags.contains(t)) enrichedTags.add(t);
        }
      }
      if (metadata.author != null && metadata.author!.isNotEmpty) {
        enrichedTags.add(metadata.author!);
      }
      if (metadata.siteName != null &&
          metadata.siteName!.isNotEmpty &&
          metadata.siteName!.toLowerCase() != category.toLowerCase()) {
        enrichedTags.add(metadata.siteName!);
      }

      // Use empty description when it mirrors the title (e.g. Instagram, some OG tags)
      final cleanDescription = metadata.description.trim().toLowerCase() ==
              metadata.title.trim().toLowerCase()
          ? ''
          : metadata.description;

      // Step 3: Generate embedding — Voyage AI if key available
      state = state.copyWith(status: AddUrlStatus.generatingEmbedding);
      List<double>? embedding;

      if (embeddingService != null) {
        try {
          final textToEmbed = buildBookmarkEmbeddingInput(
            title: metadata.title,
            description: cleanDescription,
            tags: enrichedTags,
            category: category,
            summary: summary,
          );
          final vec = await embeddingService.generateEmbedding(textToEmbed);
          embedding = vec.isEmpty ? null : vec;
        } on EmbeddingException catch (e) {
          developer.log(
            'Voyage embedding failed: $e',
            name: 'AddUrl',
          );
          embedding = null;
        }
      }

      // Step 4: Duplicate similarity check (if we have embeddings)
      int similarCount = 0;
      if (embedding != null && embedding.isNotEmpty) {
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
        ..description = cleanDescription
        ..thumbnailUrl = metadata.imageUrl
        ..category = category
        ..categoryEmoji = emoji
        ..categories = CategoryResolver.buildCategories(
          primaryCategory: category,
          platformCategory: platformCategorization.category,
        )
        ..tags = enrichedTags
        ..summary = summary
        ..userNotes = notes
        ..savedAt = DateTime.now()
        ..embedding = embedding;

      await isarService.saveUrl(savedUrl);
      _ref.invalidate(urlStreamProvider);
      _ref.invalidate(askEmptySuggestionsProvider);
      _ref.invalidate(interestClusterThemesProvider);

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
