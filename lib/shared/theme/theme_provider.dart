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
  /// Pass [initial] (from [ThemePrefsSnapshot]) to start with the saved value
  /// instead of loading it after the first frame.
  ThemeModeNotifier({ThemeMode? initial})
    : super(initial ?? ThemeMode.system) {
    if (initial == null) _load();
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
  AmoledSurfacesNotifier({bool? initial}) : super(initial ?? false) {
    if (initial == null) _load();
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
  AccentColorNotifier({AppAccentColor? initial})
    : super(initial ?? AppAccentColor.glimpse) {
    if (initial == null) _load();
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

/// Saved appearance, read once before `runApp`.
///
/// Without this the theme providers start at their defaults and switch to the
/// saved choice a frame later, which [AppTheme.transitionStyle] animates as a
/// visible accent/brightness flash on every cold start.
class ThemePrefsSnapshot {
  const ThemePrefsSnapshot({
    required this.themeMode,
    required this.amoledSurfaces,
    required this.accent,
  });

  final ThemeMode themeMode;
  final bool amoledSurfaces;
  final AppAccentColor accent;

  static const fallback = ThemePrefsSnapshot(
    themeMode: ThemeMode.system,
    amoledSurfaces: false,
    accent: AppAccentColor.glimpse,
  );

  /// Never throws: a prefs failure must not block the first frame.
  static Future<ThemePrefsSnapshot> load() async {
    try {
      return await _read();
    } catch (_) {
      return fallback;
    }
  }

  static Future<ThemePrefsSnapshot> _read() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyAppearancePrefs(prefs);
    final modeIndex = prefs.getInt(_kThemeModeKey);
    final accentIndex = prefs.getInt(_kAccentColorKey);
    return ThemePrefsSnapshot(
      themeMode: modeIndex != null && modeIndex < ThemeMode.values.length
          ? ThemeMode.values[modeIndex]
          : ThemeMode.system,
      amoledSurfaces: prefs.getInt(_kAmoledSurfacesKey) == 1,
      accent: accentIndex != null && accentIndex < AppAccentColor.values.length
          ? AppAccentColor.values[accentIndex]
          : AppAccentColor.glimpse,
    );
  }

  /// Provider overrides that seed the theme notifiers with this snapshot.
  List<Override> get overrides => [
    themeModeProvider.overrideWith(
      (ref) => ThemeModeNotifier(initial: themeMode),
    ),
    amoledSurfacesProvider.overrideWith(
      (ref) => AmoledSurfacesNotifier(initial: amoledSurfaces),
    ),
    accentColorProvider.overrideWith(
      (ref) => AccentColorNotifier(initial: accent),
    ),
  ];
}
