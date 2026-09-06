import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/shared/widgets/expressive_tap_scale.dart';

void main() {
  Widget surface({
    bool enabled = true,
    bool reduceMotion = false,
    VoidCallback? onTap,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: Center(
          child: ExpressiveTapScale(
            enabled: enabled,
            child: SizedBox(
              width: 180,
              height: 100,
              child: InkWell(onTap: onTap),
            ),
          ),
        ),
      ),
    ),
  );

  double scale(WidgetTester tester) => tester
      .widget<Transform>(
        find
            .descendant(
              of: find.byType(ExpressiveTapScale),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform
      .entry(0, 0);

  testWidgets('press responds quickly and release preserves the tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(surface(onTap: () => taps++));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(InkWell)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 85));
    expect(scale(tester), closeTo(.98, .001));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(scale(tester), closeTo(1, .001));
  });

  testWidgets('scroll movement cancels compression and does not tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(surface(onTap: () => taps++));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(InkWell)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 85));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(scale(tester), 1);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 0);
  });

  testWidgets('another pointer cannot release the active press', (
    tester,
  ) async {
    await tester.pumpWidget(surface());
    final point = tester.getCenter(find.byType(InkWell));
    final first = await tester.startGesture(point, pointer: 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 85));
    final second = await tester.startGesture(point, pointer: 2);
    await second.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(scale(tester), closeTo(.98, .001));
    await first.cancel();
    await tester.pumpAndSettle();
    expect(scale(tester), 1);
  });

  testWidgets('disabling during a press resets the surface', (tester) async {
    await tester.pumpWidget(surface());
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(InkWell)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 85));
    await tester.pumpWidget(surface(enabled: false));
    await gesture.up();
    await tester.pumpWidget(surface());
    expect(scale(tester), 1);
  });

  testWidgets('reduced motion leaves taps functional without scale animation', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(surface(reduceMotion: true, onTap: () => taps++));
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(
      find.descendant(
        of: find.byType(ExpressiveTapScale),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
  });
}
