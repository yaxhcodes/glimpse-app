import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kDebugMode;

import '../database/isar_service.dart';
import '../models/saved_url.dart';
import '../models/url_processing_status.dart';
import 'category_resolver.dart';
import 'category_taxonomy.dart';
import 'domain_categorizer.dart';
import 'embedding_input.dart';
import 'embedding_service.dart';
import 'gemini_service.dart';
import 'link_preview_service.dart';
import 'memory_intent_resolver.dart';
import 'tag_noise_filter.dart';
import 'text_cleaner.dart';
import 'title_resolver.dart';
import 'transcript_enrichment_service.dart';
import 'url_processing_observer.dart';
import 'usage_service.dart';

/// Background enrichment for saved URLs.
///
/// Processes AI categorization, summaries, and embeddings with
/// bounded concurrency so the UI stays responsive and the save
/// action completes instantly.
class EnrichmentService {
  // Each attempt re-runs the (paid) Apify extraction, so keep this short.
  // Permanent failures (HTTP 422 — Groq can't read the media, no video, etc.)
  // already stop after attempt 1 via the non-retryable path; this ladder only
  // applies to transient failures (HTTP 424, e.g. an Apify timeout), which are
  // rare on the paid tier. Two attempts caps the worst-case Apify spend.
  static const _mediaRetryDelays = <Duration>[
    Duration.zero,
    Duration(seconds: 15),
  ];

  final IsarService _isarService;
  final GeminiService? _geminiService;
  final EmbeddingService? _embeddingService;
  final LinkPreviewService? _linkService;
  final TranscriptEnrichmentService? _transcriptEnrichmentService;
  final UsageService _usageService;
  final bool _isPro;
  final void Function()? _onEnriched;

  EnrichmentService({
    required IsarService isarService,
    GeminiService? geminiService,
    EmbeddingService? embeddingService,
    LinkPreviewService? linkService,
    TranscriptEnrichmentService? transcriptEnrichmentService,
    required UsageService usageService,
    required bool isPro,
    void Function()? onEnriched,
  }) : _isarService = isarService,
       _geminiService = geminiService,
       _embeddingService = embeddingService,
       _linkService = linkService,
       _transcriptEnrichmentService = transcriptEnrichmentService,
       _usageService = usageService,
       _isPro = isPro,
       _onEnriched = onEnriched {
    if (kDebugMode) {
      developer.log(
        'EnrichmentService created: gemini=${_geminiService != null}, '
        'embedding=${_embeddingService != null}, '
        'linkPreview=${_linkService != null}, isPro=$_isPro',
        name: 'Enrichment',
      );
    }
  }

  /// Enrich a batch of URLs with bounded concurrency.
  ///
  /// AI (categorize + summarize) runs 2 at a time.
  /// Embeddings run 2 at a time, but only after AI completes for each URL.
  /// Individual URL failures do NOT prevent other URLs from being enriched.
  Future<void> enrichBatch(List<int> urlIds) async {
    if (urlIds.isEmpty) return;

    developer.log(
      'enrichBatch START: ${urlIds.length} URLs',
      name: 'Enrichment',
    );

    // Run each save through the same guarded state machine used by single
    // saves, so a failed AI phase cannot be followed by a raw READY save.
    final saveSemaphore = _Semaphore(2);
    final futures = <Future<void>>[];
    for (final id in urlIds) {
      futures.add(_runWithSemaphore(saveSemaphore, () => enrichSingle(id)));
    }
    await Future.wait(futures, eagerError: false);

    developer.log('enrichBatch COMPLETE', name: 'Enrichment');

    // Notify listeners that enrichment is complete
    _onEnriched?.call();
  }

