import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTypography {
  /// Top-level tab titles (Home, Collections, Interests): the editorial serif
  /// from onboarding, so every tab opens with the same voice.
  static TextStyle pageTitle(ThemeData theme) => editorial(
    theme.textTheme.headlineSmall,
    color: theme.colorScheme.onSurface,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.05,
    letterSpacing: -0.5,
  );

  static TextStyle editorial(
    TextStyle? base, {
    Color? color,
    double? fontSize,
    FontWeight fontWeight = FontWeight.w600,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.newsreader(
      textStyle: base,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}
