import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SourceOrderNotifier extends StateNotifier<List<String>> {
  SourceOrderNotifier() : super(const []) {
    _load();
  }

  static const _prefsKey = 'glimpse_source_quick_access_order';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_prefsKey) ?? const [];
  }

  Future<void> reorder(List<String> names) async {
    state = [
      for (final name in names)
        if (name.trim().isNotEmpty) name.trim(),
    ];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, state);
  }
}

final sourceOrderProvider =
    StateNotifierProvider<SourceOrderNotifier, List<String>>(
  (ref) => SourceOrderNotifier(),
);