  /// Enrich a single URL with all phases (AI then embedding).
  /// Each phase is individually guarded so a failure in one does not
  /// prevent the other from running or the callback from firing.
  Future<void> enrichSingle(
    int urlId, {
    bool forceAi = false,
    bool forceEmbedding = false,
    bool countAiUsage = true,
  }) async {
    try {
      await _enrichAi(urlId, force: forceAi, countUsage: countAiUsage);
      _onEnriched?.call();
    } catch (e, st) {
      developer.log(
        'enrichSingle AI phase failed for $urlId: $e',
        name: 'Enrichment',
        stackTrace: st,
      );
    }
    final afterAi = await _isarService.getUrlById(urlId);
    if (afterAi?.processingStatus == UrlProcessingStatus.failed) {
      developer.log(
        'enrichSingle STOP: AI phase left save failed for $urlId',
        name: 'Enrichment',
      );
      _onEnriched?.call();
      return;
    }
    if (afterAi != null &&
        afterAi.processingStatus != UrlProcessingStatus.generatingEmbeddings &&
        afterAi.processingStatus != UrlProcessingStatus.ready &&
        TranscriptEnrichmentService.supportsUrl(afterAi.rawUrl)) {
      developer.log(
        'enrichSingle SKIP embedding: media save not ready '
        '(status=${afterAi.processingStatus}) for $urlId',
        name: 'Enrichment',
      );
      _onEnriched?.call();
      return;
    }
    try {
      await _markProcessing(
        urlId,
        UrlProcessingStatus.generatingEmbeddings,
        error: afterAi?.processingError == 'ai_limit_reached'
            ? 'ai_limit_reached'
            : null,
        stage: 'EMBEDDING_GENERATION_STARTED',
      );
      await _enrichEmbedding(urlId, force: forceEmbedding);
      final afterEmbedding = await _isarService.getUrlById(urlId);
      final hasPresentableEnrichment =
          afterEmbedding != null && _hasPresentableEnrichment(afterEmbedding);
      final hasAiEnrichment =
          afterEmbedding != null && _hasAiEnrichment(afterEmbedding);
      final allowedNonAiFallback =
          afterEmbedding?.processingError == 'ai_limit_reached' &&
          hasPresentableEnrichment;
      if (hasAiEnrichment || allowedNonAiFallback) {
        await _markProcessing(
          urlId,
          UrlProcessingStatus.ready,
          error: allowedNonAiFallback ? 'ai_limit_reached' : null,
          stage: 'SAVE_COMPLETED',
        );
      } else {
        await _markProcessing(
          urlId,
          UrlProcessingStatus.failed,
          error: 'ai_enrichment_missing',
          stage: 'SAVE_FAILED',
        );
      }
    } catch (e, st) {
      developer.log(
        'enrichSingle embedding phase failed for $urlId: $e',
        name: 'Enrichment',
        stackTrace: st,
      );
    }
    _onEnriched?.call();
  }

  /// Enrich metadata for a single URL (fetch title/description/thumbnail).
  /// Used when the URL was saved with only a domain fallback.
  Future<void> enrichMetadata(int urlId) async {
    if (_linkService == null) {
      developer.log(
        'enrichMetadata SKIP: linkService is null for $urlId',
        name: 'Enrichment',
      );
      return;
    }
    final url = await _isarService.getUrlById(urlId);
    if (url == null) {
      developer.log(
        'enrichMetadata SKIP: URL $urlId not found in Isar',
        name: 'Enrichment',
      );
      return;
    }

    developer.log('enrichMetadata START: ${url.rawUrl}', name: 'Enrichment');

    try {
      final metadata = await _linkService.fetchMetadata(url.rawUrl);
      developer.log(
        'enrichMetadata FETCH OK: "${metadata.title}"',
        name: 'Enrichment',
      );

      final cleanDescription =
          metadata.description.trim().toLowerCase() ==
              metadata.title.trim().toLowerCase()
          ? ''
          : metadata.description;

      url.title = metadata.title;
      url.description = cleanDescription;
      if (metadata.imageUrl != null && metadata.imageUrl!.isNotEmpty) {
        url.thumbnailUrl = metadata.imageUrl;
      }

      // Enrich tags with platform-extracted data
      if (metadata.extractedTags != null) {
        for (final t in metadata.extractedTags!) {
          if (!url.tags.contains(t)) url.tags = [...url.tags, t];
        }
      }
      if (metadata.author != null && metadata.author!.isNotEmpty) {
        url.tags = [...url.tags, metadata.author!];
      }
      if (metadata.siteName != null &&
          metadata.siteName!.isNotEmpty &&
          !url.tags.contains(metadata.siteName!)) {
        url.tags = [...url.tags, metadata.siteName!];
      }
      final recipe = metadata.recipe;
      if (recipe != null) {
        final normalized = CategoryTaxonomy.normalize(
          category: 'Food & Cooking',
          tags: [...recipe.tags, 'recipe'],
        );
        final existing = _savedEnrichment(url);
        final recipeTags = TagNoiseFilter.filterTags([
          ...recipe.tags,
          'recipe',
          if ((recipe.cuisine ?? '').isNotEmpty) recipe.cuisine!,
          if ((recipe.category ?? '').isNotEmpty) recipe.category!,
        ]);
        final result = TranscriptEnrichmentResult(
          meaningfulTitle: recipe.title,
          summary: recipe.summary ?? recipe.description ?? '',
          category: normalized.name,
          tags: recipeTags,
          contentType: 'recipe',
          brief: existing?.brief,
          steps: existing?.steps ?? const [],
          mentions: existing?.mentions ?? const [],
          recipe: recipe,
          keyPoints: existing?.keyPoints ?? const [],
          thumbnailUrl: recipe.image ?? metadata.imageUrl,
          creator: recipe.author ?? metadata.author,
          memoryIntent: existing?.memoryIntent,
        );
        url
          ..category = normalized.name
          ..categoryEmoji = normalized.emoji
          ..categories = CategoryResolver.buildCategories(
            primaryCategory: normalized.name,
            platformCategory: DomainCategorizer.categorize(url.rawUrl).category,
          )
          ..tags = TagNoiseFilter.filterTags([...url.tags, ...recipeTags])
          ..summary = result.summary.isEmpty ? url.summary : result.summary
          ..enrichmentJson = jsonEncode(result.toJson());
      }

      await _isarService.updateUrl(url);
      developer.log(
        'enrichMetadata SAVE OK: ${url.rawUrl}',
        name: 'Enrichment',
      );
      _onEnriched?.call();
    } catch (e, st) {
      developer.log(
        'enrichMetadata FAILED for $urlId: $e',
        name: 'Enrichment',
        stackTrace: st,
      );
    }
  }

