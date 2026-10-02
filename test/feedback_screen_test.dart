import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/feedback/feedback_screen.dart';
import 'package:glimpse/features/feedback/feedback_service.dart';
import 'package:glimpse/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFeedbackService extends FeedbackService {
  _FakeFeedbackService({this.failWith});

  final FeedbackFailure? failWith;
  final sent = <({FeedbackKind kind, String message, Uint8List? screenshot})>[];

  @override
  Future<void> submit({
    required FeedbackKind kind,
    required String message,
    String? screenName,
    Uint8List? screenshotPng,
    String? locale,
  }) async {
    if (failWith != null) throw FeedbackException(failWith!);
    sent.add((kind: kind, message: message, screenshot: screenshotPng));
  }
}

// A 1x1 transparent PNG.
final _png = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

Future<void> _pump(
  WidgetTester tester,
  FeedbackService service, {
  FeedbackLaunch launch = const FeedbackLaunch(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [feedbackServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // A page underneath, as in the app: a sent report pops back to it.
        home: Navigator(
          onGenerateInitialRoutes: (_, _) => [
            MaterialPageRoute(builder: (_) => const Scaffold()),
            MaterialPageRoute(builder: (_) => FeedbackScreen(launch: launch)),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  FilledButton sendButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  testWidgets('sends nothing until there is a message', (tester) async {
    final service = _FakeFeedbackService();
    await _pump(tester, service);
    expect(sendButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(sendButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Search froze');
    await tester.pump();
    expect(sendButton(tester).onPressed, isNotNull);
  });

  testWidgets('a shake report sends its screenshot unless switched off', (
    tester,
  ) async {
    final service = _FakeFeedbackService();
    await _pump(
      tester,
      service,
      launch: FeedbackLaunch(screenshot: _png, fromShake: true),
    );
    expect(find.text('Include screenshot'), findsOneWidget);
    expect(
      find.textContaining('You opened this by shaking your phone'),
      findsOneWidget,
      reason: 'first shake explains how to turn it off',
    );

    await tester.enterText(find.byType(TextField), 'Card overlaps');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(service.sent.single.screenshot, _png);
    expect(service.sent.single.kind, FeedbackKind.bug);

    // Again, with the screenshot switched off and as an idea.
    await _pump(
      tester,
      service,
      launch: FeedbackLaunch(screenshot: _png, fromShake: true),
    );
    expect(
      find.textContaining('You opened this by shaking your phone'),
      findsNothing,
      reason: 'the tip shows only once',
    );
    await tester.tap(find.text('I have an idea'));
    await tester.tap(find.byType(Switch));
    await tester.enterText(find.byType(TextField), 'Dark widget');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(service.sent.last.screenshot, isNull);
    expect(service.sent.last.kind, FeedbackKind.idea);
  });

  testWidgets('signed out, it says so and keeps the message', (tester) async {
    await _pump(
      tester,
      _FakeFeedbackService(failWith: FeedbackFailure.signedOut),
    );
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to send feedback.'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
  });
}
