import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Typography system
//
// Space Grotesk  → display / app-bar branding (modern tech look)
// Inter          → all UI text — titles, body, metadata, navigation
// Fira Code      → tags and technical labels (structured, database-like)
// ─────────────────────────────────────────────────────────────────────────────

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

  static TextTheme _buildTextTheme() {
    return TextTheme(
      // ── Space Grotesk — Display / Branding ─────────────────────────────
      displayLarge: GoogleFonts.spaceGrotesk(
        fontSize: 57, fontWeight: FontWeight.w700, height: 1.12, letterSpacing: -0.25,
      ),
      displayMedium: GoogleFonts.spaceGrotesk(
        fontSize: 45, fontWeight: FontWeight.w700, height: 1.16, letterSpacing: 0,
      ),
      displaySmall: GoogleFonts.spaceGrotesk(
        fontSize: 36, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: 0,
      ),
      headlineLarge: GoogleFonts.spaceGrotesk(
        fontSize: 32, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: 0.32,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 28, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: 0.28,
      ),
      headlineSmall: GoogleFonts.spaceGrotesk(
        fontSize: 24, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: 0.24,
      ),

      // ── Inter — Titles ──────────────────────────────────────────────────
      titleLarge: GoogleFonts.inter(
        fontSize: 20, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: 0,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 18, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: 0,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: 0,
      ),

      // ── Inter — Body ────────────────────────────────────────────────────
      bodyLarge: GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w400, height: 1.4, letterSpacing: 0,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w400, height: 1.4, letterSpacing: 0,
      ),
      bodySmall: GoogleFonts.inter(
        // metadata: source names, timestamps
        fontSize: 13, fontWeight: FontWeight.w500, height: 1.3, letterSpacing: 0,
      ),

      // ── Inter / Fira Code — Labels ──────────────────────────────────────
      labelLarge: GoogleFonts.inter(
        // buttons, navigation items
        fontSize: 14, fontWeight: FontWeight.w500, height: 1.3, letterSpacing: 0,
      ),
      labelMedium: GoogleFonts.firaCode(
        // tag chips, technical labels
        fontSize: 13, fontWeight: FontWeight.w500, height: 1.3, letterSpacing: 0.26,
      ),
      labelSmall: GoogleFonts.firaCode(
        // small source chips, overlays
        fontSize: 12, fontWeight: FontWeight.w500, height: 1.3, letterSpacing: 0.24,
      ),
    );
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final textTheme = _buildTextTheme();
    // App-bar title uses Space Grotesk Bold for branding feel
    final appBarTitleStyle = GoogleFonts.spaceGrotesk(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: colorScheme.onSurface,
    );
    // Chip labels use Fira Code with onSurface color so text is readable in
    // both light and dark mode. A plain TextStyle (not MaterialStateTextStyle)
    // is required here — Flutter's chip widget reads `.color` directly and
    // does NOT call the MaterialStateTextStyle resolver, so a resolver-based
    // style always resolves to null color and falls back to the washed-out M3
    // default (onSurfaceVariant).
    final chipLabelStyle = GoogleFonts.firaCode(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.24,
      color: colorScheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        titleTextStyle: appBarTitleStyle,
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
        labelStyle: chipLabelStyle,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