  /// Phase 1: AI categorization + summary.
  /// Entire method is wrapped in try/catch so failures never crash
  /// the batch or prevent Phase 2 (embedding) from running.
  Future<void> _enrichAi(
    int urlId, {
    bool force = false,
    bool countUsage = true,
  }) async {
    try {
      await _enrichAiInner(urlId, force: force, countUsage: countUsage);
    } catch (e, st) {
      developer.log(
        '_enrichAi FAILED for $urlId: $e',
        name: 'Enrichment',
        stackTrace: st,
      );
    }
  }

  Future<void> _enrichAiInner(
    int urlId, {
    bool force = false,
    bool countUsage = true,
  }) async {
    final url = await _isarService.getUrlById(urlId);
    if (url == null) {
      developer.log(
        '_enrichAi SKIP: URL $urlId not found in Isar',
        name: 'Enrichment',
      );
      return;
    }

    developer.log('_enrichAi START: ${url.rawUrl}', name: 'Enrichment');

    final platformCat = DomainCategorizer.categorize(url.rawUrl);
    final savedEnrichment = _savedEnrichment(url);
    final savedRecipe = savedEnrichment?.recipe;
    final recipeAlreadyEnhanced =
        savedRecipe != null && !_recipeNeedsEnhancement(savedRecipe);

    // Skip only when a real AI envelope exists. Metadata title/description can
    // look stable while still being a raw bookmark.
    if (!force &&
        _hasAiEnrichment(url) &&
        (savedRecipe == null || recipeAlreadyEnhanced)) {
      developer.log(
        '_enrichAi SKIP (already enriched): ${url.rawUrl}',
        name: 'Enrichment',
      );
      return;
    }

    final aiLimitReached = countUsage
        ? await _usageService.hasReachedLimit(UsageFeature.aiSave, _isPro)
        : false;

    if (aiLimitReached) {
      developer.log(
        '_enrichAi SKIP: AI save limit reached (isPro=$_isPro)',
        name: 'Enrichment',
      );
    }

    String category;
    String emoji;
    List<String> tags;
    String? summary;
    String? enrichedTitle;
    String? enrichedThumbnailUrl;
    String? enrichmentJson;
    MemoryIntentMetadata? memoryIntent;

    final mediaRequiresEvidence = TranscriptEnrichmentService.supportsUrl(
      url.rawUrl,
    );
    final transcriptResult =
        !aiLimitReached && _transcriptEnrichmentService != null
        ? await _enrichTranscriptWithRetries(url, forceRefresh: force)
        : null;

    // Genuine media-extraction failure (NOT a quota issue): stop here — the
    // retry helper has already marked this FAILED so the user can retry later.
    // When the user is simply out of free AI saves we deliberately fall
    // through to the basic, non-AI save path below: the bookmark is kept and
    // completes immediately (we allow indefinite non-AI saves), just without
    // transcript/entity enrichment. The UI surfaces an upgrade prompt.
    if (mediaRequiresEvidence && transcriptResult == null && !aiLimitReached) {
      developer.log(
        '_enrichAi STOP: media evidence unavailable for ${url.rawUrl}',
        name: 'Enrichment',
      );
      return;
    }

    if (transcriptResult != null) {
      await _markProcessing(
        urlId,
        UrlProcessingStatus.transcriptReady,
        stage: 'TRANSCRIPT_VALIDATION_PASSED',
      );
      await _markProcessing(
        urlId,
        UrlProcessingStatus.enriching,
        stage: 'GEMINI_PROCESSING_STARTED',
      );
      var enrichedTranscriptResult = transcriptResult;
      final recipeForEnhancement = transcriptResult.recipe ?? savedRecipe;
      if (recipeForEnhancement != null) {
        final enhancedRecipe = await _enhanceRecipeIfNeeded(
          recipeForEnhancement,
          url: url.rawUrl,
          aiLimitReached: aiLimitReached,
          countUsage: false,
        );
        final recipeTags = TagNoiseFilter.filterTags([
          ...transcriptResult.tags,
          ...enhancedRecipe.tags,
          'recipe',
        ]);
        final recipeSummary = enhancedRecipe.summary?.trim().isNotEmpty == true
            ? enhancedRecipe.summary!.trim()
            : enhancedRecipe.description?.trim();
        enrichedTranscriptResult = transcriptResult.copyWith(
          meaningfulTitle: transcriptResult.meaningfulTitle.trim().isNotEmpty
              ? transcriptResult.meaningfulTitle
              : enhancedRecipe.title,
          summary: transcriptResult.summary.trim().isNotEmpty
              ? transcriptResult.summary
              : recipeSummary ?? '',
          category: 'Food & Cooking',
          tags: recipeTags,
          contentType: 'recipe',
          recipe: enhancedRecipe,
          thumbnailUrl: transcriptResult.thumbnailUrl ?? enhancedRecipe.image,
          creator: transcriptResult.creator ?? enhancedRecipe.author,
        );
      }
      final normalized = CategoryTaxonomy.normalize(
        category: enrichedTranscriptResult.category,
        tags: enrichedTranscriptResult.tags,
      );
      category = normalized.name;
      emoji = normalized.emoji;
      tags = enrichedTranscriptResult.tags;
      memoryIntent = enrichedTranscriptResult.memoryIntent;
      summary = enrichedTranscriptResult.summary.isNotEmpty
          ? enrichedTranscriptResult.summary
          : _metadataFallbackSummary(url);
      enrichedTitle = enrichedTranscriptResult.meaningfulTitle.isNotEmpty
          ? enrichedTranscriptResult.meaningfulTitle
          : null;
      enrichedThumbnailUrl = enrichedTranscriptResult.thumbnailUrl;
      enrichmentJson = jsonEncode(
        enrichedTranscriptResult
            .copyWith(category: category, tags: tags)
            .toJson(),
      );
      if (countUsage) {
        await _usageService.incrementUsage(UsageFeature.aiSave);
      }
      await _markProcessing(
        urlId,
        UrlProcessingStatus.generatingRecommendations,
        stage: 'RECOMMENDATION_GENERATION_STARTED',
        fields: {
          'mention_count': enrichedTranscriptResult.mentions.length,
          'has_recipe': enrichedTranscriptResult.recipe != null,
        },
      );
      developer.log(
        '_enrichAi transcript backend RESULT: cat=$category, '
        'tags=${tags.length}, summary=${summary?.length ?? 0} chars',
        name: 'Enrichment',
      );
    } else if (savedRecipe != null && !mediaRequiresEvidence) {
      final enhancedRecipe = await _enhanceRecipeIfNeeded(
        savedRecipe,
        url: url.rawUrl,
        aiLimitReached: aiLimitReached,
        countUsage: countUsage,
      );
      final normalized = CategoryTaxonomy.normalize(
        category: 'Food & Cooking',
        tags: enhancedRecipe.tags,
      );
      category = normalized.name;
      emoji = normalized.emoji;
      tags = enhancedRecipe.tags;
      summary = enhancedRecipe.summary?.trim().isNotEmpty == true
          ? enhancedRecipe.summary
          : _metadataFallbackSummary(url);
      enrichedTitle = enhancedRecipe.title.trim().isEmpty
          ? null
          : enhancedRecipe.title;
      enrichedThumbnailUrl = enhancedRecipe.image;
      enrichmentJson = jsonEncode(
        TranscriptEnrichmentResult(
          meaningfulTitle: enrichedTitle ?? savedEnrichment!.meaningfulTitle,
          summary: summary ?? '',
          category: category,
          tags: tags,
          contentType: 'recipe',
          brief: summary,
          steps: savedEnrichment!.steps,
          mentions: savedEnrichment.mentions,
          recipe: enhancedRecipe,
          keyPoints: savedEnrichment.keyPoints,
          thumbnailUrl: enrichedThumbnailUrl ?? savedEnrichment.thumbnailUrl,
          creator: enhancedRecipe.author ?? savedEnrichment.creator,
          caption: savedEnrichment.caption,
          transcript: savedEnrichment.transcript,
          likeCount: savedEnrichment.likeCount,
          commentCount: savedEnrichment.commentCount,
          memoryIntent: savedEnrichment.memoryIntent,
        ).toJson(),
      );
    } else if (_geminiService != null &&
        !aiLimitReached &&
        !mediaRequiresEvidence) {
      try {
        developer.log(
          '_enrichAi CALLING GeminiService.categorize: ${url.rawUrl}',
          name: 'Enrichment',
        );
        final result = await _geminiService.categorize(
          title: url.title,
          description: url.description,
          url: url.rawUrl,
        );
        developer.log(
          '_enrichAi Gemini RESULT: cat=${result.category}, '
          'emoji=${result.emoji}, tags=${result.tags.length}, '
          'summary=${result.summary.length} chars',
          name: 'Enrichment',
        );
        category = result.category;
        emoji = result.emoji;
        tags = result.tags;
        memoryIntent = result.memoryIntent;
        summary = result.summary.trim();
        if (!_isValidAiSummary(summary) || tags.isEmpty) {
          await _markProcessing(
            urlId,
            UrlProcessingStatus.failed,
            error: 'gemini_returned_low_quality_result',
            stage: 'SAVE_FAILED',
          );
          return;
        }
        if (countUsage) {
          await _usageService.incrementUsage(UsageFeature.aiSave);
        }
      } catch (e, st) {
        developer.log(
          '_enrichAi Gemini FAILED for $urlId: $e',
          name: 'Enrichment',
          stackTrace: st,
        );
        await _markProcessing(
          urlId,
          UrlProcessingStatus.failed,
          error: 'gemini_enrichment_failed',
          stage: 'SAVE_FAILED',
        );
        return;
      }
    } else {
      if (_geminiService == null && !aiLimitReached && !mediaRequiresEvidence) {
        developer.log(
          '_enrichAi FAILED: GeminiService is null for eligible save',
          name: 'Enrichment',
        );
        await _markProcessing(
          urlId,
          UrlProcessingStatus.failed,
          error: 'gemini_unavailable',
          stage: 'SAVE_FAILED',
        );
        return;
      }
      if (_geminiService == null) {
        developer.log(
          '_enrichAi SKIP: GeminiService is null',
          name: 'Enrichment',
        );
      }
      category = platformCat.category;
      emoji = platformCat.emoji;
      tags = _metadataFallbackTags(url, platformCat.tags);
      summary = _metadataFallbackSummary(url);
    }

    // Enrich tags with platform data already stored, then sanitize aggressively.
    final enrichedTags = TagNoiseFilter.filterTags(tags);
    for (final t in url.tags) {
      final clean = TagNoiseFilter.cleanTag(t);
      if (!TagNoiseFilter.isNoiseTag(clean) && !enrichedTags.contains(clean)) {
        enrichedTags.add(clean);
      }
    }

    // Reload url in case it was modified concurrently
    final freshUrl = await _isarService.getUrlById(urlId);
    if (freshUrl == null) {
      developer.log(
        '_enrichAi SKIP: URL $urlId disappeared before save',
        name: 'Enrichment',
      );
      return;
    }

    freshUrl.category = category;
    freshUrl.categoryEmoji = emoji;
    final inferredCategories = CategoryTaxonomy.inferAdditionalCategories(
      tags: enrichedTags,
      text:
          '${enrichedTitle ?? freshUrl.title} ${summary ?? ''} ${freshUrl.description}',
    );
    final curatedCategories = CategoryTaxonomy.curateSourceCategories(
      categories: [category, ...inferredCategories],
      primaryCategory: category,
      tags: enrichedTags,
      text:
          '${enrichedTitle ?? freshUrl.title} ${summary ?? ''} ${freshUrl.description}',
    );
    freshUrl.categories = CategoryResolver.buildCategories(
      primaryCategory: category,
      platformCategory: platformCat.category,
      additionalCategories: curatedCategories
          .where((item) => item != category)
          .toList(),
    );
    if (enrichedTitle != null &&
        !TitleResolver.isLowSignalTitle(
          enrichedTitle,
          domain: freshUrl.domain,
        ) &&
        freshUrl.title != enrichedTitle) {
      freshUrl.title = enrichedTitle;
    }
    if (enrichedThumbnailUrl != null && enrichedThumbnailUrl.isNotEmpty) {
      freshUrl.thumbnailUrl = enrichedThumbnailUrl;
    }
    freshUrl.tags = enrichedTags;
    freshUrl.summary = summary;
    if (enrichmentJson == null &&
        !aiLimitReached &&
        !mediaRequiresEvidence &&
        summary?.trim().isNotEmpty == true) {
      enrichmentJson = jsonEncode(
        TranscriptEnrichmentResult(
          meaningfulTitle:
              TitleResolver.isLowSignalTitle(
                freshUrl.title,
                domain: freshUrl.domain,
              )
              ? ''
              : freshUrl.title,
          summary: summary!,
          category: category,
          tags: enrichedTags,
          contentType: 'generic',
          thumbnailUrl: freshUrl.thumbnailUrl,
          memoryIntent: memoryIntent,
        ).toJson(),
      );
    }
    if (enrichmentJson != null && enrichmentJson.isNotEmpty) {
      freshUrl.enrichmentJson = enrichmentJson;
    }
    freshUrl.processingError = null;

    await _isarService.updateUrl(freshUrl);
    await _markProcessing(
      freshUrl.id,
      UrlProcessingStatus.generatingEmbeddings,
      error: aiLimitReached ? 'ai_limit_reached' : null,
      stage: 'RECOMMENDATION_COMPLETED',
      fields: {
        'tag_count': enrichedTags.length,
        'has_recipe': enrichmentJson?.contains('"recipe"') == true,
      },
    );
    developer.log(
      '_enrichAi SAVE OK: ${freshUrl.rawUrl} → $category',
      name: 'Enrichment',
    );
  }

