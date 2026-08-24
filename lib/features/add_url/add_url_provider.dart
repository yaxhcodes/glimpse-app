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
import '../../core/services/app_task_service.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/services/usage_service.dart';
import '../../core/services/domain_categorizer.dart';
import '../../core/services/category_resolver.dart';
import '../../core/services/enrichment_service.dart';
import '../../core/services/link_preview_service.dart';
import '../../core/services/rediscover_utility_profile.dart';
import '../../core/services/tag_noise_filter.dart';
import '../../core/services/url_save_notifications.dart';
import '../../core/services/url_enrichment_job.dart';
import '../../core/services/url_enrichment_notification_guard.dart';
import '../../core/services/url_processing_observer.dart';
import '../../l10n/app_locale.dart';
import '../ask/ask_empty_suggestions_provider.dart';
import '../collections/collections_provider.dart';
import '../home/home_provider.dart';
import '../rediscover/rediscover_daily_set.dart';
import '../rediscover/rediscover_provider.dart';
import '../rediscover/rediscover_topic_pulse_provider.dart';
import '../shell/navigation_discovery_provider.dart';

/// State for the Add URL flow.
enum AddUrlStatus {
  idle,
  saving, // instant save in progress
  done,
  duplicate,
  error,
}

enum AddUrlOutcome { none, captured, alreadySaved, capturedWithRelated }

enum AddUrlEnrichmentExecution { immediate, durable }

