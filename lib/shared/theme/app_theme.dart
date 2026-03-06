import 'package:flutter/material.dart';

/// Predefined accent color palettes inspired by Pixel / Seal.
enum AppAccentColor {
  dynamic('Dynamic', Icons.auto_awesome, null), // uses wallpaper
  purple('Purple', Icons.circle, Color(0xFF6750A4)),
  blue('Blue', Icons.circle, Color(0xFF1565C0)),
  teal('Teal', Icons.circle, Color(0xFF00796B)),
  green('Green', Icons.circle, Color(0xFF2E7D32)),
  lime('Lime', Icons.circle, Color(0xFF9E9D24)),
  yellow('Yellow', Icons.circle, Color(0xFFF9A825)),
  orange('Orange', Icons.circle, Color(0xFFEF6C00)),
  red('Red', Icons.circle, Color(0xFFC62828)),
  pink('Pink', Icons.circle, Color(0xFFAD1457)),
  sakura('Sakura', Icons.circle, Color(0xFFF48FB1)),
  indigo('Indigo', Icons.circle, Color(0xFF283593)),
  slate('Slate', Icons.circle, Color(0xFF546E7A));

  final String label;
  final IconData icon;
  final Color? seedColor;
  const AppAccentColor(this.label, this.icon, this.seedColor);
}

class AppTheme {
  AppTheme._();

  /// Build a light theme from a [seedColor].
  static ThemeData lightTheme(Color seedColor) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    return _buildTheme(colorScheme);
  }

  /// Build a dark theme from a [seedColor].
  static ThemeData darkTheme(Color seedColor) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );
    return _buildTheme(colorScheme);
  }

  /// Build a theme directly from a pre-built [ColorScheme] (for dynamic color).
  static ThemeData fromColorScheme(ColorScheme colorScheme) {
    return _buildTheme(colorScheme);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
