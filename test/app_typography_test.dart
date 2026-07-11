import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/shared/theme/app_theme.dart';
import 'package:glimpse/shared/theme/app_typography.dart';

void main() {
  test('all app theme variants use Instrument Sans for interface text', () {
    final seed = Colors.indigo;
    final dynamicLight = ColorScheme.fromSeed(seedColor: seed);
    final dynamicDark = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    final themes = <ThemeData>[
      AppTheme.lightTheme(seed),
      AppTheme.darkTheme(seed),
      AppTheme.amoledTheme(seed),
      AppTheme.fromColorScheme(dynamicLight),
      AppTheme.fromColorSchemeAmoled(dynamicDark),
    ];

    for (final theme in themes) {
      final styles = <TextStyle?>[
        theme.textTheme.displayLarge,
        theme.textTheme.headlineMedium,
        theme.textTheme.titleLarge,
        theme.textTheme.bodyMedium,
        theme.textTheme.labelSmall,
        theme.appBarTheme.titleTextStyle,
        theme.navigationBarTheme.labelTextStyle?.resolve(const <WidgetState>{
          WidgetState.selected,
        }),
        theme.navigationBarTheme.labelTextStyle?.resolve(const <WidgetState>{}),
      ];

      for (final style in styles) {
        expect(style?.fontFamily, startsWith('InstrumentSans'));
      }
    }
  });

  test('editorial helper uses Newsreader and preserves explicit metrics', () {
    const color = Color(0xFF123456);
    final style = AppTypography.editorial(
      const TextStyle(fontSize: 18),
      color: color,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.12,
      letterSpacing: 0,
    );

    expect(style.fontFamily, startsWith('Newsreader'));
    expect(style.color, color);
    expect(style.fontSize, 22);
    expect(style.fontWeight, FontWeight.w700);
    expect(style.height, 1.12);
    expect(style.letterSpacing, 0);
  });
}
