import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/shared/theme/app_theme.dart';
import 'package:glimpse/shared/widgets/app_glass_surface.dart';

void main() {
  testWidgets('glass surface clips and blurs content behind it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(const Color(0xFF6750A4)),
        home: const Scaffold(
          body: AppGlassSurface(child: SizedBox(height: 80)),
        ),
      ),
    );

    expect(find.byType(ClipRect), findsWidgets);
    final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    expect(filter.filter, isA<ImageFilter>());

    final glassDecoration = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((decoration) => decoration.color != null);
    expect(glassDecoration.color, isNotNull);
    expect(glassDecoration.color!.a, lessThan(1));
    expect(glassDecoration.border, isNull);
  });

  testWidgets('high contrast makes glass nearly opaque', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme(const Color(0xFF6750A4)),
        home: const MediaQuery(
          data: MediaQueryData(highContrast: true),
          child: AppGlassSurface(opacity: 0.5),
        ),
      ),
    );

    final glassDecoration = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((decoration) => decoration.color != null);
    expect(glassDecoration.color!.a, closeTo(0.96, 0.001));
  });
}
