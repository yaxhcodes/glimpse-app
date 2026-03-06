import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/link_preview_service.dart';
import '../../core/services/domain_categorizer.dart';

/// State for the Add URL flow.
enum AddUrlStatus { idle, fetchingMetadata, categorizing, saving, done, error }

class AddUrlState {
  final AddUrlStatus status;
  final String? errorMessage;
  final String url;
  final LinkMetadata? metadata;

  const AddUrlState({
    this.status = AddUrlStatus.idle,
    this.errorMessage,
    this.url = '',
    this.metadata,
  });

  AddUrlState copyWith({
    AddUrlStatus? status,
    String? errorMessage,
    String? url,
    LinkMetadata? metadata,
  }) {
    return AddUrlState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      url: url ?? this.url,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Provider that orchestrates: fetch metadata → categorize by domain → save.
class AddUrlNotifier extends StateNotifier<AddUrlState> {
  final Ref _ref;
  bool _isSaving = false;

  AddUrlNotifier(this._ref) : super(const AddUrlState());

  Future<bool> saveUrl(String rawUrl, {String? notes}) async {
    // Prevent duplicate saves (auto-save + manual button press)
    if (_isSaving) return false;
    _isSaving = true;

    final linkService = _ref.read(linkPreviewServiceProvider);
    final isarService = _ref.read(isarServiceProvider);

    // Normalize URL (ensure https:// prefix)
    final normalizedUrl = LinkPreviewService.normalizeUrl(rawUrl);

    try {
      // Validate URL
      if (!LinkPreviewService.isValidUrl(normalizedUrl)) {
        _isSaving = false;
        state = state.copyWith(
          status: AddUrlStatus.error,
          errorMessage: 'Please enter a valid URL',
        );
        return false;
      }

      // Check for duplicates
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
      );
      final metadata = await linkService.fetchMetadata(normalizedUrl);

      // Step 2: Categorize by domain (no AI needed)
      state = state.copyWith(
        status: AddUrlStatus.categorizing,
        metadata: metadata,
      );
      final categorization = DomainCategorizer.categorize(normalizedUrl);

      // Step 3: Save to DB
      state = state.copyWith(status: AddUrlStatus.saving);
      // Enrich tags with author/creator/site info for better search
      final enrichedTags = [...categorization.tags];
      if (metadata.author != null && metadata.author!.isNotEmpty) {
        enrichedTags.add(metadata.author!);
      }
      if (metadata.siteName != null && metadata.siteName!.isNotEmpty) {
        // Don't add if it's the same as category
        if (metadata.siteName!.toLowerCase() !=
            categorization.category.toLowerCase()) {
          enrichedTags.add(metadata.siteName!);
        }
      }

      final savedUrl = SavedUrl()
        ..rawUrl = normalizedUrl
        ..domain = metadata.domain
        ..title = metadata.title
        ..description = metadata.description
        ..thumbnailUrl = metadata.imageUrl
        ..category = categorization.category
        ..categoryEmoji = categorization.emoji
        ..tags = enrichedTags
        ..userNotes = notes
        ..savedAt = DateTime.now()
        ..embedding = [];

      await isarService.saveUrl(savedUrl);

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
