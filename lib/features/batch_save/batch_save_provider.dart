import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/saved_url.dart';
import '../../core/models/url_processing_status.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/category_resolver.dart';
import '../../core/services/domain_categorizer.dart';
import '../../core/services/link_preview_service.dart';
import '../../core/services/session_tracking_service.dart';
import '../ask/ask_empty_suggestions_provider.dart';
import '../home/home_provider.dart';
import '../mindmap/interest_clusters_provider.dart';
import 'batch_save_models.dart';

/// Overall status of the batch save flow.
enum BatchSaveStatus {
  preview,    // showing preview, user can review
  saving,     // instant-saving URLs
  enriching,  // saved; organizing in background
  done,       // all saved
  error,      // unrecoverable error
}

class BatchSaveState {
  final BatchSaveStatus status;
  final List<BatchUrlItem> items;
  final String sessionId;
  final String? errorMessage;
  final int savedCount;
  final int totalToSave;

  const BatchSaveState({
    this.status = BatchSaveStatus.preview,
    this.items = const [],
    required this.sessionId,
    this.errorMessage,
    this.savedCount = 0,
    this.totalToSave = 0,
  });

  BatchSaveState copyWith({
    BatchSaveStatus? status,
    List<BatchUrlItem>? items,
    String? sessionId,
    String? errorMessage,
    int? savedCount,
    int? totalToSave,
  }) {
    return BatchSaveState(
      status: status ?? this.status,
      items: items ?? this.items,
      sessionId: sessionId ?? this.sessionId,
      errorMessage: errorMessage ?? this.errorMessage,
      savedCount: savedCount ?? this.savedCount,
      totalToSave: totalToSave ?? this.totalToSave,
    );
  }

  int get readyCount =>
      items.where((i) => i.status == BatchItemStatus.ready).length;

  int get duplicateCount =>
      items.where((i) => i.status == BatchItemStatus.duplicate).length;

  int get errorCount =>
      items.where((i) => i.status == BatchItemStatus.error).length;

  bool get canSave => readyCount > 0;
}

/// Orchestrates multi-URL capture with instant save and background enrichment.
///
/// Phase 1 (instant): Save all URLs to Isar immediately using metadata
/// already fetched during preview + domain-categorizer fallback for AI fields.
///
/// Phase 2 (background): Enrich each URL with AI categorization, summaries,
/// and embeddings via [EnrichmentService].
class BatchSaveNotifier extends StateNotifier<BatchSaveState> {
  final Ref _ref;
  bool _disposed = false;

  BatchSaveNotifier(this._ref, List<String> urls)
      : super(BatchSaveState(
          items: urls.map((u) => BatchUrlItem(rawUrl: u)).toList(),
          sessionId: _generateSessionId(),
        )) {
    _startMetadataFetch();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static String _generateSessionId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = now.toString().substring(7);
    return 'session_${now}_$random';
  }

  /// Begin fetching metadata for all URLs concurrently (capped).
  Future<void> _startMetadataFetch() async {
    final items = state.items;
    final isar = _ref.read(isarServiceProvider);
    final linkService = _ref.read(linkPreviewServiceProvider);

    // Check duplicates first (fast, local)
    final updatedItems = <BatchUrlItem>[];
    for (final item in items) {
      if (_disposed) return;
      final existing = await isar.findByRawUrl(item.rawUrl);
      if (existing != null) {
        updatedItems.add(item.copyWith(
          status: BatchItemStatus.duplicate,
          isDuplicate: true,
        ));
      } else {
        updatedItems.add(item);
      }
    }
    if (_disposed) return;
    state = state.copyWith(items: updatedItems);

    // Fetch metadata with limited concurrency
    const concurrency = 4;
    final queue = List<BatchUrlItem>.from(updatedItems)
      ..retainWhere((i) => !i.isDuplicate);

    Future<void> fetchOne(BatchUrlItem item) async {
      if (_disposed) return;
      final idx = state.items.indexWhere((i) => i.rawUrl == item.rawUrl);
      if (idx < 0) return;

      _replaceItem(idx, item.copyWith(status: BatchItemStatus.fetching));

      try {
        final metadata = await linkService.fetchMetadata(item.rawUrl);
        if (_disposed) return;
        _replaceItem(
          idx,
          item.copyWith(
            status: BatchItemStatus.ready,
            metadata: metadata,
          ),
        );
      } catch (e) {
        developer.log('Batch metadata fetch failed: $e', name: 'BatchSave');
        if (_disposed) return;
        _replaceItem(
          idx,
          item.copyWith(
            status: BatchItemStatus.ready,
            metadata: LinkMetadata(
              title: item.displayDomain,
              description: '',
              domain: item.displayDomain,
            ),
            error: 'Could not fetch preview',
          ),
        );
      }
    }

    for (var i = 0; i < queue.length; i += concurrency) {
      final chunk = queue.skip(i).take(concurrency);
      await Future.wait(chunk.map(fetchOne));
    }
  }

  void _replaceItem(int index, BatchUrlItem newItem) {
    final list = List<BatchUrlItem>.from(state.items);
    list[index] = newItem;
    state = state.copyWith(items: list);
  }