  Future<TranscriptEnrichmentResult?> _enrichTranscriptWithRetries(
    SavedUrl url, {
    required bool forceRefresh,
  }) async {
    final processingId = url.processingId ?? 'url-${url.id}';
    TranscriptEnrichmentException? lastError;

    for (var index = 0; index < _mediaRetryDelays.length; index += 1) {
      final attempt = index + 1;
      final delay = _mediaRetryDelays[index];
      if (delay > Duration.zero) {
        await _markProcessing(
          url.id,
          UrlProcessingStatus.retrying,
          attempt: attempt,
          error: lastError?.message,
          stage: 'RETRY_SCHEDULED',
          fields: {'delay_ms': delay.inMilliseconds},
        );
        await Future.delayed(delay);
        await _markProcessing(
          url.id,
          UrlProcessingStatus.retrying,
          attempt: attempt,
          stage: 'RETRY_STARTED',
        );
      }

      await _markProcessing(
        url.id,
        UrlProcessingStatus.extracting,
        attempt: attempt,
        error: null,
        stage: 'TRANSCRIPT_EXTRACTION_STARTED',
      );

      try {
        final result = await _transcriptEnrichmentService!.enrichUrl(
          rawUrl: url.rawUrl,
          title: url.title,
          description: url.description,
          thumbnailUrl: url.thumbnailUrl,
          domain: url.domain,
          saveId: url.id.toString(),
          processingId: processingId,
          attempt: attempt,
          forceRefresh: forceRefresh || attempt > 1,
        );
        if (result != null && result.hasReliableMediaEvidence) {
          await _markProcessing(
            url.id,
            UrlProcessingStatus.transcriptReady,
            attempt: attempt,
            error: null,
            stage: 'TRANSCRIPT_EXTRACTED',
            fields: {
              'transcript_length': result.transcript?.length ?? 0,
              'ocr_length': result.ocrText?.length ?? 0,
              'image_count': result.imageUrls.length,
              'mention_count': result.mentions.length,
            },
          );
          return result;
        }
        lastError = const TranscriptEnrichmentException(
          'low_quality_transcript_result',
        );
      } on TranscriptEnrichmentException catch (e) {
        lastError = e;
        if (!e.retryable) break;
      }
    }

    await _markProcessing(
      url.id,
      UrlProcessingStatus.failed,
      attempt: _mediaRetryDelays.length,
      error: lastError?.message ?? 'transcript_extraction_failed',
      stage: 'TRANSCRIPT_VALIDATION_FAILED',
    );
    return null;
  }

