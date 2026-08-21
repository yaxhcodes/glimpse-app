import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/shell/shell_status_bar_accent.dart';

void main() {
  testWidgets('status accent stays translucent and fades with visibility', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
        home: const MediaQuery(
          data: MediaQueryData(padding: EdgeInsets.only(top: 24)),
          child: Scaffold(body: ShellStatusBarAccent(visible: true)),
        ),
      ),
    );

    final opacity = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('shell-status-bar-accent')),
    );
    expect(opacity.opacity, 1);

    final decoration = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((decoration) => decoration.gradient != null);
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors.first.a, lessThan(1));
    expect(gradient.colors.last.a, 0);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('shell-status-bar-accent-size')),
      ).height,
      24,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: ShellStatusBarAccent(visible: false)),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('shell-status-bar-accent')),
          )
          .opacity,
      0,
    );
  });
}
