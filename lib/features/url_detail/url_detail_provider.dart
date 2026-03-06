import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';

/// Provider for a single URL detail by ID.
final urlDetailProvider =
    FutureProvider.family<SavedUrl?, int>((ref, id) async {
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
      final isarService = _ref.read(isarServiceProvider);
      final url = await isarService.getUrlById(id);
      if (url == null) {
        state = AsyncError('URL not found', StackTrace.current);
        return false;
      }
      url.userNotes = notes;
      await isarService.updateUrl(url);
      state = const AsyncData(null);
      return true;
    } catch (e, stack) {
      state = AsyncError(e, stack);
      return false;
    }
  }
}

final urlDetailNotifierProvider =
    StateNotifierProvider<UrlDetailNotifier, AsyncValue<void>>((ref) {
  return UrlDetailNotifier(ref);
});
