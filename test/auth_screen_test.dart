import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/constants/app_assets.dart';
import 'package:glimpse/core/models/app_user.dart';
import 'package:glimpse/core/providers/auth_provider.dart';
import 'package:glimpse/core/services/auth_service.dart';
import 'package:glimpse/features/auth/auth_screen.dart';
import 'package:glimpse/shared/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final size in [const Size(360, 800), const Size(320, 568)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('sign-in remains reachable at $size with text scale $scale', (
        tester,
      ) async {
        final controller = _TestAuthController();
        await _pump(tester, controller, size: size, scale: scale);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Use another Google account'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Use another Google account'));
        await tester.pumpAndSettle();
        expect(controller.googleCalls, 1);
        expect(controller.hintCalls, 0);
        await tester.ensureVisible(find.text('Continue as Alex'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue as Alex'));
        await tester.pumpAndSettle();
        expect(controller.hintCalls, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('new account has one primary Google action', (tester) async {
    final controller = _TestAuthController();
    await _pump(tester, controller, hint: false);
    expect(find.text('Use another Google account'), findsNothing);
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(controller.googleCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('welcome preview', (tester) async {
    await _pump(tester, _TestAuthController());
    if (const bool.fromEnvironment('AUTH_PREVIEW')) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('auth-preview')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/auth-preview.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  _TestAuthController controller, {
  Size size = const Size(360, 800),
  double scale = 1,
  bool hint = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(_ConfiguredAuthService()),
        authControllerProvider.overrideWith(() => controller),
        googleAccountHintProvider.overrideWith(
          (ref) async => hint
              ? const GoogleAccountHint(
                  email: 'alex@example.com',
                  displayName: 'Alex',
                )
              : null,
        ),
      ],
      child: RepaintBoundary(
        key: const ValueKey('auth-preview'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.amoledTheme(const Color(0xFF7CB342)),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const AuthScreen(),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage(AppAssets.logo),
      tester.element(find.byType(AuthScreen)),
    );
    await GoogleFonts.pendingFonts();
  });
  await tester.pumpAndSettle();
}

class _TestAuthController extends AuthController {
  int googleCalls = 0;
  int hintCalls = 0;

  @override
  Future<AppUser?> build() async => null;

  @override
  Future<void> signInWithGoogle() async => googleCalls++;

  @override
  Future<void> signInWithGoogleHint() async => hintCalls++;
}

class _ConfiguredAuthService implements AuthService {
  @override
  bool get isConfigured => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
