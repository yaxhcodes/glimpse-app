import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTypography {
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
