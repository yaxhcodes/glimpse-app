import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_icons.dart';
import 'app_motion.dart';
import 'app_shapes.dart';

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
  purple('Purple', AppIcons.circleFilled, Color(0xFF6750A4)), // M3 default
  blue('Blue', AppIcons.circleFilled, Color(0xFF0B57D0)), // Google Blue
  teal('Teal', AppIcons.circleFilled, Color(0xFF006A6A)), // M3 teal
  green('Green', AppIcons.circleFilled, Color(0xFF146C2E)), // Google Green
  lime('Lime', AppIcons.circleFilled, Color(0xFF7CB342)),
  yellow('Yellow', AppIcons.circleFilled, Color(0xFFF9AB00)), // Google Yellow
  orange('Orange', AppIcons.circleFilled, Color(0xFFE8710A)),
  red('Red', AppIcons.circleFilled, Color(0xFFD93025)), // Google Red
  pink('Pink', AppIcons.circleFilled, Color(0xFFB4255E)),
  sakura('Sakura', AppIcons.circleFilled, Color(0xFFE68A95)),
  indigo('Indigo', AppIcons.circleFilled, Color(0xFF3F51B5)),
  slate('Slate', AppIcons.circleFilled, Color(0xFF5B7083)),
  monochrome(
    'Monochrome',
    AppIcons.circleFilled,
    Color(0xFF5F6368),
    schemeVariant: DynamicSchemeVariant.monochrome,
  ),

  /// The house palette: the sage, cream and terracotta of the onboarding art.
  /// Declared last so persisted accent indexes stay stable; shown first in
  /// the picker and used as the default. Built by [AppTheme.brandScheme]
  /// rather than `fromSeed`.
  glimpse('Glimpse', AppIcons.circleFilled, Color(0xFF5E6E52));

  final String label;
  final IconData icon;
  final Color? seedColor;
  final DynamicSchemeVariant schemeVariant;

  const AppAccentColor(
    this.label,
    this.icon,
    this.seedColor, {
    this.schemeVariant = DynamicSchemeVariant.tonalSpot,
  });
}

class AppTheme {
  AppTheme._();

  /// A calm, shared transition for brightness and accent changes.
  ///
  /// Keeping this at the app boundary lets Flutter interpolate the complete
  /// [ThemeData] consistently instead of individual screens changing at
  /// slightly different speeds.
  static const transitionStyle = AnimationStyle(
    duration: AppMotion.long,
    curve: AppMotion.emphasized,
  );

  /// Build a light theme from a [seedColor].
  static ThemeData lightTheme(
    Color seedColor, {
    DynamicSchemeVariant schemeVariant = DynamicSchemeVariant.tonalSpot,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
      dynamicSchemeVariant: schemeVariant,
    );
    return _buildTheme(colorScheme);
  }

  /// Build a dark theme from a [seedColor].
  static ThemeData darkTheme(
    Color seedColor, {
    DynamicSchemeVariant schemeVariant = DynamicSchemeVariant.tonalSpot,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      dynamicSchemeVariant: schemeVariant,
    );
    return _buildTheme(colorScheme);
  }

