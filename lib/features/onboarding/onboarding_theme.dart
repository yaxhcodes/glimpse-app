import 'package:flutter/material.dart';

/// An art-directed palette that follows brightness, independent of app accents.
abstract final class OnboardingTheme {
  static ThemeData from(ThemeData appTheme) {
    final dark = appTheme.brightness == Brightness.dark;
    final colors =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF78836B),
          brightness: appTheme.brightness,
        ).copyWith(
          primary: dark ? const Color(0xFFC0CBB0) : const Color(0xFF46553E),
          onPrimary: dark ? const Color(0xFF242D20) : const Color(0xFFF9F6ED),
          surface: dark ? const Color(0xFF1C211C) : const Color(0xFFF6F3EA),
          onSurface: dark ? const Color(0xFFECEBDF) : const Color(0xFF292F26),
          onSurfaceVariant: dark
              ? const Color(0xFFB6BAAC)
              : const Color(0xFF656B5F),
          surfaceContainerLow: dark
              ? const Color(0xFF242A23)
              : const Color(0xFFEEEEE3),
          surfaceContainer: dark
              ? const Color(0xFF2A3128)
              : const Color(0xFFE8EADD),
          surfaceContainerHigh: dark
              ? const Color(0xFF30372D)
              : const Color(0xFFE2E5D7),
          surfaceContainerHighest: dark
              ? const Color(0xFF363E32)
              : const Color(0xFFDCDFD0),
          outlineVariant: dark
              ? const Color(0xFF414A3C)
              : const Color(0xFFD5D8C9),
        );
    return appTheme.copyWith(
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: .7,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.primary),
      ),
      chipTheme: appTheme.chipTheme.copyWith(
        backgroundColor: colors.surface,
        selectedColor: colors.surfaceContainerHighest,
        side: BorderSide.none,
        labelStyle: appTheme.textTheme.labelLarge?.copyWith(
          color: colors.onSurface,
        ),
        checkmarkColor: colors.primary,
      ),
    );
  }
}
