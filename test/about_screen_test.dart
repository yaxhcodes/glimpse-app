import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/settings/about_screen.dart';
import 'package:glimpse/l10n/l10n.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Glimpse',
      packageName: 'com.shinrinyoku.glimpse',
      version: '1.0.7',
      buildNumber: '108',
      buildSignature: '',
    );
  });

  Future<void> pumpAbout(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(useMaterial3: true),
        home: const AboutScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the new support actions', (tester) async {
    await pumpAbout(tester);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Send feedback'), findsOneWidget);
    expect(find.text('Rate on Play Store'), findsOneWidget);
    expect(find.text('Share Glimpse'), findsOneWidget);
  });

  testWidgets('reveals the keepsake after exactly seven version taps', (
    tester,
  ) async {
    await pumpAbout(tester);

    final version = find.text('Version 1.0.7 (Build 108)');
    expect(version, findsOneWidget);

    for (var tap = 0; tap < 6; tap++) {
      await tester.tap(version);
      await tester.pump();
    }
    expect(find.byKey(const Key('about-easter-egg')), findsNothing);

    await tester.tap(version);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('about-easter-egg')), findsOneWidget);
  });
}