  /// Dark theme with **true black** and near-black containers (OLED-friendly).
  static ThemeData amoledTheme(
    Color seedColor, {
    DynamicSchemeVariant schemeVariant = DynamicSchemeVariant.tonalSpot,
  }) {
    final base = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      dynamicSchemeVariant: schemeVariant,
    );
    return _buildTheme(_amoledSurfaces(base));
  }

  /// Hand-tuned house scheme ([AppAccentColor.glimpse]).
  ///
  /// Tonal seeds give every accent the same grey-green surfaces; this one
  /// carries the onboarding world into the app: warm paper in light mode,
  /// deep forest ink in dark mode, sage primary, terracotta tertiary for
  /// moments of delight, and more separation between surface and cards.
  static ColorScheme brandScheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: AppAccentColor.glimpse.seedColor!,
      brightness: brightness,
    );
    final primary = dark ? const Color(0xFFBFCCAE) : const Color(0xFF46553E);
    return base.copyWith(
      primary: primary,
      onPrimary: dark ? const Color(0xFF223019) : const Color(0xFFFAF7EE),
      primaryContainer: dark
          ? const Color(0xFF35412E)
          : const Color(0xFFDCE4CC),
      onPrimaryContainer: dark
          ? const Color(0xFFDCE6CB)
          : const Color(0xFF18220F),
      secondary: dark ? const Color(0xFFBFC6B2) : const Color(0xFF5A6350),
      onSecondary: dark ? const Color(0xFF2A3122) : const Color(0xFFFFFFFF),
      secondaryContainer: dark
          ? const Color(0xFF363D30)
          : const Color(0xFFE2E5D5),
      onSecondaryContainer: dark
          ? const Color(0xFFDDE4D0)
          : const Color(0xFF262D1F),
      tertiary: dark ? const Color(0xFFEDB797) : const Color(0xFF9C5436),
      onTertiary: dark ? const Color(0xFF4A2310) : const Color(0xFFFFFFFF),
      tertiaryContainer: dark
          ? const Color(0xFF693A22)
          : const Color(0xFFF7DCCB),
      onTertiaryContainer: dark
          ? const Color(0xFFFFDBC9)
          : const Color(0xFF391708),
      surface: dark ? const Color(0xFF151914) : const Color(0xFFF6F3EA),
      onSurface: dark ? const Color(0xFFECEBDF) : const Color(0xFF22281E),
      onSurfaceVariant: dark
          ? const Color(0xFFB8BCAD)
          : const Color(0xFF585E51),
      surfaceContainerLowest: dark
          ? const Color(0xFF10130F)
          : const Color(0xFFFFFDF8),
      surfaceContainerLow: dark
          ? const Color(0xFF1E231C)
          : const Color(0xFFEFEBE0),
      surfaceContainer: dark
          ? const Color(0xFF242A22)
          : const Color(0xFFE9E6DA),
      surfaceContainerHigh: dark
          ? const Color(0xFF2B3228)
          : const Color(0xFFE3E1D4),
      surfaceContainerHighest: dark
          ? const Color(0xFF333A2F)
          : const Color(0xFFDDDBCD),
      surfaceBright: dark ? const Color(0xFF383F34) : const Color(0xFFF6F3EA),
      surfaceDim: dark ? const Color(0xFF151914) : const Color(0xFFDDDACD),
      outline: dark ? const Color(0xFF8B9181) : const Color(0xFF74796B),
      outlineVariant: dark
          ? const Color(0xFF3D4538)
          : const Color(0xFFD3D3C4),
      inverseSurface: dark ? const Color(0xFFE3E3D7) : const Color(0xFF2F352B),
      onInverseSurface: dark
          ? const Color(0xFF2F352B)
          : const Color(0xFFF1EFE4),
      inversePrimary: dark ? const Color(0xFF46553E) : const Color(0xFFBFCCAE),
      surfaceTint: primary,
    );
  }

  /// Theme for [AppAccentColor.glimpse].
  static ThemeData brandTheme(Brightness brightness, {bool amoled = false}) {
    final scheme = brandScheme(brightness);
    return _buildTheme(
      amoled && brightness == Brightness.dark
          ? _amoledSurfaces(scheme)
          : scheme,
    );
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
        height: 1.08,
        letterSpacing: -1.4,
      ),
      displayMedium: GoogleFonts.instrumentSans(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -1.0,
      ),
      displaySmall: GoogleFonts.instrumentSans(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.14,
        letterSpacing: -0.7,
      ),
      headlineLarge: GoogleFonts.instrumentSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.16,
        letterSpacing: -0.6,
      ),
      headlineMedium: GoogleFonts.instrumentSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.18,
        letterSpacing: -0.45,
      ),
      headlineSmall: GoogleFonts.instrumentSans(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.3,
      ),

      // ── Instrument Sans — Titles
      titleLarge: GoogleFonts.instrumentSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.15,
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
      letterSpacing: -0.2,
      color: colorScheme.onSurface,
    );
    final isDark = colorScheme.brightness == Brightness.dark;
    final statusBarIcons = isDark ? Brightness.light : Brightness.dark;
    final navBarIcons = isDark ? Brightness.light : Brightness.dark;
    const controlShape = AppShapes.rounded;
    const compactControlShape = AppShapes.rounded;
    final buttonTextStyle = textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return ThemeData(
      useMaterial3: true,
      chipTheme: const ChipThemeData(shape: AppShapes.rounded),
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const AppIcon(AppIcons.arrowBack),
        closeButtonIconBuilder: (_) => const AppIcon(AppIcons.close),
        drawerButtonIconBuilder: (_) => const AppIcon(AppIcons.menu),
        endDrawerButtonIconBuilder: (_) => const AppIcon(AppIcons.menu),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface.withValues(
          alpha: isDark ? 0.88 : 0.92,
        ),
        foregroundColor: colorScheme.onSurfaceVariant,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
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
        height: 72,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
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
