import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/saved_url.dart';
import '../../core/models/url_processing_status.dart';
import '../../core/providers/service_providers.dart';

/// Provider for a single URL detail by ID.
///
/// `autoDispose` so the detail screen re-reads from disk every time it's
/// reopened. Without it the family cache holds a stale [SavedUrl] instance —
/// note edits are written to Isar but the cached object keeps the old
/// `userNotes`, so reopening the page shows the note as "gone" until restart.
final urlDetailProvider = FutureProvider.autoDispose.family<SavedUrl?, int>((
  ref,
  id,
) async {
  final isarService = ref.watch(isarServiceProvider);
  return isarService.getUrlById(id);
});

/// Notifier for delete / update actions on a URL.
class UrlDetailNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  UrlDetailNotifier(this._ref) : super(const AsyncData(null));

  Future<bool> deleteUrl(int id) async {
    state = const AsyncLoading();
    try {
      final isarService = _ref.read(isarServiceProvider);
      await isarService.deleteUrl(id);
      state = const AsyncData(null);
      return true;
    } catch (e, stack) {
      state = AsyncError(e, stack);
      return false;
    }
  }

  Future<bool> updateNotes(int id, String notes) async {
    state = const AsyncLoading();
    try {
      final updated = await _ref
          .read(savedNotesServiceProvider)
          .updatePersonalNote(id, notes);
      if (!updated) {
        state = AsyncError('URL not found', StackTrace.current);
        return false;
      }
      state = const AsyncData(null);
      return true;
    } catch (e, stack) {
      state = AsyncError(e, stack);
      return false;
    }
  }

  Future<bool> deleteAskNote(int urlId, String noteId) async {
    state = const AsyncLoading();
    try {
      final updated = await _ref
          .read(savedNotesServiceProvider)
          .deleteAskNote(urlId, noteId);
      if (!updated) {
        state = AsyncError('URL not found', StackTrace.current);
        return false;
      }
      state = const AsyncData(null);
      _ref.invalidate(urlDetailProvider(urlId));
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }

  Future<bool> retryEnrichment(int id) async {
    state = const AsyncLoading();
    try {
      final isarService = _ref.read(isarServiceProvider);
      final url = await isarService.getUrlById(id);
      if (url == null) {
        state = AsyncError('URL not found', StackTrace.current);
        return false;
      }

      final hasSavedAiPayload =
          (url.enrichmentJson ?? '').trim().isNotEmpty ||
          (url.summary ?? '').trim().isNotEmpty;
      url
        ..processingStatus = UrlProcessingStatus.queued
        ..processingError = null
        ..processingUpdatedAt = DateTime.now();
      await isarService.updateUrl(url);

      final enricher = _ref.read(enrichmentServiceProvider)();
      final failedTasks = <String>[];
      final metadataCompleted = await enricher.enrichMetadata(id);
      if (!metadataCompleted) {
        failedTasks.add('metadata_failed');
      }
      await enricher.enrichSingle(
        id,
        forceAi: true,
        forceEmbedding: true,
        countAiUsage: !hasSavedAiPayload,
        initialFailures: failedTasks,
      );
      state = const AsyncData(null);
      return true;
    } catch (e, stack) {
      state = AsyncError(e, stack);
      return false;
    }
  }

  Future<bool> refreshContentIfLikelyTruncated(int id) async {
    try {
      final isarService = _ref.read(isarServiceProvider);
      final url = await isarService.getUrlById(id);
      if (url == null) return false;
      if (!_isSupportedLongPostSource(url.rawUrl)) return false;

      final linkService = _ref.read(linkPreviewServiceProvider);
      final fresh = await linkService.fetchMetadata(url.rawUrl);
      final freshDescription = fresh.description.trim();
      final isYouTube = _isYouTubeSource(url.rawUrl);
      final needsAiRefresh = isYouTube && _needsAiRefresh(url);
      if (freshDescription.isEmpty && !needsAiRefresh) return false;

      final hasMeaningfulIncrease =
          freshDescription.length >= url.description.trim().length + 20;
      if (!hasMeaningfulIncrease && !needsAiRefresh) return false;

      if (hasMeaningfulIncrease) {
        url.description = freshDescription;
        await isarService.updateUrl(url);
      }
      if (isYouTube) {
        final enricher = _ref.read(enrichmentServiceProvider)();
        await enricher.enrichSingle(
          id,
          forceAi: true,
          forceEmbedding: true,
          countAiUsage: false,
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isSupportedLongPostSource(String rawUrl) {
    final host = Uri.tryParse(rawUrl)?.host.toLowerCase() ?? '';
    return host.contains('x.com') ||
        host.contains('twitter.com') ||
        host.contains('reddit.com') ||
        host == 'redd.it' ||
        _isYouTubeSource(rawUrl);
  }

  bool _isYouTubeSource(String rawUrl) {
    final host = Uri.tryParse(rawUrl)?.host.toLowerCase() ?? '';
    return host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtu.be';
  }

  bool _needsAiRefresh(SavedUrl url) {
    final hasSummary = url.summary?.trim().isNotEmpty ?? false;
    if (!hasSummary) return true;

    final meaningfulTags = url.tags
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty && tag != 'youtube' && tag != 'video')
        .toList();
    return meaningfulTags.isEmpty;
  }
}

final urlDetailNotifierProvider =
    StateNotifierProvider<UrlDetailNotifier, AsyncValue<void>>((ref) {
      return UrlDetailNotifier(ref);
    });