  /// Instant-save all non-duplicate URLs, then start background enrichment.
  ///
  /// URLs are persisted to Isar immediately with domain-categorizer
  /// fallback for AI fields. Enrichment (AI tags, summaries, embeddings)
  /// runs in the background so the user sees success instantly.
  Future<void> saveAll() async {
    final toSave = state.items
        .where((i) => i.status == BatchItemStatus.ready)
        .toList();

    if (toSave.isEmpty) return;

    state = state.copyWith(
      status: BatchSaveStatus.saving,
      totalToSave: toSave.length,
      savedCount: 0,
    );

    final isar = _ref.read(isarServiceProvider);
    final sessionService = SessionTrackingService();

    final savedIds = <int>[];
    var savedCount = 0;

    // Phase 1: Instant save with domain-categorizer fallback
    for (final item in toSave) {
      if (_disposed) break;
      try {
        final metadata = item.metadata ??
            LinkMetadata(
              title: item.displayDomain,
              description: '',
              domain: item.displayDomain,
            );

        final platformCat = DomainCategorizer.categorize(item.rawUrl);

        // Build tags from metadata + platform categorizer
        final tags = [...platformCat.tags];
        if (metadata.extractedTags != null) {
          for (final t in metadata.extractedTags!) {
            if (!tags.contains(t)) tags.add(t);
          }
        }
        if (metadata.author != null && metadata.author!.isNotEmpty) {
          tags.add(metadata.author!);
        }
        if (metadata.siteName != null &&
            metadata.siteName!.isNotEmpty &&
            metadata.siteName!.toLowerCase() !=
                platformCat.category.toLowerCase()) {
          tags.add(metadata.siteName!);
        }

        final cleanDescription = metadata.description.trim().toLowerCase() ==
                metadata.title.trim().toLowerCase()
            ? ''
            : metadata.description;

        final savedUrl = SavedUrl()
          ..rawUrl = item.rawUrl
          ..domain = metadata.domain
          ..title = metadata.title
          ..description = cleanDescription
          ..thumbnailUrl = metadata.imageUrl
          ..category = platformCat.category
          ..categoryEmoji = platformCat.emoji
          ..categories = CategoryResolver.buildCategories(
            primaryCategory: platformCat.category,
            platformCategory: platformCat.category,
          )
          ..tags = tags
          ..summary = null
          ..processingStatus = UrlProcessingStatus.queued
          ..processingId = '${state.sessionId}-${savedIds.length + 1}'
          ..processingAttempt = 0
          ..processingUpdatedAt = DateTime.now()
          ..processingError = null
          ..savedAt = DateTime.now()
          ..embedding = null
          ..saveSessionId = state.sessionId;

        final id = await isar.saveUrl(savedUrl);
        savedIds.add(id);
        savedCount++;

        if (_disposed) break;
        state = state.copyWith(savedCount: savedCount);
      } catch (e) {
        developer.log('Batch instant save failed: $e', name: 'BatchSave');
      }
    }

    // Record session mappings
    if (savedIds.isNotEmpty) {
      await sessionService.recordBatch(
        urlIds: savedIds,
        sessionId: state.sessionId,
      );
    }

    // Invalidate providers so Home screen shows new URLs immediately
    _ref.invalidate(urlStreamProvider);
    _ref.invalidate(categoriesProvider);
    _ref.invalidate(askEmptySuggestionsProvider);
    _ref.invalidate(interestClusterThemesProvider);

    // Transition to "enriching" state — user sees success + organizing message
    state = state.copyWith(
      status: BatchSaveStatus.enriching,
      savedCount: savedCount,
    );

    // Phase 2: Background enrichment (AI tags, summaries, embeddings)
    if (savedIds.isNotEmpty) {
      _enrichInBackground(savedIds);
    }
  }

  /// Kick off background enrichment without awaiting it.
  /// Failures are logged but never block the user.
  void _enrichInBackground(List<int> urlIds) {
    developer.log('_enrichInBackground START: ${urlIds.length} URLs: $urlIds',
        name: 'BatchSave');

    final enricher = _ref.read(enrichmentServiceProvider)(
      onEnriched: () {
        // Refresh providers so the UI progressively updates
        if (!_disposed) {
          _ref.invalidate(urlStreamProvider);
          _ref.invalidate(categoriesProvider);
          _ref.invalidate(askEmptySuggestionsProvider);
          _ref.invalidate(interestClusterThemesProvider);
        }
      },
    );

    enricher.enrichBatch(urlIds).then((_) {
      developer.log('_enrichInBackground COMPLETE', name: 'BatchSave');
    }).catchError((e, st) {
      developer.log('Background enrichment batch failed: $e',
          name: 'BatchSave', stackTrace: st);
    });
  }

  void cancel() {
    // Nothing to cancel — saves are instant, enrichment is fire-and-forget.
  }
}

final batchSaveProvider = StateNotifierProvider.autoDispose
    .family<BatchSaveNotifier, BatchSaveState, List<String>>(
  (ref, urls) => BatchSaveNotifier(ref, urls),
);
