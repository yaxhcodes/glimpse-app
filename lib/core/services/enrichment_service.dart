import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kDebugMode;

import '../database/isar_service.dart';
import '../models/saved_url.dart';
import '../models/url_processing_status.dart';
import 'category_resolver.dart';
import 'category_taxonomy.dart';
import 'domain_centroid_service.dart';
import 'domain_categorizer.dart';
import 'embedding_input.dart';
import 'embedding_service.dart';
import 'gemini_service.dart';
import 'link_preview_service.dart';
import 'memory_intent_resolver.dart';
import 'recipe_nutrition_service.dart';
import 'saved_url_enrichment_state.dart';
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
  final RecipeNutritionService? _recipeNutritionService;
  final UsageService _usageService;
  final bool _isPro;
  final String _outputLocale;
  final void Function()? _onEnriched;
  late final DomainCentroidService _domainCentroidService;

  EnrichmentService({
    required IsarService isarService,
    GeminiService? geminiService,
    EmbeddingService? embeddingService,
    LinkPreviewService? linkService,
    TranscriptEnrichmentService? transcriptEnrichmentService,
    RecipeNutritionService? recipeNutritionService,
    required UsageService usageService,
    required bool isPro,
    String outputLocale = 'en',
    void Function()? onEnriched,
  }) : _isarService = isarService,
       _geminiService = geminiService,
       _embeddingService = embeddingService,
       _linkService = linkService,
       _transcriptEnrichmentService = transcriptEnrichmentService,
       _recipeNutritionService = recipeNutritionService,
       _usageService = usageService,
       _isPro = isPro,
       _outputLocale = outputLocale,
       _onEnriched = onEnriched {
    _domainCentroidService = DomainCentroidService(_isarService);
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
    await _domainCentroidService.rebuildCentroids();

    // Run each save through the same guarded state machine used by single
    // saves, so a failed AI phase cannot be followed by a raw READY save.
    final saveSemaphore = _Semaphore(2);
    final futures = <Future<void>>[];
    for (final id in urlIds) {
      futures.add(() async {
        try {
          await _runWithSemaphore(saveSemaphore, () => enrichSingle(id));
        } catch (e, st) {
          developer.log(
            'enrichBatch item failed for $id: $e',
            name: 'Enrichment',
            stackTrace: st,
          );
        }
      }());
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
    List<String> initialFailures = const [],
  }) async {
    final failures = <String>[...initialFailures];
    await _markProcessing(
      urlId,
      UrlProcessingStatus.processing,
      error: null,
      stage: 'BACKGROUND_ENRICHMENT_STARTED',
    );

    final aiFailure = await _enrichAi(
      urlId,
      force: forceAi,
      countUsage: countAiUsage,
    );
    if (aiFailure != null) failures.add(aiFailure);
    _onEnriched?.call();

    final afterAi = await _isarService.getUrlById(urlId);
    if (afterAi == null) return;

    await _markProcessing(
      urlId,
      UrlProcessingStatus.generatingEmbeddings,
      error: null,
      stage: 'EMBEDDING_GENERATION_STARTED',
    );
    final embeddingFailure = await _enrichEmbedding(
      urlId,
      force: forceEmbedding,
    );
    if (embeddingFailure != null) failures.add(embeddingFailure);

    final afterEmbedding = await _isarService.getUrlById(urlId);
    if (afterEmbedding == null) return;
    final hasPresentableEnrichment = _hasPresentableEnrichment(afterEmbedding);
    final hasAiEnrichment = SavedUrlEnrichmentState.hasAiEnrichment(
      afterEmbedding,
    );
    final uniqueFailures = _uniqueFailures(failures);
    final status = uniqueFailures.isEmpty
        ? UrlProcessingStatus.completed
        : (hasPresentableEnrichment ||
              hasAiEnrichment ||
              afterEmbedding.title.trim().isNotEmpty)
        ? UrlProcessingStatus.partial
        : UrlProcessingStatus.failed;
    await _markProcessing(
      urlId,
      status,
      error: uniqueFailures.isEmpty ? null : uniqueFailures.join(';'),
      stage: uniqueFailures.isEmpty
          ? 'SAVE_COMPLETED'
          : status == UrlProcessingStatus.partial
          ? 'SAVE_PARTIAL'
          : 'SAVE_FAILED',
      fields: {
        'failed_task_count': uniqueFailures.length,
        if (uniqueFailures.isNotEmpty) 'failed_tasks': uniqueFailures.join(','),
      },
    );
    developer.log(
      uniqueFailures.isEmpty
          ? 'enrichSingle completed for $urlId'
          : 'enrichSingle finished with ${uniqueFailures.length} failed task(s) for $urlId: ${uniqueFailures.join(', ')}',
      name: 'Enrichment',
    );
    _onEnriched?.call();
  }

  List<String> _uniqueFailures(List<String> failures) {
    return failures
        .expand((item) => item.split(';'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  String? _appendFailure(String? existing, String failure) {
    final values = _uniqueFailures([...?existing?.split(';'), failure]);
    return values.isEmpty ? null : values.join(';');
  }

  void _logTaskFailure(
    String task,
    int urlId,
    Object error,
    StackTrace stackTrace,
  ) {
    developer.log(
      '$task failed for $urlId: $error',
      name: 'Enrichment',
      stackTrace: stackTrace,
    );
  }

  Future<void> _logTaskStage(
    int urlId,
    String stage, {
    required String task,
    Object? error,
    Map<String, Object?> fields = const {},
  }) async {
    final url = await _isarService.getUrlById(urlId);
    if (url == null) return;
    UrlProcessingObserver.logStage(
      stage,
      processingId: url.processingId ?? 'url-$urlId',
      saveId: url.id.toString(),
      url: url.rawUrl,
      platform: url.category,
      attempt: url.processingAttempt,
      error: error,
      fields: {'task': task, ...fields},
    );
  }

  Future<void> _markTaskFailed(
    int urlId, {
    required String task,
    required String error,
  }) {
    return _logTaskStage(
      urlId,
      'ENRICHMENT_TASK_FAILED',
      task: task,
      error: error,
      fields: {'error_code': error},
    );
  }

  Future<void> _markTaskCompleted(
    int urlId, {
    required String task,
    Map<String, Object?> fields = const {},
  }) {
    return _logTaskStage(
      urlId,
      'ENRICHMENT_TASK_COMPLETED',
      task: task,
      fields: fields,
    );
  }

  /// Enrich metadata for a single URL (fetch title/description/thumbnail).
  /// Used when the URL was saved with only a domain fallback.
  Future<bool> enrichMetadata(int urlId) async {
    if (_linkService == null) {
      developer.log(
        'enrichMetadata SKIP: linkService is null for $urlId',
        name: 'Enrichment',
      );
      await _markTaskFailed(
        urlId,
        task: 'metadata',
        error: 'metadata_service_unavailable',
      );
      return false;
    }
    final url = await _isarService.getUrlById(urlId);
    if (url == null) {
      developer.log(
        'enrichMetadata SKIP: URL $urlId not found in Isar',
        name: 'Enrichment',
      );
      return false;
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
          schemaVersion: 4,
          outputLocale: existing?.outputLocale ?? _outputLocale,
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
      await _markTaskCompleted(
        urlId,
        task: 'metadata',
        fields: {
          'has_title': metadata.title.trim().isNotEmpty,
          'has_thumbnail': metadata.imageUrl?.trim().isNotEmpty == true,
          'has_recipe': metadata.recipe != null,
        },
      );
      _onEnriched?.call();
      return true;
    } catch (e, st) {
      developer.log(
        'enrichMetadata FAILED for $urlId: $e',
        name: 'Enrichment',
        stackTrace: st,
      );
      await _markTaskFailed(urlId, task: 'metadata', error: 'metadata_failed');
      return false;
    }
  }

  /// Phase 1: AI categorization + summary.
  /// Entire method is wrapped in try/catch so failures never crash
  /// the batch or prevent Phase 2 (embedding) from running.
  Future<String?> _enrichAi(
    int urlId, {
    bool force = false,
    bool countUsage = true,
  }) async {
    try {
      return await _enrichAiInner(urlId, force: force, countUsage: countUsage);
    } catch (e, st) {
      _logTaskFailure('summary', urlId, e, st);
      await _markTaskFailed(
        urlId,
        task: 'summary',
        error: 'ai_enrichment_failed_unexpected',
      );
      return 'ai_enrichment_failed_unexpected';
    }
  }

  Future<String?> _enrichAiInner(
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
      return 'bookmark_missing';
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
        SavedUrlEnrichmentState.hasAiEnrichment(url) &&
        (savedRecipe == null || recipeAlreadyEnhanced)) {
      developer.log(
        '_enrichAi SKIP (already enriched): ${url.rawUrl}',
        name: 'Enrichment',
      );
      return null;
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
    List<String> keyPoints = const [];
    String? categoryEvidence;
    double? categoryConfidence;
    List<String> topics = const [];
    MemoryIntentMetadata? memoryIntent;
    String? aiFailure;
    final nestedTaskFailures = <String>[];

    final mediaRequiresEvidence = TranscriptEnrichmentService.supportsUrl(
      url.rawUrl,
    );
    final transcriptAttempt =
        !aiLimitReached && _transcriptEnrichmentService != null
        ? await _enrichTranscriptWithRetries(url, forceRefresh: force)
        : null;
    final transcriptResult = transcriptAttempt?.result;
    aiFailure = transcriptAttempt?.failureCode;

    // Media extraction failures are task-level failures. The bookmark still
    // falls through to the basic metadata/domain path below.
    if (mediaRequiresEvidence && transcriptResult == null && !aiLimitReached) {
      developer.log(
        '_enrichAi FALLBACK: media evidence unavailable for ${url.rawUrl}',
        name: 'Enrichment',
      );
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
          urlId: urlId,
          url: url.rawUrl,
          aiLimitReached: aiLimitReached,
          countUsage: false,
          onTaskFailure: nestedTaskFailures.add,
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
        await _usageService.incrementUsage(UsageFeature.aiSave, isPro: _isPro);
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
      final baseEnrichment = savedEnrichment!;
      final enhancedRecipe = await _enhanceRecipeIfNeeded(
        savedRecipe,
        urlId: urlId,
        url: url.rawUrl,
        aiLimitReached: aiLimitReached,
        countUsage: countUsage,
        onTaskFailure: nestedTaskFailures.add,
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
          schemaVersion: 4,
          outputLocale: baseEnrichment.outputLocale,
          meaningfulTitle: enrichedTitle ?? baseEnrichment.meaningfulTitle,
          summary: summary ?? '',
          category: category,
          tags: tags,
          contentType: 'recipe',
          brief: summary,
          steps: baseEnrichment.steps,
          mentions: baseEnrichment.mentions,
          recipe: enhancedRecipe,
          keyPoints: baseEnrichment.keyPoints,
          thumbnailUrl: enrichedThumbnailUrl ?? baseEnrichment.thumbnailUrl,
          creator: enhancedRecipe.author ?? baseEnrichment.creator,
          caption: baseEnrichment.caption,
          transcript: baseEnrichment.transcript,
          likeCount: baseEnrichment.likeCount,
          commentCount: baseEnrichment.commentCount,
          memoryIntent: baseEnrichment.memoryIntent,
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
        keyPoints = result.keyPoints;
        categoryEvidence = result.categoryEvidence.trim().isEmpty
            ? null
            : result.categoryEvidence.trim();
        categoryConfidence = result.categoryConfidence;
        topics = result.topics;
        memoryIntent = result.memoryIntent;
        summary = result.summary.trim();
        enrichedTitle = result.meaningfulTitle.trim().isEmpty
            ? null
            : result.meaningfulTitle.trim();
        if (!_isValidAiSummary(summary) || tags.isEmpty) {
          aiFailure = 'gemini_returned_low_quality_result';
          await _markTaskFailed(
            urlId,
            task: 'summary',
            error: 'gemini_returned_low_quality_result',
          );
          category = platformCat.category;
          emoji = platformCat.emoji;
          tags = _metadataFallbackTags(url, platformCat.tags);
          summary = _metadataFallbackSummary(url);
          enrichedTitle = null;
        }
        if (aiFailure == null && countUsage) {
          await _usageService.incrementUsage(
            UsageFeature.aiSave,
            isPro: _isPro,
          );
        }
      } catch (e, st) {
        aiFailure = 'gemini_enrichment_failed';
        _logTaskFailure('summary', urlId, e, st);
        await _markTaskFailed(
          urlId,
          task: 'summary',
          error: 'gemini_enrichment_failed',
        );
        category = platformCat.category;
        emoji = platformCat.emoji;
        tags = _metadataFallbackTags(url, platformCat.tags);
        summary = _metadataFallbackSummary(url);
      }
    } else {
      if (_geminiService == null && !aiLimitReached && !mediaRequiresEvidence) {
        developer.log(
          '_enrichAi FALLBACK: GeminiService is null for eligible save',
          name: 'Enrichment',
        );
        aiFailure = 'gemini_unavailable';
        await _markTaskFailed(
          urlId,
          task: 'summary',
          error: 'gemini_unavailable',
        );
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
      return 'bookmark_missing';
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
          schemaVersion: 4,
          outputLocale: _outputLocale,
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
          keyPoints: keyPoints,
          categoryEvidence: categoryEvidence,
          categoryConfidence: categoryConfidence,
          topics: topics,
          thumbnailUrl: freshUrl.thumbnailUrl,
          memoryIntent: memoryIntent,
        ).toJson(),
      );
    }
    if (enrichmentJson != null && enrichmentJson.isNotEmpty) {
      freshUrl.enrichmentJson = enrichmentJson;
    }
    for (final failure in nestedTaskFailures) {
      aiFailure = _appendFailure(aiFailure, failure);
    }
    await _applyCategoryCentroidValidationIfPossible(
      freshUrl,
      stage: 'AI_ENRICHMENT_CATEGORY_VALIDATED',
    );
    freshUrl.processingError = null;

    await _isarService.updateUrl(freshUrl);
    await _markTaskCompleted(
      freshUrl.id,
      task: 'summary',
      fields: {
        'tag_count': enrichedTags.length,
        'has_recipe': enrichmentJson?.contains('"recipe"') == true,
        if (aiLimitReached) 'skipped_reason': 'ai_limit_reached',
      },
    );
    developer.log(
      '_enrichAi SAVE OK: ${freshUrl.rawUrl} → $category',
      name: 'Enrichment',
    );
    return aiFailure;
  }

  Future<_TranscriptEnrichmentAttempt> _enrichTranscriptWithRetries(
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
          outputLocale: _outputLocale,
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
          await _markTaskCompleted(
            url.id,
            task: 'transcript',
            fields: {
              'transcript_length': result.transcript?.length ?? 0,
              'ocr_length': result.ocrText?.length ?? 0,
              'image_count': result.imageUrls.length,
              'mention_count': result.mentions.length,
            },
          );
          return _TranscriptEnrichmentAttempt(result: result);
        }
        lastError = const TranscriptEnrichmentException(
          'low_quality_transcript_result',
        );
      } on TranscriptEnrichmentException catch (e) {
        lastError = e;
        if (!e.retryable) break;
      }
    }

    final failureCode = lastError?.message ?? 'transcript_extraction_failed';
    await _markProcessing(
      url.id,
      UrlProcessingStatus.enriching,
      attempt: _mediaRetryDelays.length,
      error: failureCode,
      stage: 'TRANSCRIPT_VALIDATION_FAILED',
    );
    await _markTaskFailed(url.id, task: 'transcript', error: failureCode);
    return _TranscriptEnrichmentAttempt(failureCode: failureCode);
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
    required int urlId,
    required String url,
    required bool aiLimitReached,
    required bool countUsage,
    required void Function(String failure) onTaskFailure,
  }) async {
    if (!_recipeNeedsEnhancement(recipe) ||
        _geminiService == null ||
        aiLimitReached) {
      if (recipe.nutrition != null || _recipeNutritionService == null) {
        return recipe;
      }
      final calculatedNutrition = await _calculateRecipeNutrition(
        recipe,
        urlId: urlId,
        estimatedServings: null,
        onTaskFailure: onTaskFailure,
      );
      return recipe.copyWith(
        nutrition: calculatedNutrition,
        nutritionAttempted:
            recipe.nutritionAttempted ||
            calculatedNutrition?.hasAnyValue == true,
      );
    }

    try {
      final enhancement = await _geminiService.enhanceRecipe(
        recipe: recipe,
        url: url,
      );
      if (countUsage) {
        await _usageService.incrementUsage(UsageFeature.aiSave, isPro: _isPro);
      }

      final enhancedSteps = enhancement.steps.isNotEmpty
          ? enhancement.steps
          : recipe.steps;
      final enhancedIngredients = enhancement.ingredients.isNotEmpty
          ? enhancement.ingredients
          : recipe.ingredients;
      final enhancedServings = recipe.servings?.trim().isNotEmpty == true
          ? recipe.servings
          : enhancement.servings?.toString();
      final recipeWithStructuredIngredients = recipe.copyWith(
        ingredients: enhancedIngredients,
        servings: enhancedServings,
        steps: enhancedSteps,
      );
      final calculatedNutrition =
          recipe.nutrition ??
          await _calculateRecipeNutrition(
            recipeWithStructuredIngredients,
            urlId: urlId,
            estimatedServings: enhancement.servings,
            onTaskFailure: onTaskFailure,
          );
      developer.log(
        '_enrichAi recipe enhancement result: '
        'nutrition=${calculatedNutrition?.hasAnyValue == true}, '
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
        ingredients: enhancedIngredients,
        steps: enhancedSteps,
        servings: enhancedServings,
        nutrition: calculatedNutrition,
        nutritionAttempted: calculatedNutrition?.hasAnyValue == true,
      );
    } catch (e, st) {
      developer.log(
        '_enrichAi recipe enhancement failed: $e',
        name: 'Enrichment',
        stackTrace: st,
      );
      onTaskFailure('recipe_failed');
      await _markTaskFailed(urlId, task: 'recipe', error: 'recipe_failed');
      return recipe;
    }
  }

  Future<RecipeNutrition?> _calculateRecipeNutrition(
    EnrichedRecipe recipe, {
    required int urlId,
    required int? estimatedServings,
    required void Function(String failure) onTaskFailure,
  }) async {
    final service = _recipeNutritionService;
    if (service == null) return null;
    try {
      return await service.calculate(
        recipe: recipe,
        estimatedServings: estimatedServings,
      );
    } catch (e, st) {
      developer.log(
        '_enrichAi recipe nutrition failed: $e',
        name: 'Enrichment',
        stackTrace: st,
      );
      onTaskFailure('nutrition_failed');
      await _markTaskFailed(
        urlId,
        task: 'nutrition',
        error: 'nutrition_failed',
      );
      return null;
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
  Future<String?> _enrichEmbedding(int urlId, {bool force = false}) async {
    try {
      return await _enrichEmbeddingInner(urlId, force: force);
    } catch (e, st) {
      _logTaskFailure('embedding', urlId, e, st);
      await _markTaskFailed(
        urlId,
        task: 'embedding',
        error: 'embedding_failed_unexpected',
      );
      return 'embedding_failed_unexpected';
    }
  }

  Future<String?> _enrichEmbeddingInner(int urlId, {bool force = false}) async {
    if (_embeddingService == null) {
      developer.log(
        '_enrichEmbedding SKIP: EmbeddingService is null for $urlId',
        name: 'Enrichment',
      );
      return null;
    }

    final url = await _isarService.getUrlById(urlId);
    if (url == null) {
      developer.log(
        '_enrichEmbedding SKIP: URL $urlId not found in Isar',
        name: 'Enrichment',
      );
      return 'bookmark_missing';
    }

    // Skip if already embedded
    if (!force && url.embedding != null && url.embedding!.isNotEmpty) {
      developer.log(
        '_enrichEmbedding SKIP (already embedded): ${url.rawUrl}',
        name: 'Enrichment',
      );
      return null;
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
        await _markTaskFailed(
          urlId,
          task: 'embedding',
          error: 'embedding_empty_vector',
        );
        return 'embedding_empty_vector';
      }

      // Reload in case AI enrichment modified it concurrently
      final freshUrl = await _isarService.getUrlById(urlId);
      if (freshUrl == null) {
        developer.log(
          '_enrichEmbedding SKIP: URL $urlId disappeared before save',
          name: 'Enrichment',
        );
        return 'bookmark_missing';
      }

      freshUrl.embedding = vec;
      await _applyCategoryCentroidValidationIfPossible(
        freshUrl,
        stage: 'EMBEDDING_CATEGORY_VALIDATED',
      );
      await _isarService.updateUrl(freshUrl);
      await _markTaskCompleted(
        freshUrl.id,
        task: 'embedding',
        fields: {'dimensions': vec.length},
      );
      developer.log(
        '_enrichEmbedding SAVE OK: ${freshUrl.rawUrl} (${vec.length} dims)',
        name: 'Enrichment',
      );
      return null;
    } on EmbeddingException catch (e, st) {
      _logTaskFailure('embedding', urlId, e, st);
      await _markTaskFailed(
        urlId,
        task: 'embedding',
        error: 'embedding_failed',
      );
      return 'embedding_failed';
    }
  }

  Future<void> _applyCategoryCentroidValidationIfPossible(
    SavedUrl url, {
    required String stage,
  }) async {
    final embedding = url.embedding;
    if (embedding == null || embedding.isEmpty) return;
    final claimedCategory = CategoryTaxonomy.normalize(
      category: url.category,
      tags: url.tags,
    ).name;

    final validation = await _domainCentroidService.validate(
      claimedCategory: claimedCategory,
      saveEmbedding: embedding,
    );
    if (!validation.isReliable && !validation.hasCorrectionSuggestion) return;

    final fields = {
      'claimed_category': claimedCategory,
      'centroid_similarity': validation.similarity,
      'centroid_sample_size': validation.centroidSampleSize,
      'similarity_floor': DomainCentroidService.similarityFloor,
      'correction_similarity_floor':
          DomainCentroidService.correctionSimilarityFloor,
      'correction_margin': DomainCentroidService.correctionMargin,
      if (validation.suggestedCategory != null)
        'suggested_category': validation.suggestedCategory,
      if (validation.suggestedCategory != null)
        'suggested_similarity': validation.suggestedSimilarity,
      if (validation.suggestedCategory != null)
        'suggested_sample_size': validation.suggestedSampleSize,
    };
    if (validation.suggestedCategory != null) {
      final originalCategory = url.category;
      final corrected = CategoryTaxonomy.byName(validation.suggestedCategory!);
      url
        ..category = corrected.name
        ..categoryEmoji = corrected.emoji
        ..categories = CategoryResolver.buildCategories(
          primaryCategory: corrected.name,
          platformCategory: DomainCategorizer.categorize(url.rawUrl).category,
        )
        ..enrichmentJson = _markCategoryCentroidDecision(
          url.enrichmentJson,
          originalCategory: originalCategory,
          finalCategory: corrected.name,
          validation: validation,
          needsReview: false,
        );

      UrlProcessingObserver.logStage(
        'CATEGORY_CENTROID_CORRECTED',
        processingId: url.processingId ?? 'url-${url.id}',
        saveId: url.id.toString(),
        url: url.rawUrl,
        platform: originalCategory,
        attempt: url.processingAttempt,
        fields: fields,
      );
      return;
    }

    if (validation.similarity >= DomainCentroidService.similarityFloor) {
      UrlProcessingObserver.logStage(
        stage,
        processingId: url.processingId ?? 'url-${url.id}',
        saveId: url.id.toString(),
        url: url.rawUrl,
        platform: url.category,
        attempt: url.processingAttempt,
        fields: fields,
      );
      return;
    }

    final originalCategory = url.category;
    final other = CategoryTaxonomy.byName('Other');
    url
      ..category = other.name
      ..categoryEmoji = other.emoji
      ..categories = CategoryResolver.buildCategories(
        primaryCategory: other.name,
        platformCategory: DomainCategorizer.categorize(url.rawUrl).category,
      )
      ..enrichmentJson = _markCategoryCentroidDecision(
        url.enrichmentJson,
        originalCategory: originalCategory,
        finalCategory: other.name,
        validation: validation,
        needsReview: true,
      );

    UrlProcessingObserver.logStage(
      'CATEGORY_CENTROID_REJECTED',
      processingId: url.processingId ?? 'url-${url.id}',
      saveId: url.id.toString(),
      url: url.rawUrl,
      platform: originalCategory,
      attempt: url.processingAttempt,
      fields: fields,
    );
  }

  String _markCategoryCentroidDecision(
    String? rawJson, {
    required String originalCategory,
    required String finalCategory,
    required DomainCentroidResult validation,
    required bool needsReview,
  }) {
    final data = <String, dynamic>{};
    if (rawJson != null && rawJson.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map) {
          data.addAll(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        data['unparsed_enrichment'] = rawJson;
      }
    }
    data
      ..['category'] = finalCategory
      ..['category_needs_review'] = needsReview
      ..['original_gemini_category'] = originalCategory
      ..['category_validation'] = {
        'method': 'embedding_centroid',
        'similarity': validation.similarity,
        'centroid_sample_size': validation.centroidSampleSize,
        'similarity_floor': DomainCentroidService.similarityFloor,
        'correction_similarity_floor':
            DomainCentroidService.correctionSimilarityFloor,
        'correction_margin': DomainCentroidService.correctionMargin,
        if (validation.suggestedCategory != null)
          'suggested_category': validation.suggestedCategory,
        if (validation.suggestedCategory != null)
          'suggested_similarity': validation.suggestedSimilarity,
        if (validation.suggestedCategory != null)
          'suggested_sample_size': validation.suggestedSampleSize,
      };
    return jsonEncode(data);
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

class _TranscriptEnrichmentAttempt {
  const _TranscriptEnrichmentAttempt({this.result, this.failureCode});

  final TranscriptEnrichmentResult? result;
  final String? failureCode;
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
