import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/engagement_event.dart';
import '../../core/models/saved_url.dart';
import '../../core/models/url_processing_status.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/usage_providers.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/services/usage_service.dart';
import '../../core/services/domain_categorizer.dart';
import '../../core/services/category_resolver.dart';
import '../../core/services/enrichment_service.dart';
import '../../core/services/link_preview_service.dart';
import '../../core/services/tag_noise_filter.dart';
import '../../core/services/url_save_notifications.dart';
import '../../core/services/url_processing_observer.dart';
import '../ask/ask_empty_suggestions_provider.dart';
import '../collections/collections_provider.dart';
import '../home/home_provider.dart';
import '../rediscover/rediscover_memory_prefs.dart';
import '../rediscover/rediscover_provider.dart';

/// State for the Add URL flow.
enum AddUrlStatus {
  idle,
  saving, // instant save in progress
  done,
  duplicate,
  error,
}

enum AddUrlOutcome { none, captured, alreadySaved, capturedWithRelated }

class AddUrlState {
  final AddUrlStatus status;
  final String? errorMessage;
  final String url;
  final int? savedUrlId;
  final AddUrlOutcome outcome;
  final List<int> relatedSaveIds;

  /// True when the save succeeded but the user's monthly AI-save allowance is
  /// exhausted, so this save will NOT be AI-enriched. The UI surfaces an
  /// upgrade prompt. Reset to false on every new save attempt.
  final bool aiLimitReached;

  const AddUrlState({
    this.status = AddUrlStatus.idle,
    this.errorMessage,
    this.url = '',
    this.savedUrlId,
    this.outcome = AddUrlOutcome.none,
    this.relatedSaveIds = const [],
    this.aiLimitReached = false,
  });

  AddUrlState copyWith({
    AddUrlStatus? status,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? url,
    int? savedUrlId,
    bool clearSavedUrlId = false,
    AddUrlOutcome? outcome,
    List<int>? relatedSaveIds,
    bool clearRelatedSaveIds = false,
    bool? aiLimitReached,
  }) {
    return AddUrlState(
      status: status ?? this.status,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      url: url ?? this.url,
      savedUrlId: clearSavedUrlId ? null : savedUrlId ?? this.savedUrlId,
      outcome: outcome ?? this.outcome,
      relatedSaveIds: clearRelatedSaveIds
          ? const []
          : relatedSaveIds ?? this.relatedSaveIds,
      aiLimitReached: aiLimitReached ?? this.aiLimitReached,
    );
  }
}

/// Instant-save URL with domain-categorizer fallback, then kicks off
/// background enrichment (metadata, AI, embedding).
class AddUrlNotifier extends StateNotifier<AddUrlState> {
  final Ref _ref;
  bool _isSaving = false;

  AddUrlNotifier(this._ref) : super(const AddUrlState());

