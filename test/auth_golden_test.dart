import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/app_user.dart';
import 'package:glimpse/core/providers/auth_provider.dart';
import 'package:glimpse/core/services/auth_service.dart';
import 'package:glimpse/features/auth/auth_screen.dart';
import 'package:glimpse/features/onboarding/onboarding_stages.dart';
import 'package:glimpse/l10n/l10n.dart';
import 'package:glimpse/shared/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

const _boundaryKey = ValueKey('auth-golden-boundary');

/// Sign-in is drawn as onboarding's last chapter, so it is captured at the
/// same size and in the same house palette as `onboarding_v3_*`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('sign-in after onboarding, $mode', (tester) async {
      await _pump(tester, dark: dark, firstRun: true, hint: true);
      await _expectGolden(tester, 'goldens/auth_v2_${mode}_first_run.png');
    });
    testWidgets('sign-in returning, no account hint, $mode', (tester) async {
      await _pump(tester, dark: dark, firstRun: false, hint: false);
      await _expectGolden(tester, 'goldens/auth_v2_${mode}_returning.png');
    });
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required bool dark,
  required bool firstRun,
  required bool hint,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(_ConfiguredAuthService()),
        authControllerProvider.overrideWith(_SignedOutController.new),
        googleAccountHintProvider.overrideWith(
          (ref) async => hint
              ? const GoogleAccountHint(
                  email: 'alex@example.com',
                  displayName: 'Alex Rivera',
                )
              : null,
        ),
      ],
      child: RepaintBoundary(
        key: _boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.brandTheme(dark ? Brightness.dark : Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: AuthScreen(isOnboardingEntry: firstRun),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage(OnboardingArt.reel),
      tester.element(find.byType(AuthScreen)),
    );
    await GoogleFonts.pendingFonts();
  });
  await tester.pumpAndSettle();
}

Future<void> _expectGolden(WidgetTester tester, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  final frame = await tester.runAsync(
    () async => boundary.toImage(pixelRatio: 1),
  );
  try {
    await expectLater(frame!, matchesGoldenFile(path));
  } finally {
    frame?.dispose();
  }
  expect(tester.takeException(), isNull);
}

class _SignedOutController extends AuthController {
  @override
  Future<AppUser?> build() async => null;
}

class _ConfiguredAuthService implements AuthService {
  @override
  bool get isConfigured => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
