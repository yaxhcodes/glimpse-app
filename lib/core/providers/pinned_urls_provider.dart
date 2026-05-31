import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int maxPinnedUrls = 5;
const _kPinnedUrlIdsKey = 'glimpse_pinned_url_ids';

final pinnedUrlsProvider =
    StateNotifierProvider<PinnedUrlsNotifier, List<int>>((ref) {
  return PinnedUrlsNotifier();
});

class PinnedUrlsNotifier extends StateNotifier<List<int>> {
  PinnedUrlsNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kPinnedUrlIdsKey) ?? const [];
    final ids = <int>[];
    for (final item in raw) {
      final id = int.tryParse(item);
      if (id != null && !ids.contains(id)) ids.add(id);
    }
    if (mounted) state = ids.take(maxPinnedUrls).toList();
  }

  bool isPinned(int id) => state.contains(id);

  bool get isAtLimit => state.length >= maxPinnedUrls;

  Future<bool> pin(int id) async {
    if (state.contains(id)) return true;
    if (state.length >= maxPinnedUrls) return false;
    state = [id, ...state];
    await _persist();
    return true;
  }

  Future<void> unpin(int id) async {
    if (!state.contains(id)) return;
    state = state.where((item) => item != id).toList();
    await _persist();
  }

  Future<bool> toggle(int id) async {
    if (state.contains(id)) {
      await unpin(id);
      return true;
    }
    return pin(id);
  }

  Future<void> pruneToExisting(Set<int> existingIds) async {
    final cleaned = state.where(existingIds.contains).toList();
    if (cleaned.length == state.length) return;
    state = cleaned;
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kPinnedUrlIdsKey,
      state.map((id) => id.toString()).toList(),
    );
  }
}
