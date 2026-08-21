import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/shell/shell_bottom_navigation_transition.dart';

void main() {
  testWidgets('hide transition keeps its layout extent stable', (tester) async {
    Future<void> pumpTransition({required bool visible}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: 320,
                height: 96,
                child: ShellBottomNavigationTransition(
                  visible: visible,
                  child: const ColoredBox(
                    key: ValueKey('navigation-surface'),
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    await pumpTransition(visible: true);
    final transition = find.byType(ShellBottomNavigationTransition);
    expect(tester.getSize(transition), const Size(320, 96));

    await pumpTransition(visible: false);
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.getSize(transition), const Size(320, 96));
    expect(
      find.descendant(of: transition, matching: find.byType(SlideTransition)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: transition, matching: find.byType(FadeTransition)),
      findsNothing,
    );
    expect(
      find.descendant(of: transition, matching: find.byType(RepaintBoundary)),
      findsWidgets,
    );
  });

  testWidgets('native navigation labels remain above the system inset', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          navigationBarTheme: const NavigationBarThemeData(height: 72),
        ),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            padding: EdgeInsets.only(bottom: 24),
          ),
          child: Scaffold(
            extendBody: true,
            body: SizedBox.expand(),
            bottomNavigationBar: ShellBottomNavigationTransition(
              visible: true,
              child: NavigationBar(
                selectedIndex: 0,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.collections_bookmark_outlined),
                    label: 'Collections',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final navigationRect = tester.getRect(find.byType(NavigationBar));
    expect(navigationRect.bottom, 800);
    expect(navigationRect.height, 96);

    for (final label in ['Home', 'Collections']) {
      final labelRect = tester.getRect(find.text(label));
      expect(labelRect.top, greaterThanOrEqualTo(navigationRect.top));
      expect(labelRect.bottom, lessThanOrEqualTo(navigationRect.bottom - 24));
    }
  });
}
