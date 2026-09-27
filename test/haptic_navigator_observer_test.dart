import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/app_haptics.dart';
import 'package:glimpse/core/services/haptic_navigator_observer.dart';

void main() {
  final played = <String>[];
  const channel = MethodChannel('com.shinrinyoku.glimpse/haptics');
  final navigator = GlobalKey<NavigatorState>();

  Widget app({VoidCallback? before}) => MaterialApp(
    navigatorKey: navigator,
    navigatorObservers: [HapticNavigatorObserver()],
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () {
              before?.call();
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const Text('page')),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  setUp(() {
    played.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          played.add((call.arguments as Map)['name'] as String);
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('opening a page by touch is felt as a tap', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('page'), findsOneWidget);
    expect(played, ['tap']);
  });

  testWidgets('navigation driven by code stays silent', (tester) async {
    await tester.pumpWidget(app());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('page')),
    );
    await tester.pumpAndSettle();
    expect(find.text('page'), findsOneWidget);
    expect(played, isEmpty);
  });

  testWidgets('a widget that already gave feedback is not doubled', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(before: () => AppHaptics.play(AppHaptics.tick)),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(played, ['tick']);
  });

  testWidgets('dialogs and sheets are left alone', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [HapticNavigatorObserver()],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const Text('dialog'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('dialog'), findsOneWidget);
    expect(played, isEmpty);
  });
}
