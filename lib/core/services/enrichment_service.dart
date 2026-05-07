import 'dart:async';
import 'dart:developer' as developer;

import '../database/isar_service.dart';
import 'category_resolver.dart';
import 'domain_categorizer.dart';
import 'embedding_input.dart';
import 'embedding_service.dart';
import 'gemini_service.dart';
import 'link_preview_service.dart';
import 'usage_service.dart';

/// Background enrichment for saved URLs.
///
/// Processes AI categorization, summaries, and embeddings with
/// bounded concurrency so the UI stays responsive and the save
/// action completes instantly.
class EnrichmentService {
  final IsarService _isarService;
  final GeminiService? _geminiService;
  final EmbeddingService? _embeddingService;
  final LinkPreviewService? _linkService;
  final UsageService _usageService;
  final bool _isPro;
  final void Function()? _onEnriched;

  EnrichmentService({
    required IsarService isarService,
    GeminiService? geminiService,
    EmbeddingService? embeddingService,
    LinkPreviewService? linkService,
    required UsageService usageService,
    required bool isPro,
    void Function()? onEnriched,
  })  : _isarService = isarService,
        _geminiService = geminiService,
        _embeddingService = embeddingService,
        _linkService = linkService,
        _usageService = usageService,
        _isPro = isPro,
        _onEnriched = onEnriched;

  /// Enrich a batch of URLs with bounded concurrency.
  ///
  /// AI (categorize + summarize) runs 2 at a time.
  /// Embeddings run 2 at a time, but only after AI completes for each URL.
  Future<void> enrichBatch(List<int> urlIds) async {
    if (urlIds.isEmpty) return;

    // Phase 1: AI categorization + summary (concurrency 2)
    final aiSemaphore = _Semaphore(2);
    final aiFutures = <Future<void>>[];
    for (final id in urlIds) {
      aiFutures.add(_runWithSemaphore(aiSemaphore, () => _enrichAi(id)));
    }
    await Future.wait(aiFutures);

    // Phase 2: Embeddings (concurrency 2)
    final embSemaphore = _Semaphore(2);
    final embFutures = <Future<void>>[];
    for (final id in urlIds) {
      embFutures.add(_runWithSemaphore(embSemaphore, () => _enrichEmbedding(id)));
    }
    await Future.wait(embFutures);

    // Notify listeners that enrichment is complete
    _onEnriched?.call();
  }

  /// Enrich a single URL with all phases (AI then embedding).
  Future<void> enrichSingle(int urlId) async {
    await _enrichAi(urlId);
    await _enrichEmbedding(urlId);
    _onEnriched?.call();
  }

  /// Enrich metadata for a single URL (fetch title/description/thumbnail).
  /// Used when the URL was saved with only a domain fallback.
  Future<void> enrichMetadata(int urlId) async {
    if (_linkService == null) return;
    final url = await _isarService.getUrlById(urlId);
    if (url == null) return;

    try {
      final metadata = await _linkService.fetchMetadata(url.rawUrl);

      final cleanDescription = metadata.description.trim().toLowerCase() ==
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

      await _isarService.updateUrl(url);
      _onEnriched?.call();
    } catch (e) {
      developer.log('Metadata enrichment failed for $urlId: $e',
          name: 'EnrichmentService');
    }
  }

  /// Phase 1: AI categorization + summary.
  Future<void> _enrichAi(int urlId) async {
    final url = await _isarService.getUrlById(urlId);
    if (url == null) return;

    final platformCat = DomainCategorizer.categorize(url.rawUrl);

    // Skip if already AI-categorized (not just domain fallback)
    if (url.category != platformCat.category && url.summary != null) {
      return;
    }

    final aiLimitReached = await _usageService.hasReachedLimit(
      UsageFeature.aiSave,
      _isPro,
    );

    String category;
    String emoji;
    List<String> tags;
    String? summary;

    if (_geminiService != null && !aiLimitReached) {
      try {
        final result = await _geminiService.categorize(
          title: url.title,
          description: url.description,
          url: url.rawUrl,
        );
        category = result.category;
        emoji = result.emoji;
        tags = result.tags;
        summary = result.summary.isNotEmpty ? result.summary : null;
        await _usageService.incrementUsage(UsageFeature.aiSave);
      } catch (e) {
        developer.log('AI enrichment failed for $urlId: $e',
            name: 'EnrichmentService');
        category = platformCat.category;
        emoji = platformCat.emoji;
        tags = platformCat.tags;
        summary = null;
      }
    } else {
      category = platformCat.category;
      emoji = platformCat.emoji;
      tags = platformCat.tags;
      summary = null;
    }

    // Enrich tags with platform data already stored
    final enrichedTags = [...tags];
    for (final t in url.tags) {
      if (!enrichedTags.contains(t)) enrichedTags.add(t);
    }

    // Reload url in case it was modified concurrently
    final freshUrl = await _isarService.getUrlById(urlId);
    if (freshUrl == null) return;

    freshUrl.category = category;
    freshUrl.categoryEmoji = emoji;
    freshUrl.categories = CategoryResolver.buildCategories(
      primaryCategory: category,
      platformCategory: platformCat.category,
    );
    freshUrl.tags = enrichedTags;
    freshUrl.summary = summary;

    await _isarService.updateUrl(freshUrl);
  }

  /// Phase 2: Generate embedding vector.
  Future<void> _enrichEmbedding(int urlId) async {
    if (_embeddingService == null) return;

    final url = await _isarService.getUrlById(urlId);
    if (url == null) return;

    // Skip if already embedded
    if (url.embedding != null && url.embedding!.isNotEmpty) return;

    try {
      final textToEmbed = buildBookmarkEmbeddingInput(
        title: url.title,
        description: url.description,
        tags: url.tags,
        category: url.category,
        summary: url.summary,
      );
      final vec = await _embeddingService.generateEmbedding(textToEmbed);
      if (vec.isEmpty) return;

      // Reload in case AI enrichment modified it concurrently
      final freshUrl = await _isarService.getUrlById(urlId);
      if (freshUrl == null) return;

      freshUrl.embedding = vec;
      await _isarService.updateUrl(freshUrl);
    } on EmbeddingException catch (e) {
      developer.log('Embedding enrichment failed for $urlId: $e',
          name: 'EnrichmentService');
    }
  }

  Future<T> _runWithSemaphore<T>(_Semaphore sem, Future<T> Function() task) async {
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