  Future<void> _markProcessing(
    int urlId,
    String status, {
    int? attempt,
    String? error,
    required String stage,
    Map<String, Object?> fields = const {},
  }) async {
    final url = await _isarService.getUrlById(urlId);
    if (url == null) return;
    url
      ..processingStatus = status
      ..processingAttempt = attempt ?? url.processingAttempt
      ..processingError = error
      ..processingUpdatedAt = DateTime.now();
    await _isarService.updateUrl(url);
    UrlProcessingObserver.logStage(
      stage,
      processingId: url.processingId ?? 'url-$urlId',
      saveId: url.id.toString(),
      url: url.rawUrl,
      platform: url.category,
      attempt: url.processingAttempt,
      error: error,
      fields: {'status': status, ...fields},
    );
    _onEnriched?.call();
  }

  List<String> _metadataFallbackTags(SavedUrl url, List<String> baseTags) {
    final tags = TagNoiseFilter.filterTags(baseTags);
    final text = '${url.title} ${url.description}'.toLowerCase();
    for (final phrase in _candidatePhrases(text)) {
      if (tags.length >= 5) break;
      if (phrase.length < 3 || phrase.length > 28) continue;
      if (TagNoiseFilter.isNoiseTag(phrase)) continue;
      if (!tags.contains(phrase)) tags.add(phrase);
    }
    return tags;
  }

