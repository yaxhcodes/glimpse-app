import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/engagement_event.dart';
import '../../core/models/saved_url.dart';
import '../../core/models/url_processing_status.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/usage_providers.dart';
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
import '../home/home_provider.dart';
import '../mindmap/interest_clusters_provider.dart';

/// State for the Add URL flow.
enum AddUrlStatus {
  idle,
  saving, // instant save in progress
  done,
  error,
}

class AddUrlState {
  final AddUrlStatus status;
  final String? errorMessage;
  final String url;
  final int? savedUrlId;

  /// True when the save succeeded but the user's monthly AI-save allowance is
  /// exhausted, so this save will NOT be AI-enriched. The UI surfaces an
  /// upgrade prompt. Reset to false on every new save attempt.
  final bool aiLimitReached;

  const AddUrlState({
    this.status = AddUrlStatus.idle,
    this.errorMessage,
    this.url = '',
    this.savedUrlId,
    this.aiLimitReached = false,
  });

  AddUrlState copyWith({
    AddUrlStatus? status,
    String? errorMessage,
    String? url,
    int? savedUrlId,
    bool clearSavedUrlId = false,
    bool? aiLimitReached,
  }) {
    return AddUrlState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      url: url ?? this.url,
      savedUrlId: clearSavedUrlId ? null : savedUrlId ?? this.savedUrlId,
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
  /// Returns `true` if saved successfully, `false` on validation / duplicate error.
  Future<bool> saveUrl(
    String rawUrl, {
    String? notes,
    bool notifyCapture = false,
  }) async {
    if (_isSaving) return false;
    _isSaving = true;

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
        );
        return false;
      }

      // Exact duplicate check
      final existing = await isarService.findByRawUrl(normalizedUrl);
      if (existing != null) {
        if (notifyCapture) {
          await UrlSaveNotifications.showAlreadyCaptured(existing);
        }
        _isSaving = false;
        state = state.copyWith(
          status: AddUrlStatus.error,
          errorMessage: 'This URL has already been saved',
          savedUrlId: existing.id,
        );
        return false;
      }

      // Instant save with domain-categorizer fallback
      state = state.copyWith(
        status: AddUrlStatus.saving,
        url: normalizedUrl,
        errorMessage: null,
        clearSavedUrlId: true,
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
        ..processingStatus = UrlProcessingStatus.pending
        ..processingId = processingId
        ..processingAttempt = 0
        ..processingUpdatedAt = DateTime.now()
        ..processingError = null
        ..embedding = null; // enrichment will update

      await isarService.saveUrl(savedUrl);
      unawaited(
        isarService.logEvent(type: EngagementEventType.save, url: savedUrl),
      );
      savedUrl
        ..processingStatus = UrlProcessingStatus.queued
        ..processingUpdatedAt = DateTime.now();
      await isarService.updateUrl(savedUrl);
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

      if (notifyCapture) {
        await UrlSaveNotifications.showCaptureStarted();
      }

      // Invalidate providers so Home screen shows the new URL instantly
      _ref.invalidate(urlStreamProvider);
      _ref.invalidate(categoriesProvider);
      _ref.invalidate(askEmptySuggestionsProvider);
      _ref.invalidate(interestClusterThemesProvider);

      // Surface (but never block on) the AI-save allowance: if it's exhausted,
      // the background enrichment will skip AI work, so tell the UI to prompt
      // an upgrade. Pro/dev-override users always read false here. The limit
      // value itself differs between prod and dev builds (see UsageLimits).
      final aiLimitReached = await _ref
          .read(usageServiceProvider)
          .hasReachedLimit(UsageFeature.aiSave, _ref.read(isProUserProvider));

      state = state.copyWith(
        status: AddUrlStatus.done,
        savedUrlId: savedUrl.id,
        aiLimitReached: aiLimitReached,
      );
      _isSaving = false;

      // Kick off background enrichment (fire and forget)
      _enrichInBackground(
        normalizedUrl,
        processingId: processingId,
        notifyCapture: notifyCapture,
      );

      return true;
    } catch (e) {
      _isSaving = false;
      state = state.copyWith(
        status: AddUrlStatus.error,
        errorMessage: e.toString(),
        clearSavedUrlId: true,
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
    final enricher = _ref.read(enrichmentServiceProvider)(
      onEnriched: () {
        // Refresh providers so the URL card progressively hydrates
        _ref.invalidate(urlStreamProvider);
        _ref.invalidate(categoriesProvider);
        _ref.invalidate(askEmptySuggestionsProvider);
        _ref.invalidate(interestClusterThemesProvider);
      },
    );

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
      // First enrich metadata, then AI + embedding
      await enricher.enrichMetadata(url.id);
      await enricher.enrichSingle(url.id);
      if (notifyCapture) {
        final enriched = await isarService.getUrlById(url.id);
        if (enriched != null &&
            enriched.processingStatus == UrlProcessingStatus.ready) {
          await UrlSaveNotifications.showCaptureReady(enriched);
        } else if (enriched != null &&
            enriched.processingStatus == UrlProcessingStatus.failed) {
          await UrlSaveNotifications.showCaptureFailed(enriched);
        }
      }
      developer.log('_findAndEnrich DONE: $normalizedUrl', name: 'AddUrl');
    } catch (e, st) {
      UrlProcessingObserver.logStage(
        'SAVE_FAILED',
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
