import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryOrderNotifier extends StateNotifier<List<String>> {
  static const _prefsKey = 'glimpse_category_order';

  CategoryOrderNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      state = List<String>.from(jsonDecode(raw) as List);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state));
  }

  /// Merges stored order with DB categories: removes stale entries, appends new ones.
  void sync(List<String> dbCategories) {
    final updated = [
      ...state.where(dbCategories.contains),
      ...dbCategories.where((c) => !state.contains(c)),
    ];
    if (updated.toString() != state.toString()) {
      state = updated;
      _persist();
    }
  }

  void reorder(int oldIndex, int newIndex) {
    final list = List<String>.from(state);
    if (newIndex > oldIndex) newIndex--;
    list.insert(newIndex, list.removeAt(oldIndex));
    state = list;
    _persist();
  }

  void remove(String category) {
    state = state.where((c) => c != category).toList();
    _persist();
  }
}

final categoryOrderProvider =
    StateNotifierProvider<CategoryOrderNotifier, List<String>>(
  (_) => CategoryOrderNotifier(),
);
