import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/shared/theme/app_motion.dart';
import 'package:glimpse/shared/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('monochrome is appended without shifting persisted accent indexes', () {
    expect(
      AppAccentColor.values
          .take(AppAccentColor.monochrome.index)
          .map((accent) => accent.name),
      [
        'dynamic',
        'purple',
        'blue',
        'teal',
        'green',
        'lime',
        'yellow',
        'orange',
        'red',
        'pink',
        'sakura',
        'indigo',
        'slate',
      ],
    );
  });

  test('theme changes use the shared expressive transition', () {
    expect(AppTheme.transitionStyle.duration, AppMotion.long);
    expect(AppTheme.transitionStyle.curve, AppMotion.emphasized);
  });

  testWidgets('accent changes interpolate instead of switching abruptly', (
    tester,
  ) async {
    final seed = ValueNotifier<Color>(Colors.purple);
    addTearDown(seed.dispose);
    Color? renderedPrimary;

    await tester.pumpWidget(
      ValueListenableBuilder<Color>(
        valueListenable: seed,
        builder: (context, value, child) {
          return MaterialApp(
            theme: AppTheme.lightTheme(value),
            themeAnimationStyle: AppTheme.transitionStyle,
            home: Builder(
              builder: (context) {
                renderedPrimary = Theme.of(context).colorScheme.primary;
                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );

    final startingPrimary = renderedPrimary;
    final targetPrimary = AppTheme.lightTheme(Colors.blue).colorScheme.primary;
    seed.value = Colors.blue;
    await tester.pump();
    await tester.pump(AppMotion.long * 0.5);

    expect(renderedPrimary, isNot(startingPrimary));
    expect(renderedPrimary, isNot(targetPrimary));

    await tester.pumpAndSettle();
    expect(renderedPrimary, targetPrimary);
  });

  test('pink and sakura generate visibly distinct Material palettes', () {
    final pink = AppTheme.lightTheme(
      AppAccentColor.pink.seedColor!,
    ).colorScheme;
    final sakura = AppTheme.lightTheme(
      AppAccentColor.sakura.seedColor!,
    ).colorScheme;

    expect(sakura.primary, isNot(pink.primary));
    expect(sakura.primaryContainer, isNot(pink.primaryContainer));
    expect(sakura.tertiary, isNot(pink.tertiary));
  });

  test('monochrome removes chroma from the core accent roles', () {
    final accent = AppAccentColor.monochrome;

    for (final brightness in Brightness.values) {
      final theme = brightness == Brightness.light
          ? AppTheme.lightTheme(
              accent.seedColor!,
              schemeVariant: accent.schemeVariant,
            )
          : AppTheme.darkTheme(
              accent.seedColor!,
              schemeVariant: accent.schemeVariant,
            );
      final scheme = theme.colorScheme;

      expect(_isNeutral(scheme.primary), isTrue);
      expect(_isNeutral(scheme.secondary), isTrue);
      expect(_isNeutral(scheme.tertiary), isTrue);
      expect(_isNeutral(scheme.primaryContainer), isTrue);
    }
  });
}

bool _isNeutral(Color color) {
  final argb = color.toARGB32();
  final red = (argb >> 16) & 0xff;
  final green = (argb >> 8) & 0xff;
  final blue = argb & 0xff;
  return red == green && green == blue;
}