  /// Instant-save a URL using domain-categorizer fallback for AI fields.
  /// Background enrichment (AI categorization, embedding) runs afterwards.
  ///
  /// Returns `true` when a new row is captured or an existing row is assigned
  /// to the requested collection. Unassigned exact duplicates remain a
  /// successful resurfacing outcome in [state], but return `false` so manual
  /// entry screens can keep the existing-save preview visible.
  Future<bool> saveUrl(
    String rawUrl, {
    String? notes,
    int? collectionId,
    bool notifyCapture = false,
    bool showCaptureAcknowledgement = true,
  }) async {
    if (_isSaving) return false;
    _isSaving = true;

    final user = _ref.read(authServiceProvider).currentUser;
    if (user == null) {
      _isSaving = false;
      state = state.copyWith(
        status: AddUrlStatus.error,
        errorMessage: 'Sign in to save links.',
        clearSavedUrlId: true,
        outcome: AddUrlOutcome.none,
        clearRelatedSaveIds: true,
        aiLimitReached: false,
      );
      return false;
    }

    final isarService = _ref.read(isarServiceProvider);

    final startedAt = DateTime.now();
    final processingId = const Uuid().v4();
    UrlProcessingObserver.logStage(
      'SAVE_RECEIVED',
      processingId: processingId,
      url: rawUrl,
      attempt: 0,
    );
    final normalizedUrl = LinkPreviewService.normalizeUrl(rawUrl);
    UrlProcessingObserver.logStage(
      'URL_NORMALIZED',
      processingId: processingId,
      url: normalizedUrl,
      attempt: 0,
      duration: DateTime.now().difference(startedAt),
    );

    try {
      if (!LinkPreviewService.isValidUrl(normalizedUrl)) {
        _isSaving = false;
        state = state.copyWith(
          status: AddUrlStatus.error,
          errorMessage: 'Please enter a valid URL',
          clearSavedUrlId: true,
          outcome: AddUrlOutcome.none,
          clearRelatedSaveIds: true,
        );
        return false;
      }

      // Exact duplicate check
      final existing = await isarService.findByRawUrl(normalizedUrl);
      if (existing != null) {
        if (existing.isInBin) {
          final restored = await isarService.resaveUrlFromBin(
            existing.id,
            userNotes: notes,
          );
          if (restored == null) {
            throw StateError('The link could not be restored from Bin.');
          }
          final needsEnrichment = !restored.isProcessingReady;
          if (needsEnrichment) {
            restored
              ..processingStatus = UrlProcessingStatus.queued
              ..processingId = processingId
              ..processingUpdatedAt = DateTime.now()
              ..processingError = null;
            await isarService.updateUrl(restored);
          }
          final addedToCollection =
              collectionId == null ||
              await _addToCollection(
                urlId: restored.id,
                collectionId: collectionId,
              );
          _ref.invalidate(categoriesProvider);
          _ref.invalidate(collectionsSummaryProvider);
          _ref.invalidate(rediscoverRecapsProvider);
          _ref.invalidate(recentlyResurfacedProvider);
          _ref.invalidate(relatedSavesProvider);

          final aiLimitReached = needsEnrichment
              ? await _ref
                    .read(usageServiceProvider)
                    .hasReachedLocalLimit(
                      UsageFeature.aiSave,
                      _ref.read(isProUserProvider),
                    )
              : false;
          state = state.copyWith(
            status: addedToCollection ? AddUrlStatus.done : AddUrlStatus.error,
            errorMessage: addedToCollection
                ? null
                : 'The link was restored, but it could not be added to the collection.',
            clearErrorMessage: addedToCollection,
            savedUrlId: restored.id,
            outcome: AddUrlOutcome.captured,
            clearRelatedSaveIds: true,
            aiLimitReached: aiLimitReached,
          );
          _isSaving = false;
          if (needsEnrichment) {
            if (notifyCapture && showCaptureAcknowledgement) {
              await UrlSaveNotifications.showCaptureStarted();
            }
            _enrichInBackground(
              normalizedUrl,
              processingId: processingId,
              notifyCapture: notifyCapture,
            );
          } else if (notifyCapture && showCaptureAcknowledgement) {
            await UrlSaveNotifications.showAlreadyCaptured(restored);
          }
          return addedToCollection;
        }
        final addedToCollection =
            collectionId == null ||
            await _addToCollection(
              urlId: existing.id,
              collectionId: collectionId,
            );
        await isarService.updateResurfacedAt(existing.id, DateTime.now());
        if (existing.rediscoverDismissedAt != null) {
          await isarService.updateRediscoverDismissedAt(existing.id, null);
        }
        if (notifyCapture && showCaptureAcknowledgement) {
          await UrlSaveNotifications.showAlreadyCaptured(existing);
        }
        _ref.invalidate(rediscoverRecapsProvider);
        _ref.invalidate(recentlyResurfacedProvider);
        _ref.invalidate(relatedSavesProvider);
        _isSaving = false;
        if (!addedToCollection) {
          state = state.copyWith(
            status: AddUrlStatus.error,
            errorMessage:
                'This link is saved, but it could not be added to the collection.',
            savedUrlId: existing.id,
            outcome: AddUrlOutcome.alreadySaved,
            clearRelatedSaveIds: true,
          );
          return false;
        }
        state = state.copyWith(
          status: collectionId == null
              ? AddUrlStatus.duplicate
              : AddUrlStatus.done,
          clearErrorMessage: true,
          savedUrlId: existing.id,
          outcome: AddUrlOutcome.alreadySaved,
          clearRelatedSaveIds: true,
        );
        return collectionId != null;
      }

      // Instant save with domain-categorizer fallback
      state = state.copyWith(
        status: AddUrlStatus.saving,
        url: normalizedUrl,
        clearErrorMessage: true,
        clearSavedUrlId: true,
        outcome: AddUrlOutcome.none,
        clearRelatedSaveIds: true,
      );

      final platformCat = DomainCategorizer.categorize(normalizedUrl);
      final domain = _extractDomain(normalizedUrl);
      final platform = platformCat.category;

      final savedUrl = SavedUrl()
        ..rawUrl = normalizedUrl
        ..domain = domain
        ..title =
            domain // placeholder — enrichment will update
        ..description = ''
        ..thumbnailUrl =
            null // enrichment will update
        ..category = platformCat.category
        ..categoryEmoji = platformCat.emoji
        ..categories = CategoryResolver.buildCategories(
          primaryCategory: platformCat.category,
          platformCategory: platformCat.category,
        )
        ..tags = TagNoiseFilter.filterTags(platformCat.tags)
        ..summary =
            null // enrichment will update
        ..userNotes = notes
        ..savedAt = DateTime.now()
        ..processingStatus = UrlProcessingStatus.queued
        ..processingId = processingId
        ..processingAttempt = 0
        ..processingUpdatedAt = DateTime.now()
        ..processingError = null
        ..embedding = null; // enrichment will update

      await isarService.saveUrl(savedUrl);
      unawaited(
        isarService.logEvent(type: EngagementEventType.save, url: savedUrl),
      );
      final addedToCollection =
          collectionId == null ||
          await _addToCollection(
            urlId: savedUrl.id,
            collectionId: collectionId,
          );
      UrlProcessingObserver.logStage(
        'JOB_CREATED',
        processingId: processingId,
        saveId: savedUrl.id.toString(),
        url: normalizedUrl,
        platform: platform,
        attempt: 0,
        duration: DateTime.now().difference(startedAt),
      );

      developer.log(
        'saveUrl OK: id=${savedUrl.id} url=$normalizedUrl',
        name: 'AddUrl',
      );

      if (notifyCapture && showCaptureAcknowledgement) {
        await UrlSaveNotifications.showCaptureStarted();
      }

      // Invalidate providers so Home screen shows the new URL instantly
      _ref.invalidate(categoriesProvider);

      // Surface (but never block on) the AI-save allowance: if it's exhausted,
      // the background enrichment will skip AI work, so tell the UI to prompt
      // an upgrade. Pro/dev-override users always read false here. The limit
      // value itself differs between prod and dev builds (see UsageLimits).
      final aiLimitReached = await _ref
          .read(usageServiceProvider)
          .hasReachedLocalLimit(
            UsageFeature.aiSave,
            _ref.read(isProUserProvider),
          );

      state = state.copyWith(
        status: addedToCollection ? AddUrlStatus.done : AddUrlStatus.error,
        errorMessage: addedToCollection
            ? null
            : 'The link was saved, but it could not be added to the collection.',
        clearErrorMessage: addedToCollection,
        savedUrlId: savedUrl.id,
        outcome: AddUrlOutcome.captured,
        clearRelatedSaveIds: true,
        aiLimitReached: aiLimitReached,
      );
      _isSaving = false;

      // Kick off background enrichment (fire and forget)
      _enrichInBackground(
        normalizedUrl,
        processingId: processingId,
        notifyCapture: notifyCapture,
      );
      unawaited(
        _ref
            .read(analyticsServiceProvider)
            .trackEvent(AnalyticsEvent.saveCompleted),
      );

      return addedToCollection;
    } catch (e) {
      _isSaving = false;
      state = state.copyWith(
        status: AddUrlStatus.error,
        errorMessage: e.toString(),
        clearSavedUrlId: true,
        outcome: AddUrlOutcome.none,
        clearRelatedSaveIds: true,
      );
      return false;
    }
  }

