import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
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

  testWidgets('licenses returns through About and Settings repeatedly', (
    tester,
  ) async {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks(['Test package'], 'Test license');
    });
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: TextButton(
              onPressed: () => context.push('/about'),
              child: const Text('Open About'),
            ),
          ),
        ),
        GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(
          useMaterial3: true,
          platform: TargetPlatform.android,
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
            },
          ),
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    for (var visit = 0; visit < 2; visit++) {
      await tester.tap(find.text('Open About'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
      await tester.pumpAndSettle();
      final aboutPosition = tester.getTopLeft(find.byType(AboutScreen));
      await tester.tap(find.text('Licenses'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.getTopLeft(find.byType(AboutScreen, skipOffstage: false)),
        aboutPosition,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test package'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AboutScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Open About'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
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
