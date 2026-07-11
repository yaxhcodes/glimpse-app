import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_icons.dart';

/// Mouse / trackpad friendly scrolling (desktop, web) + touch.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Typography system
//
// Instrument Sans → interface, navigation, controls, labels, and metadata
// Newsreader      → opt-in editorial titles via AppTypography
// ─────────────────────────────────────────────────────────────────────────────

/// Predefined accent color palettes inspired by Pixel / Seal.
enum AppAccentColor {
  dynamic('Dynamic', AppIcons.automaticTheme, null), // uses wallpaper
  // Seeds aligned to the Google / Material You palette Pixel renders.
  purple('Purple', Icons.circle, Color(0xFF6750A4)), // M3 default
  blue('Blue', Icons.circle, Color(0xFF0B57D0)), // Google Blue
  teal('Teal', Icons.circle, Color(0xFF006A6A)), // M3 teal
  green('Green', Icons.circle, Color(0xFF146C2E)), // Google Green
  lime('Lime', Icons.circle, Color(0xFF7CB342)),
  yellow('Yellow', Icons.circle, Color(0xFFF9AB00)), // Google Yellow
  orange('Orange', Icons.circle, Color(0xFFE8710A)),
  red('Red', Icons.circle, Color(0xFFD93025)), // Google Red
  pink('Pink', Icons.circle, Color(0xFFB4255E)),
  sakura('Sakura', Icons.circle, Color(0xFFF48FB1)),
  indigo('Indigo', Icons.circle, Color(0xFF3F51B5)),
  slate('Slate', Icons.circle, Color(0xFF5B7083));

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

  /// Dark theme with **true black** and near-black containers (OLED-friendly).
  static ThemeData amoledTheme(Color seedColor) {
    final base = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );
    return _buildTheme(_amoledSurfaces(base));
  }

  /// Build a theme directly from a pre-built [ColorScheme] (for dynamic color).
  static ThemeData fromColorScheme(ColorScheme colorScheme) {
    return _buildTheme(colorScheme);
  }

  /// Dynamic dark colors with AMOLED-style surfaces; keeps accent from [scheme].
  static ThemeData fromColorSchemeAmoled(ColorScheme scheme) {
    return _buildTheme(_amoledSurfaces(scheme));
  }

  /// Replace dark greys with black / near-black; preserves primary, error, etc.
  static ColorScheme _amoledSurfaces(ColorScheme scheme) {
    assert(scheme.brightness == Brightness.dark);
    const black = Color(0xFF000000);
    return scheme.copyWith(
      surface: black,
      surfaceContainerLowest: black,
      surfaceContainerLow: const Color(0xFF0D0D0D),
      surfaceContainer: const Color(0xFF151515),
      surfaceContainerHigh: const Color(0xFF1A1A1A),
      surfaceContainerHighest: const Color(0xFF202020),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      // ── Instrument Sans — Display / Branding
      displayLarge: GoogleFonts.instrumentSans(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        height: 1.12,
        letterSpacing: -0.25,
      ),
      displayMedium: GoogleFonts.instrumentSans(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        height: 1.16,
        letterSpacing: 0,
      ),
      displaySmall: GoogleFonts.instrumentSans(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0,
      ),
      headlineLarge: GoogleFonts.instrumentSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0.32,
      ),
      headlineMedium: GoogleFonts.instrumentSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0.28,
      ),
      headlineSmall: GoogleFonts.instrumentSans(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.24,
      ),

      // ── Instrument Sans — Titles
      titleLarge: GoogleFonts.instrumentSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0,
      ),
      titleMedium: GoogleFonts.instrumentSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0,
      ),
      titleSmall: GoogleFonts.instrumentSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0,
      ),

      // ── Instrument Sans — Body
      bodyLarge: GoogleFonts.instrumentSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.4,
        letterSpacing: 0,
      ),
      bodyMedium: GoogleFonts.instrumentSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        letterSpacing: 0,
      ),
      bodySmall: GoogleFonts.instrumentSans(
        // metadata: source names, timestamps
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0,
      ),

      // ── Instrument Sans — Labels
      labelLarge: GoogleFonts.instrumentSans(
        // buttons, navigation items
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0,
      ),
      labelMedium: GoogleFonts.instrumentSans(
        // tag chips and compact labels
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.26,
      ),
      labelSmall: GoogleFonts.instrumentSans(
        // small source chips, overlays
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.24,
      ),
    );
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final textTheme = _buildTextTheme();
    final appBarTitleStyle = GoogleFonts.instrumentSans(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: colorScheme.onSurface,
    );
    final isDark = colorScheme.brightness == Brightness.dark;
    final statusBarIcons = isDark ? Brightness.light : Brightness.dark;
    final navBarIcons = isDark ? Brightness.light : Brightness.dark;
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final compactControlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    final buttonTextStyle = textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurfaceVariant,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: appBarTitleStyle,
        iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        actionsIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: statusBarIcons,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: colorScheme.surface,
          systemNavigationBarIconBrightness: navBarIcons,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        surfaceTintColor: colorScheme.surfaceTint.withValues(alpha: 0.22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 3,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 2,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        dragHandleColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
        backgroundColor: colorScheme.surfaceContainerHighest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        prefixIconColor: colorScheme.onSurfaceVariant,
        suffixIconColor: colorScheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          shape: WidgetStatePropertyAll(compactControlShape),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: controlShape,
          textStyle: buttonTextStyle,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 1,
          shape: controlShape,
          textStyle: buttonTextStyle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: controlShape,
          textStyle: buttonTextStyle,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: compactControlShape,
          textStyle: buttonTextStyle,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 44)),
          shape: WidgetStatePropertyAll(controlShape),
          textStyle: WidgetStatePropertyAll(buttonTextStyle),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(
          colorScheme.surfaceContainerHigh,
        ),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 18),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colorScheme.surfaceContainer),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(2),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: colorScheme.error,
        textColor: colorScheme.onError,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        // Calm tonal FAB that matches the nav indicator pill, rather than the
        // saturated primaryContainer (which gets loud with a vivid dynamic
        // accent). Keeps every FAB in the app consistent.
        backgroundColor: colorScheme.secondaryContainer,
        foregroundColor: colorScheme.onSecondaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 2,
        highlightElevation: 4,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        elevation: 2,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            // Selected icon sits inside the secondaryContainer indicator pill,
            // so it pairs with onSecondaryContainer — calmer and more readable
            // than the saturated `primary` (which can get loud with a vivid
            // dynamic accent).
            color: selected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.instrumentSans(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            height: 1.3,
            letterSpacing: 0,
            // Neutral selected label (M3 default) — the filled icon + pill carry
            // the selected state, so the label stays calm instead of accent-loud.
            color: selected
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        elevation: 0,
        useIndicator: true,
        indicatorColor: colorScheme.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        selectedIconTheme: IconThemeData(
          size: 24,
          color: colorScheme.onSecondaryContainer,
        ),
        unselectedIconTheme: IconThemeData(
          size: 24,
          color: colorScheme.onSurfaceVariant,
        ),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
      // Android 16 enables predictive-back animations by default for apps
      // targeting API 36. PredictiveBackPageTransitionsBuilder renders the OS-driven
      // back gesture preview on Android 14+ (and falls back to a zoom transition
      // on older releases or non-gesture navigation). Safe here because every
      // back-intercepting screen uses PopScope (not the deprecated
      // WillPopScope), and the manifest opts in via enableOnBackInvokedCallback.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