  TranscriptEnrichmentResult? _savedEnrichment(SavedUrl url) {
    final raw = url.enrichmentJson;
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return TranscriptEnrichmentResult.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  bool _recipeStepsNeedWork(EnrichedRecipe recipe) {
    return recipe.steps.length <= 1 ||
        (recipe.steps.length <= 3 &&
            recipe.steps.any((step) => step.length > 300));
  }

  bool _recipeNeedsEnhancement(EnrichedRecipe recipe) {
    final hasSummary = recipe.summary?.trim().isNotEmpty ?? false;
    final hasDifficulty = recipe.difficulty?.trim().isNotEmpty ?? false;
    final needsNutrition =
        recipe.nutrition == null && !recipe.nutritionAttempted;
    return !hasSummary ||
        !hasDifficulty ||
        _recipeStepsNeedWork(recipe) ||
        needsNutrition;
  }

  Future<EnrichedRecipe> _enhanceRecipeIfNeeded(
    EnrichedRecipe recipe, {
    required String url,
    required bool aiLimitReached,
    required bool countUsage,
  }) async {
    if (!_recipeNeedsEnhancement(recipe) ||
        _geminiService == null ||
        aiLimitReached) {
      final estimatedNutrition =
          recipe.nutrition ?? RecipeNutrition.estimateFromRecipe(recipe);
      return recipe.copyWith(
        nutrition: estimatedNutrition,
        nutritionAttempted:
            recipe.nutritionAttempted ||
            estimatedNutrition?.hasAnyValue == true,
      );
    }

    try {
      final enhancement = await _geminiService.enhanceRecipe(
        recipe: recipe,
        url: url,
      );
      if (countUsage) {
        await _usageService.incrementUsage(UsageFeature.aiSave);
      }

      final enhancedSteps = enhancement.steps.isNotEmpty
          ? enhancement.steps
          : recipe.steps;
      final enhancedNutrition =
          enhancement.nutrition ??
          recipe.nutrition ??
          RecipeNutrition.estimateFromRecipe(recipe);
      developer.log(
        '_enrichAi recipe enhancement result: '
        'nutrition=${enhancedNutrition?.hasAnyValue == true}, '
        'steps=${enhancedSteps.length}',
        name: 'Enrichment',
      );
      return recipe.copyWith(
        summary: enhancement.summary.trim().isNotEmpty
            ? enhancement.summary
            : recipe.summary ?? recipe.description,
        difficulty: enhancement.difficulty.trim().isNotEmpty
            ? enhancement.difficulty
            : recipe.difficulty ?? _recipeDifficulty(recipe),
        tags: TagNoiseFilter.filterTags([
          ...recipe.tags,
          ...enhancement.tags,
          'recipe',
        ]),
        steps: enhancedSteps,
        nutrition: enhancedNutrition,
        nutritionAttempted: enhancedNutrition?.hasAnyValue == true,
      );
    } catch (e, st) {
      developer.log(
        '_enrichAi recipe enhancement failed: $e',
        name: 'Enrichment',
        stackTrace: st,
      );
      final estimatedNutrition =
          recipe.nutrition ?? RecipeNutrition.estimateFromRecipe(recipe);
      return recipe.copyWith(
        nutrition: estimatedNutrition,
        nutritionAttempted: estimatedNutrition?.hasAnyValue == true,
      );
    }
  }

  String _recipeDifficulty(EnrichedRecipe recipe) {
    if (recipe.steps.length <= 5 && recipe.ingredients.length <= 10) {
      return 'Easy';
    }
    if (recipe.steps.length >= 12 || recipe.ingredients.length >= 20) {
      return 'Hard';
    }
    return 'Medium';
  }

  bool _hasPresentableEnrichment(SavedUrl url) {
    if ((url.enrichmentJson ?? '').trim().isNotEmpty) return true;
    final summary = url.summary?.trim() ?? '';
    if (summary.length >= 24) return true;
    return false;
  }

  bool _hasAiEnrichment(SavedUrl url) {
    final result = _savedEnrichment(url);
    if (result == null) return false;
    if (result.recipe?.hasUsefulContent == true) return true;
    if (result.mentions.isNotEmpty || result.steps.isNotEmpty) return true;
    if (result.keyPoints.isNotEmpty) return true;
    return _isValidAiSummary(result.summary) && result.tags.isNotEmpty;
  }

  bool _isValidAiSummary(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 40) return false;
    if (RegExp(
      r'^saved item titled|^saved\s+\w+\s+from|add notes or refresh metadata',
      caseSensitive: false,
    ).hasMatch(text)) {
      return false;
    }
    return text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length >=
        8;
  }

