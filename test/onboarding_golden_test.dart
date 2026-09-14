import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/onboarding/onboarding_flow_controller.dart';
import 'package:glimpse/features/onboarding/onboarding_screen.dart';
import 'package:glimpse/core/services/entitlement_service.dart';
import 'package:glimpse/shared/theme/app_theme.dart';
import 'package:glimpse/features/mindmap/cluster_card.dart';
import 'package:google_fonts/google_fonts.dart';

const _goldenBoundaryKey = ValueKey('onboarding-golden-boundary');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
    final phosphorBold = FontLoader('packages/phosphor_flutter/PhosphorBold')
      ..addFont(
        rootBundle.load(
          'packages/phosphor_flutter/lib/fonts/Phosphor-Bold.ttf',
        ),
      );
    final phosphorFill = FontLoader('packages/phosphor_flutter/PhosphorFill')
      ..addFont(
        rootBundle.load(
          'packages/phosphor_flutter/lib/fonts/Phosphor-Fill.ttf',
        ),
      );
    await Future.wait([phosphorBold.load(), phosphorFill.load()]);
  });

  for (final dark in [false, true]) {
    for (
      var chapter = 0;
      chapter < OnboardingChapterController.count;
      chapter++
    ) {
      testWidgets('onboarding ${dark ? 'dark' : 'light'} chapter $chapter', (
        tester,
      ) async {
        await _pumpStory(tester, dark: dark);
        for (var i = 0; i < chapter; i++) {
          await _tapCta(tester);
        }
        await _expectGolden(
          tester,
          'goldens/onboarding_v2_${dark ? 'dark_' : ''}$chapter.png',
        );
      });
    }
  }
}

Future<void> _pumpStory(WidgetTester tester, {required bool dark}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final coordinator = OnboardingFlowCoordinator(
    seedDemo: () async => 1,
    markOnboardingSeen: () async {},
    trackEvent: (_) async {},
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        onboardingFlowCoordinatorProvider.overrideWithValue(coordinator),
        isProUserProvider.overrideWithValue(false),
      ],
      child: RepaintBoundary(
        key: _goldenBoundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark
              ? AppTheme.darkTheme(Colors.green)
              : AppTheme.lightTheme(Colors.green),
          home: const OnboardingScreen(),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    await precacheImage(
      TopSignalArtwork.imageProvider(
        tester.element(find.byType(OnboardingScreen)),
      ),
      tester.element(find.byType(OnboardingScreen)),
    );
    for (final asset in ['opening']) {
      await precacheImage(
        AssetImage('assets/onboarding/$asset.webp'),
        tester.element(find.byType(OnboardingScreen)),
      );
    }
    await GoogleFonts.pendingFonts();
  });
  await tester.pumpAndSettle();
}

Future<void> _expectGolden(WidgetTester tester, String path) async {
  await tester.runAsync(() async {
    for (final widget in tester.widgetList<Image>(find.byType(Image))) {
      await precacheImage(widget.image, tester.element(find.byType(Scaffold)));
    }
  });
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_goldenBoundaryKey),
  );
  final frame = await tester.runAsync(() async {
    final frame = await boundary.toImage();
    final pixels = (await frame.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    final button = tester.getRect(
      find.byKey(const ValueKey('onboarding-primary-cta')),
    );
    final pixel =
        (button.center.dy.floor() * frame.width + (button.left + 16).floor()) *
        4;
    expect(
      pixels.getUint8(pixel),
      Theme.of(tester.element(find.byType(Scaffold))).brightness ==
              Brightness.dark
          ? greaterThan(150)
          : lessThan(100),
      reason: 'CTA must actually paint in the captured frame',
    );
    expect(pixels.getUint8(pixel + 3), 255, reason: 'CTA must be opaque');
    return frame;
  });
  try {
    await expectLater(frame!, matchesGoldenFile(path));
  } finally {
    frame?.dispose();
  }
}

Future<void> _tapCta(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('onboarding-primary-cta')));
  await tester.pumpAndSettle();
}
