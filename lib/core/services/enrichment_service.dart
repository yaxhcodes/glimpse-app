import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kDebugMode;

import '../database/isar_service.dart';
import '../models/saved_url.dart';
import 'category_resolver.dart';
import 'category_taxonomy.dart';
import 'domain_categorizer.dart';
import 'embedding_input.dart';
import 'embedding_service.dart';
import 'gemini_service.dart';
import 'link_preview_service.dart';
import 'tag_noise_filter.dart';
import 'text_cleaner.dart';
import 'transcript_enrichment_service.dart';
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
  })  : _isarService = isarService,
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

    developer.log('enrichBatch START: ${urlIds.length} URLs', name: 'Enrichment');

    // Phase 1: AI categorization + summary (concurrency 2)
    final aiSemaphore = _Semaphore(2);
    final aiFutures = <Future<void>>[];
    for (final id in urlIds) {
      aiFutures.add(_runWithSemaphore(aiSemaphore, () => _enrichAi(id)));
    }
    await Future.wait(aiFutures, eagerError: false);

    // Phase 2: Embeddings (concurrency 2)
    final embSemaphore = _Semaphore(2);
    final embFutures = <Future<void>>[];
    for (final id in urlIds) {
      embFutures.add(_runWithSemaphore(embSemaphore, () => _enrichEmbedding(id)));
    }
    await Future.wait(embFutures, eagerError: false);

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
    } catch (e, st) {
      developer.log('enrichSingle AI phase failed for $urlId: $e',
          name: 'Enrichment', stackTrace: st);
    }
    try {
      await _enrichEmbedding(urlId, force: forceEmbedding);
    } catch (e, st) {
      developer.log('enrichSingle embedding phase failed for $urlId: $e',
          name: 'Enrichment', stackTrace: st);
    }
    _onEnriched?.call();
  }

  /// Enrich metadata for a single URL (fetch title/description/thumbnail).
  /// Used when the URL was saved with only a domain fallback.
  Future<void> enrichMetadata(int urlId) async {
    if (_linkService == null) {
      developer.log('enrichMetadata SKIP: linkService is null for $urlId',
          name: 'Enrichment');
      return;
    }
    final url = await _isarService.getUrlById(urlId);
    if (url == null) {
      developer.log('enrichMetadata SKIP: URL $urlId not found in Isar',
          name: 'Enrichment');
      return;
    }

    developer.log('enrichMetadata START: ${url.rawUrl}', name: 'Enrichment');

    try {
      final metadata = await _linkService.fetchMetadata(url.rawUrl);
      developer.log('enrichMetadata FETCH OK: "${metadata.title}"', name: 'Enrichment');

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
      developer.log('enrichMetadata SAVE OK: ${url.rawUrl}', name: 'Enrichment');
      _onEnriched?.call();
    } catch (e, st) {
      developer.log('enrichMetadata FAILED for $urlId: $e',
          name: 'Enrichment', stackTrace: st);
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
      developer.log('_enrichAi FAILED for $urlId: $e',
          name: 'Enrichment', stackTrace: st);
    }
  }

  Future<void> _enrichAiInner(
    int urlId, {
    bool force = false,
    bool countUsage = true,
  }) async {
    final url = await _isarService.getUrlById(urlId);
    if (url == null) {
      developer.log('_enrichAi SKIP: URL $urlId not found in Isar',
          name: 'Enrichment');
      return;
    }

    developer.log('_enrichAi START: ${url.rawUrl}', name: 'Enrichment');

    final platformCat = DomainCategorizer.categorize(url.rawUrl);

    // Skip if already AI-categorized (not just domain fallback)
    if (!force && url.category != platformCat.category && url.summary != null) {
      developer.log('_enrichAi SKIP (already enriched): ${url.rawUrl}',
          name: 'Enrichment');
      return;
    }

    final aiLimitReached = countUsage
        ? await _usageService.hasReachedLimit(
            UsageFeature.aiSave,
            _isPro,
          )
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

    final transcriptResult = !aiLimitReached && _transcriptEnrichmentService != null
        ? await _transcriptEnrichmentService!.enrichUrl(
            rawUrl: url.rawUrl,
            title: url.title,
            description: url.description,
            thumbnailUrl: url.thumbnailUrl,
            domain: url.domain,
          )
        : null;

    if (transcriptResult != null) {
      final normalized = CategoryTaxonomy.normalize(
        category: transcriptResult.category,
        tags: transcriptResult.tags,
      );
      category = normalized.name;
      emoji = normalized.emoji;
      tags = transcriptResult.tags;
      summary = transcriptResult.summary.isNotEmpty
          ? transcriptResult.summary
          : _metadataFallbackSummary(url);
      enrichedTitle = transcriptResult.meaningfulTitle.isNotEmpty
          ? transcriptResult.meaningfulTitle
          : null;
      enrichedThumbnailUrl = transcriptResult.thumbnailUrl;
      if (countUsage) {
        await _usageService.incrementUsage(UsageFeature.aiSave);
      }
      developer.log(
        '_enrichAi transcript backend RESULT: cat=$category, '
        'tags=${tags.length}, summary=${summary?.length ?? 0} chars',
        name: 'Enrichment',
      );
    } else if (_geminiService != null && !aiLimitReached) {

      try {
        developer.log('_enrichAi CALLING GeminiService.categorize: ${url.rawUrl}',
            name: 'Enrichment');
        final result = await _geminiService!.categorize(
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
        summary = result.summary.isNotEmpty
            ? result.summary
            : _metadataFallbackSummary(url);
        if (countUsage) {
          await _usageService.incrementUsage(UsageFeature.aiSave);
        }
      } catch (e, st) {
        developer.log('_enrichAi Gemini FAILED for $urlId: $e',
            name: 'Enrichment', stackTrace: st);
        category = platformCat.category;
        emoji = platformCat.emoji;
        tags = _metadataFallbackTags(url, platformCat.tags);
        summary = _metadataFallbackSummary(url);
      }
    } else {
      if (_geminiService == null) {
        developer.log('_enrichAi SKIP: GeminiService is null', name: 'Enrichment');
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
      developer.log('_enrichAi SKIP: URL $urlId disappeared before save',
          name: 'Enrichment');
      return;
    }

    freshUrl.category = category;
    freshUrl.categoryEmoji = emoji;
    freshUrl.categories = CategoryResolver.buildCategories(
      primaryCategory: category,
      platformCategory: platformCat.category,
    );
    if (enrichedTitle != null && _shouldReplaceTitle(freshUrl.title, freshUrl.domain)) {
      freshUrl.title = enrichedTitle;
    }
    if (enrichedThumbnailUrl != null && enrichedThumbnailUrl.isNotEmpty) {
      freshUrl.thumbnailUrl = enrichedThumbnailUrl;
    }
    freshUrl.tags = enrichedTags;
    freshUrl.summary = summary;

    await _isarService.updateUrl(freshUrl);
    developer.log('_enrichAi SAVE OK: ${freshUrl.rawUrl} → $category', name: 'Enrichment');
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

  Iterable<String> _candidatePhrases(String text) sync* {
    const stop = {
      'the', 'and', 'for', 'with', 'from', 'into', 'this', 'that', 'his',
      'her', 'their', 'your', 'you', 'are', 'was', 'were', 'video', 'youtube',
      'http', 'https', 'www', 'com',
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

  bool _shouldReplaceTitle(String currentTitle, String domain) {
    final lower = currentTitle.trim().toLowerCase();
    if (lower.isEmpty || lower == domain.toLowerCase()) return true;
    if (lower == 'instagram' || lower == 'instagram reel') return true;
    if (RegExp(r'^(x[0-9a-f]{2,}\s*[·-]?\s*)+$').hasMatch(lower)) return true;
    return lower.contains('on instagram') || lower.startsWith('www.instagram.com');
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
      developer.log('_enrichEmbedding FAILED for $urlId: $e',
          name: 'Enrichment', stackTrace: st);
    }
  }

  Future<void> _enrichEmbeddingInner(int urlId, {bool force = false}) async {
    if (_embeddingService == null) {
      developer.log('_enrichEmbedding SKIP: EmbeddingService is null for $urlId',
          name: 'Enrichment');
      return;
    }

    final url = await _isarService.getUrlById(urlId);
    if (url == null) {
      developer.log('_enrichEmbedding SKIP: URL $urlId not found in Isar',
          name: 'Enrichment');
      return;
    }

    // Skip if already embedded
    if (!force && url.embedding != null && url.embedding!.isNotEmpty) {
      developer.log('_enrichEmbedding SKIP (already embedded): ${url.rawUrl}',
          name: 'Enrichment');
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
      );
      developer.log('_enrichEmbedding CALLING EmbeddingService for ${url.rawUrl}',
          name: 'Enrichment');
      final vec = await _embeddingService!.generateEmbedding(textToEmbed);
      if (vec.isEmpty) {
        developer.log('_enrichEmbedding EMPTY vector returned for ${url.rawUrl}',
            name: 'Enrichment');
        return;
      }

      // Reload in case AI enrichment modified it concurrently
      final freshUrl = await _isarService.getUrlById(urlId);
      if (freshUrl == null) {
        developer.log('_enrichEmbedding SKIP: URL $urlId disappeared before save',
            name: 'Enrichment');
        return;
      }

      freshUrl.embedding = vec;
      await _isarService.updateUrl(freshUrl);
      developer.log('_enrichEmbedding SAVE OK: ${freshUrl.rawUrl} (${vec.length} dims)',
          name: 'Enrichment');
    } on EmbeddingException catch (e, st) {
      developer.log('_enrichEmbedding EmbeddingException for $urlId: $e',
          name: 'Enrichment', stackTrace: st);
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
