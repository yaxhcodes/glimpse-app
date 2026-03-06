import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

const _kThemeModeKey = 'theme_mode';
const _kAccentColorKey = 'accent_color';

/// Persisted ThemeMode provider.
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_kThemeModeKey);
    if (idx != null && idx < ThemeMode.values.length) {
      state = ThemeMode.values[idx];
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeModeKey, mode.index);
  }
}

/// Persisted accent color provider.
final accentColorProvider =
    StateNotifierProvider<AccentColorNotifier, AppAccentColor>((ref) {
  return AccentColorNotifier();
});

class AccentColorNotifier extends StateNotifier<AppAccentColor> {
  AccentColorNotifier() : super(AppAccentColor.dynamic) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_kAccentColorKey);
    if (idx != null && idx < AppAccentColor.values.length) {
      state = AppAccentColor.values[idx];
    }
  }

  Future<void> set(AppAccentColor color) async {
    state = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAccentColorKey, color.index);
  }
}