  /// Background enrichment: fetch metadata, AI categorize, generate embedding.
  /// Runs after instant save so the user never waits for it.
  void _enrichInBackground(
    String normalizedUrl, {
    required String processingId,
    required bool notifyCapture,
  }) {
    // Isar's live URL stream progressively hydrates the card after every
    // persisted enrichment stage. Restarting that stream from onEnriched
    // multiplied full-library emissions and caused visible frame stalls.
    final enricher = _ref.read(enrichmentServiceProvider)();

    // Find the URL's ID we just saved and enrich it
    _findAndEnrich(
      normalizedUrl,
      enricher,
      processingId: processingId,
      notifyCapture: notifyCapture,
    );
  }

  Future<void> _findAndEnrich(
    String normalizedUrl,
    EnrichmentService enricher, {
    required String processingId,
    required bool notifyCapture,
  }) async {
    try {
      final isarService = _ref.read(isarServiceProvider);
      final url = await isarService.findByRawUrl(normalizedUrl);
      if (url == null) {
        developer.log(
          '_findAndEnrich: URL not found after save: $normalizedUrl',
          name: 'AddUrl',
        );
        return;
      }
      developer.log(
        '_findAndEnrich START: id=${url.id} url=$normalizedUrl',
        name: 'AddUrl',
      );
      UrlProcessingObserver.logStage(
        'JOB_STARTED',
        processingId: processingId,
        saveId: url.id.toString(),
        url: normalizedUrl,
        platform: url.category,
        attempt: url.processingAttempt ?? 0,
      );
      final failedTasks = <String>[];
      final metadataCompleted = await enricher.enrichMetadata(url.id);
      if (!metadataCompleted) {
        failedTasks.add('metadata_failed');
      }
      await enricher.enrichSingle(url.id, initialFailures: failedTasks);
      _refreshDerivedDataAfterEnrichment();
      final relatedIds = await _surfaceSimilarOlderSaves(url.id);
      if (relatedIds.isNotEmpty) {
        _ref.invalidate(rediscoverRecapsProvider);
        _ref.invalidate(recentlyResurfacedProvider);
        _ref.invalidate(relatedSavesProvider);
        if (mounted && state.savedUrlId == url.id) {
          state = state.copyWith(
            outcome: AddUrlOutcome.capturedWithRelated,
            relatedSaveIds: relatedIds,
          );
        }
      }
      if (notifyCapture) {
        final enriched = await isarService.getUrlById(url.id);
        if (enriched != null &&
            UrlProcessingStatus.isSuccessfulTerminal(
              enriched.processingStatus,
            )) {
          await UrlSaveNotifications.showCaptureReady(enriched);
        } else if (enriched != null &&
            enriched.processingStatus == UrlProcessingStatus.failed) {
          await UrlSaveNotifications.showCaptureFailed(enriched);
        }
      }
      developer.log('_findAndEnrich DONE: $normalizedUrl', name: 'AddUrl');
    } catch (e, st) {
      UrlProcessingObserver.logStage(
        'BACKGROUND_ENRICHMENT_FAILED',
        processingId: processingId,
        url: normalizedUrl,
        error: e,
      );
      developer.log(
        'Background enrichment failed: $e',
        name: 'AddUrl',
        stackTrace: st,
      );
    }
  }

