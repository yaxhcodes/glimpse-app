import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/constants/app_assets.dart';
import 'package:glimpse/features/onboarding/onboarding_flow_controller.dart';
import 'package:glimpse/features/onboarding/onboarding_screen.dart';
import 'package:glimpse/features/onboarding/onboarding_story.dart';
import 'package:glimpse/shared/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

const _goldenBoundaryKey = ValueKey('onboarding-golden-boundary');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    final symbols = FontLoader('GlimpseMaterialSymbolsRounded')
      ..addFont(
        rootBundle.load('assets/fonts/GlimpseMaterialSymbolsRounded.ttf'),
      );
    await symbols.load();
  });

  testWidgets('discovery story frame', (tester) async {
    await _pumpStory(tester);
    await _expectGolden(tester, 'goldens/onboarding_discovery.png');
  });

  testWidgets('share story frame', (tester) async {
    await _pumpStory(tester);
    await _tapCta(tester);
    await tester.tap(find.byKey(const ValueKey('onboarding-share-target')));
    await tester.pumpAndSettle();
    await _expectGolden(tester, 'goldens/onboarding_share.png');
  });

  testWidgets('enrichment story frame', (tester) async {
    await _pumpStory(tester);
    await _tapCta(tester);
    await _tapCta(tester);
    await _expectGolden(tester, 'goldens/onboarding_enrichment.png');
  });

  testWidgets('calendar passage story frame', (tester) async {
    await _pumpStory(tester);
    await _reachRediscover(tester);
    tester
        .state<OnboardingStorySceneState>(find.byType(OnboardingStoryScene))
        .setTimePassage(0.58);
    await tester.pumpAndSettle();
    await _expectStoryGolden(
      tester,
      'goldens/onboarding_rediscover_timeline.png',
    );
  });

  testWidgets('rediscover notification story frame', (tester) async {
    await _pumpStory(tester);
    await _reachRediscover(tester);
    await tester.pumpAndSettle();
    await _expectGolden(
      tester,
      'goldens/onboarding_rediscover_notification.png',
    );
  });

  testWidgets('opened memory story frame', (tester) async {
    await _pumpStory(tester);
    await _reachRediscover(tester);
    await tester.pumpAndSettle();
    await _tapCta(tester);
    await _expectGolden(tester, 'goldens/onboarding_rediscover_opened.png');
  });
}

Future<void> _pumpStory(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final coordinator = OnboardingFlowCoordinator(
    seedDemo: () async => 1,
    markShareLessonSeen: () async {},
    markOnboardingSeen: () async {},
    trackEvent: (_) async {},
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        onboardingFlowCoordinatorProvider.overrideWithValue(coordinator),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme(Colors.green),
        home: const RepaintBoundary(
          key: _goldenBoundaryKey,
          child: OnboardingScreen(),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage(AppAssets.onboardingKyoto),
      tester.element(find.byType(OnboardingScreen)),
    );
    await GoogleFonts.pendingFonts();
  });
  await tester.pumpAndSettle();
}

Future<void> _reachRediscover(WidgetTester tester) async {
  await _tapCta(tester);
  await _tapCta(tester);
  await tester.tap(find.byKey(const ValueKey('onboarding-primary-cta')));
  await tester.pump();
}

Future<void> _expectGolden(WidgetTester tester, String path) async {
  final dynamic screenState = tester.state(find.byType(OnboardingScreen));
  screenState.setState(() {});
  await tester.pump();
  for (final element in tester.allElements) {
    element.renderObject?.markNeedsPaint();
  }
  await tester.pump();
  await expectLater(find.byKey(_goldenBoundaryKey), matchesGoldenFile(path));
}

Future<void> _expectStoryGolden(WidgetTester tester, String path) async {
  final story = find.byKey(const ValueKey('onboarding-story-stage'));
  tester.renderObject(story).markNeedsPaint();
  await tester.pump();
  await expectLater(story, matchesGoldenFile(path));
}

Future<void> _tapCta(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('onboarding-primary-cta')));
  await tester.pumpAndSettle();
}