class AddUrlState {
  final AddUrlStatus status;
  final String? errorMessage;
  final String url;
  final int? savedUrlId;
  final AddUrlOutcome outcome;
  final List<int> relatedSaveIds;
  final bool durableEnrichmentScheduled;

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
    this.durableEnrichmentScheduled = true,
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
    bool? durableEnrichmentScheduled,
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
      durableEnrichmentScheduled:
          durableEnrichmentScheduled ?? this.durableEnrichmentScheduled,
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
    AddUrlEnrichmentExecution enrichmentExecution =
        AddUrlEnrichmentExecution.immediate,
    bool notifyOnCompletion = false,
  }) async {
    if (_isSaving) return false;
    _isSaving = true;

    final authService = _ref.read(authServiceProvider);
    var user = authService.currentUser;
    if (user == null) {
      try {
        user = await _ref.read(authControllerProvider.future);
      } catch (error, stackTrace) {
        developer.log(
          'Could not finish auth restoration before local save.',
          name: 'AddUrl',
          error: error,
          stackTrace: stackTrace,
        );
        user = authService.currentUser;
      }
    }
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
            final scheduled =
                enrichmentExecution == AddUrlEnrichmentExecution.durable
                ? await _scheduleDurableEnrichment(
                    restored,
                    processingId: processingId,
                    notifyOnCompletion: notifyOnCompletion,
                    evaluateNavigationDiscovery: false,
                  )
                : true;
            state = state.copyWith(durableEnrichmentScheduled: scheduled);
            _enrichInBackground(
              normalizedUrl,
              processingId: processingId,
              notifyOnCompletion: notifyOnCompletion,
              evaluateNavigationDiscovery: false,
              keepAlive:
                  enrichmentExecution == AddUrlEnrichmentExecution.durable,
            );
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
        durableEnrichmentScheduled: true,
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

      if (enrichmentExecution == AddUrlEnrichmentExecution.durable) {
        final scheduled = await _scheduleDurableEnrichment(
          savedUrl,
          processingId: processingId,
          notifyOnCompletion: notifyOnCompletion,
          evaluateNavigationDiscovery: true,
        );
        state = state.copyWith(durableEnrichmentScheduled: scheduled);
      }
      _enrichInBackground(
        normalizedUrl,
        processingId: processingId,
        notifyOnCompletion: notifyOnCompletion,
        evaluateNavigationDiscovery: true,
        keepAlive: enrichmentExecution == AddUrlEnrichmentExecution.durable,
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
    required bool notifyOnCompletion,
    required bool evaluateNavigationDiscovery,
    required bool keepAlive,
  }) {
    unawaited(
      _startLocalizedEnrichment(
        normalizedUrl,
        processingId: processingId,
        notifyOnCompletion: notifyOnCompletion,
        evaluateNavigationDiscovery: evaluateNavigationDiscovery,
        keepAlive: keepAlive,
      ),
    );
  }

  Future<void> _startLocalizedEnrichment(
    String normalizedUrl, {
    required String processingId,
    required bool notifyOnCompletion,
    required bool evaluateNavigationDiscovery,
    required bool keepAlive,
  }) async {
    try {
      // Isar's live URL stream progressively hydrates the card after every
      // persisted enrichment stage. Restarting that stream from onEnriched
      // multiplied full-library emissions and caused visible frame stalls.
      final enricher = await createLocalizedEnrichmentService(_ref);

      // Find the URL's ID we just saved and enrich it
      await _findAndEnrich(
        normalizedUrl,
        enricher,
        processingId: processingId,
        notifyOnCompletion: notifyOnCompletion,
        evaluateNavigationDiscovery: evaluateNavigationDiscovery,
      );
    } finally {
      if (keepAlive) {
        await AppTaskService().finishEnrichmentKeepAlive(processingId);
      }
    }
  }

  Future<void> _findAndEnrich(
    String normalizedUrl,
    EnrichmentService enricher, {
    required String processingId,
    required bool notifyOnCompletion,
    required bool evaluateNavigationDiscovery,
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
      final enrichmentResult = await enricher.enrichSingle(
        url.id,
        initialFailures: failedTasks,
      );
      final enriched = await isarService.getUrlById(url.id);
      final enrichmentSucceeded =
          enriched != null &&
          UrlProcessingStatus.isSuccessfulTerminal(enriched.processingStatus);
      _refreshDerivedDataAfterEnrichment();
      if (evaluateNavigationDiscovery && enrichmentSucceeded) {
        unawaited(
          _ref
              .read(navigationDiscoveryProvider.notifier)
              .recordCompletedNewSave(url.id),
        );
      }
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
      if (notifyOnCompletion) {
        if (enrichmentResult.aiLimitReached) {
          await UrlEnrichmentNotificationGuard.deliverOnce(
            processingId,
            UrlEnrichmentNotificationOutcome.aiLimitReached,
            () => UrlSaveNotifications.showAiLimitReached(
              isPro: _ref.read(isProUserProvider),
              savedUrlId: url.id,
            ),
          );
        } else if (enrichmentSucceeded) {
          await UrlEnrichmentNotificationGuard.deliverOnce(
            processingId,
            UrlEnrichmentNotificationOutcome.ready,
            () => UrlSaveNotifications.showCaptureReady(enriched),
          );
        } else if (enriched != null &&
            enriched.processingStatus == UrlProcessingStatus.failed) {
          await UrlEnrichmentNotificationGuard.deliverOnce(
            processingId,
            UrlEnrichmentNotificationOutcome.failed,
            () => UrlSaveNotifications.showCaptureFailed(enriched),
          );
        }
      }
      if (enrichmentResult.aiLimitReached || enrichmentSucceeded) {
        await UrlEnrichmentScheduler.cancel(url.id);
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

  Future<bool> _scheduleDurableEnrichment(
    SavedUrl savedUrl, {
    required String processingId,
    required bool notifyOnCompletion,
    required bool evaluateNavigationDiscovery,
  }) async {
    final isPro = _ref.read(isProUserProvider);
    if (notifyOnCompletion) {
      await UrlEnrichmentNotificationGuard.markDeliveryExpected(processingId);
    }
    final keepAliveStarted = await AppTaskService().startEnrichmentKeepAlive(
      processingId,
    );
    await EntitlementService.persistEffectiveProSnapshot(isPro);
    final outputLocale = appLocaleTag(await loadEffectiveAppLocale());
    final scheduled = await UrlEnrichmentScheduler.schedule(
      UrlEnrichmentJob(
        savedUrlId: savedUrl.id,
        processingId: processingId,
        outputLocale: outputLocale,
        notifyOnCompletion: notifyOnCompletion,
        evaluateNavigationDiscovery: evaluateNavigationDiscovery,
        isPro: isPro,
      ),
    );
    return keepAliveStarted && scheduled;
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
    final pulse = await detectAndPersistTopicPulseForSave(
      isar: isarService,
      sourceId: sourceId,
    );
    if (pulse == null) return const [];
    await RediscoverUtilityProfileStore.recordTopicSave(
      pulse.topicKey,
      at: pulse.detectedAt,
    );
    _ref.invalidate(rediscoverUtilityProfileProvider);
    _ref.invalidate(rediscoverTopicPulsesProvider);
    _ref.invalidate(rediscoverDailySetProvider);
    return pulse.archiveSaveIds.take(3).toList();
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