  void _refreshDerivedDataAfterEnrichment() {
    // Refresh expensive derived surfaces once after the pipeline settles,
    // rather than once for every processing-status write.
    _ref.invalidate(categoriesProvider);
    _ref.invalidate(askEmptySuggestionsProvider);
    _ref.invalidate(rediscoverRecapsProvider);
    _ref.invalidate(recentlyResurfacedProvider);
    _ref.invalidate(relatedSavesProvider);
  }

  Future<List<int>> _surfaceSimilarOlderSaves(int sourceId) async {
    final isarService = _ref.read(isarServiceProvider);
    final source = await isarService.getUrlById(sourceId);
    final embedding = source?.embedding;
    if (source == null || embedding == null || embedding.isEmpty) {
      return const [];
    }

    final scored = await isarService.semanticSearchScored(
      embedding,
      limit: 8,
      minScore: 0.72,
    );
    final related = <int>[];
    for (final entry in scored) {
      final candidate = entry.key;
      if (candidate.id == source.id) continue;
      if (!candidate.savedAt.isBefore(source.savedAt)) continue;
      if (candidate.isDone || candidate.rediscoverDismissedAt != null) continue;
      related.add(candidate.id);
      await isarService.updateResurfacedAt(candidate.id, DateTime.now());
      if (related.length >= 3) break;
    }
    await RediscoverMemoryPrefs.saveRelatedSaves(
      sourceId: source.id,
      relatedIds: related,
    );
    return related;
  }

  Future<bool> _addToCollection({
    required int urlId,
    required int collectionId,
  }) async {
    final isarService = _ref.read(isarServiceProvider);
    try {
      final collection = await isarService.getCollectionById(collectionId);
      if (collection == null) {
        throw StateError('Collection $collectionId no longer exists.');
      }
      await isarService.addUrlToCollection(
        collectionId: collectionId,
        urlId: urlId,
      );
      _ref.invalidate(collectionsListProvider);
      _ref.invalidate(collectionsSummaryProvider);
      _ref.invalidate(collectionMetaProvider(collectionId));
      _ref.invalidate(collectionUrlsProvider(collectionId));
      return true;
    } catch (error, stackTrace) {
      developer.log(
        'Could not add the saved URL to collection $collectionId.',
        name: 'AddUrl',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  String _extractDomain(String url) {
    try {
      final host = Uri.parse(url).host.toLowerCase();
      return host.startsWith('www.') ? host.substring(4) : host;
    } catch (_) {
      return url;
    }
  }

  void reset() {
    _isSaving = false;
    state = const AddUrlState();
  }
}

final addUrlProvider = StateNotifierProvider<AddUrlNotifier, AddUrlState>((
  ref,
) {
  return AddUrlNotifier(ref);
});
