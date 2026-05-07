import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/link_preview_service.dart';
import '../../core/services/domain_categorizer.dart';
import '../../core/services/category_resolver.dart';
import '../ask/ask_empty_suggestions_provider.dart';
import '../home/home_provider.dart';
import '../mindmap/interest_clusters_provider.dart';

/// State for the Add URL flow.
enum AddUrlStatus {
  idle,
  saving,        // instant save in progress
  done,
  error,
}

class AddUrlState {
  final AddUrlStatus status;
  final String? errorMessage;
  final String url;

  const AddUrlState({
    this.status = AddUrlStatus.idle,
    this.errorMessage,
    this.url = '',
  });

  AddUrlState copyWith({
    AddUrlStatus? status,
    String? errorMessage,
    String? url,
  }) {
    return AddUrlState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      url: url ?? this.url,
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
  Future<bool> saveUrl(String rawUrl, {String? notes}) async {
    if (_isSaving) return false;
    _isSaving = true;

    final isarService = _ref.read(isarServiceProvider);

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

      // Instant save with domain-categorizer fallback
      state = state.copyWith(
        status: AddUrlStatus.saving,
        url: normalizedUrl,
        errorMessage: null,
      );

      final platformCat = DomainCategorizer.categorize(normalizedUrl);
      final domain = _extractDomain(normalizedUrl);

      final savedUrl = SavedUrl()
        ..rawUrl = normalizedUrl
        ..domain = domain
        ..title = domain // placeholder — enrichment will update
        ..description = ''
        ..thumbnailUrl = null // enrichment will update
        ..category = platformCat.category
        ..categoryEmoji = platformCat.emoji
        ..categories = CategoryResolver.buildCategories(
          primaryCategory: platformCat.category,
          platformCategory: platformCat.category,
        )
        ..tags = platformCat.tags
        ..summary = null // enrichment will update
        ..userNotes = notes
        ..savedAt = DateTime.now()
        ..embedding = null; // enrichment will update

      await isarService.saveUrl(savedUrl);

      // Invalidate providers so Home screen shows the new URL instantly
      _ref.invalidate(urlStreamProvider);
      _ref.invalidate(categoriesProvider);
      _ref.invalidate(askEmptySuggestionsProvider);
      _ref.invalidate(interestClusterThemesProvider);

      state = state.copyWith(status: AddUrlStatus.done);
      _isSaving = false;

      // Kick off background enrichment (fire and forget)
      _enrichInBackground(normalizedUrl);

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

  /// Background enrichment: fetch metadata, AI categorize, generate embedding.
  /// Runs after instant save so the user never waits for it.
  void _enrichInBackground(String normalizedUrl) {
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
    _findAndEnrich(normalizedUrl, enricher);
  }

  Future<void> _findAndEnrich(String normalizedUrl, dynamic enricher) async {
    try {
      final isarService = _ref.read(isarServiceProvider);
      final url = await isarService.findByRawUrl(normalizedUrl);
      if (url == null) return;
      // First enrich metadata, then AI + embedding
      await enricher.enrichMetadata(url.id);
      await enricher.enrichSingle(url.id);
    } catch (e) {
      developer.log('Background enrichment failed: $e', name: 'AddUrl');
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

final addUrlProvider =
    StateNotifierProvider<AddUrlNotifier, AddUrlState>((ref) {
  return AddUrlNotifier(ref);
});