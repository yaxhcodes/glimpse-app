import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

const _kThemeModeKey = 'theme_mode';
const _kAmoledSurfacesKey = 'amoled_surfaces';
const _kLegacyAppearanceKey = 'app_appearance';
const _kAccentColorKey = 'accent_color';

/// One-time migration from unified `app_appearance` (4-way) to theme + AMOLED toggle.
Future<void> _migrateLegacyAppearancePrefs(SharedPreferences prefs) async {
  final legacy = prefs.getInt(_kLegacyAppearanceKey);
  if (legacy == null) return;

  if (legacy == 3) {
    await prefs.setInt(_kThemeModeKey, ThemeMode.dark.index);
    await prefs.setInt(_kAmoledSurfacesKey, 1);
  } else if (legacy >= 0 && legacy < ThemeMode.values.length) {
    await prefs.setInt(_kThemeModeKey, legacy);
    await prefs.setInt(_kAmoledSurfacesKey, 0);
  }
  await prefs.remove(_kLegacyAppearanceKey);
}

/// Persisted light / dark / system.
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
    await _migrateLegacyAppearancePrefs(prefs);
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

/// True black / near-black surfaces for dark theme (OLED). Independent of [themeMode].
final amoledSurfacesProvider =
    StateNotifierProvider<AmoledSurfacesNotifier, bool>((ref) {
  return AmoledSurfacesNotifier();
});

class AmoledSurfacesNotifier extends StateNotifier<bool> {
  AmoledSurfacesNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyAppearancePrefs(prefs);
    final v = prefs.getInt(_kAmoledSurfacesKey);
    if (v == 1) {
      state = true;
    } else if (v == 0) {
      state = false;
    }
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAmoledSurfacesKey, value ? 1 : 0);
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