  Iterable<String> _candidatePhrases(String text) sync* {
    const stop = {
      'the',
      'and',
      'for',
      'with',
      'from',
      'into',
      'this',
      'that',
      'his',
      'her',
      'their',
      'your',
      'you',
      'are',
      'was',
      'were',
      'video',
      'youtube',
      'http',
      'https',
      'www',
      'com',
    };
    final words = text
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length >= 3 && !stop.contains(w))
        .toList();
    for (var i = 0; i < words.length; i++) {
      yield words[i];
      if (i < words.length - 1) yield '${words[i]} ${words[i + 1]}';
    }
  }

  String? _metadataFallbackSummary(SavedUrl url) {
    final description = _cleanDisplayText(url.description);
    if (description.isNotEmpty) {
      return _firstSentences(description, maxSentences: 2, maxChars: 360);
    }
    final title = url.title.trim();
    if (title.isNotEmpty && title.toLowerCase() != url.domain.toLowerCase()) {
      return 'Saved item titled "$title". Add notes or refresh metadata for a richer summary.';
    }
    return null;
  }

  String _cleanDisplayText(String text) {
    return TextCleaner.cleanLoose(text);
  }

  String _firstSentences(
    String text, {
    required int maxSentences,
    required int maxChars,
  }) {
    final normalized = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final matches = RegExp(r'[^.!?]+[.!?]').allMatches(normalized).toList();
    final candidate = matches.isEmpty
        ? normalized
        : matches.take(maxSentences).map((m) => m.group(0)!.trim()).join(' ');
    if (candidate.length <= maxChars) return candidate;
    final cut = candidate.substring(0, maxChars);
    final lastSpace = cut.lastIndexOf(' ');
    return '${cut.substring(0, lastSpace > 120 ? lastSpace : maxChars).trim()}...';
  }

  /// Phase 2: Generate embedding vector.
  /// Entire method is wrapped in try/catch so failures never crash the batch.
  Future<void> _enrichEmbedding(int urlId, {bool force = false}) async {
    try {
      await _enrichEmbeddingInner(urlId, force: force);
    } catch (e, st) {
      developer.log(
        '_enrichEmbedding FAILED for $urlId: $e',
        name: 'Enrichment',
        stackTrace: st,
      );
    }
  }

  Future<void> _enrichEmbeddingInner(int urlId, {bool force = false}) async {
    if (_embeddingService == null) {
      developer.log(
        '_enrichEmbedding SKIP: EmbeddingService is null for $urlId',
        name: 'Enrichment',
      );
      return;
    }

    final url = await _isarService.getUrlById(urlId);
    if (url == null) {
      developer.log(
        '_enrichEmbedding SKIP: URL $urlId not found in Isar',
        name: 'Enrichment',
      );
      return;
    }

    // Skip if already embedded
    if (!force && url.embedding != null && url.embedding!.isNotEmpty) {
      developer.log(
        '_enrichEmbedding SKIP (already embedded): ${url.rawUrl}',
        name: 'Enrichment',
      );
      return;
    }

    developer.log('_enrichEmbedding START: ${url.rawUrl}', name: 'Enrichment');

    try {
      final textToEmbed = buildBookmarkEmbeddingInput(
        title: url.title,
        description: url.description,
        tags: url.tags,
        category: url.category,
        summary: url.summary,
        memoryIntentText: MemoryIntentResolver.searchableText(url),
      );
      developer.log(
        '_enrichEmbedding CALLING EmbeddingService for ${url.rawUrl}',
        name: 'Enrichment',
      );
      final vec = await _embeddingService.generateEmbedding(textToEmbed);
      if (vec.isEmpty) {
        developer.log(
          '_enrichEmbedding EMPTY vector returned for ${url.rawUrl}',
          name: 'Enrichment',
        );
        return;
      }

      // Reload in case AI enrichment modified it concurrently
      final freshUrl = await _isarService.getUrlById(urlId);
      if (freshUrl == null) {
        developer.log(
          '_enrichEmbedding SKIP: URL $urlId disappeared before save',
          name: 'Enrichment',
        );
        return;
      }

      freshUrl.embedding = vec;
      await _isarService.updateUrl(freshUrl);
      developer.log(
        '_enrichEmbedding SAVE OK: ${freshUrl.rawUrl} (${vec.length} dims)',
        name: 'Enrichment',
      );
    } on EmbeddingException catch (e, st) {
      developer.log(
        '_enrichEmbedding EmbeddingException for $urlId: $e',
        name: 'Enrichment',
        stackTrace: st,
      );
    }
  }

  Future<T> _runWithSemaphore<T>(
    _Semaphore sem,
    Future<T> Function() task,
  ) async {
    await sem.acquire();
    try {
      return await task();
    } finally {
      sem.release();
    }
  }
}

/// Simple counting semaphore for concurrency control.
class _Semaphore {
  final int _maxPermits;
  int _current = 0;
  final _waiting = <Completer<void>>[];

  _Semaphore(this._maxPermits);

  Future<void> acquire() async {
    if (_current < _maxPermits) {
      _current++;
      return;
    }
    final completer = Completer<void>();
    _waiting.add(completer);
    await completer.future;
    _current++;
  }

  void release() {
    _current--;
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
    }
  }
}
