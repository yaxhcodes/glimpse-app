import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/constants/app_assets.dart';
import 'package:glimpse/core/services/analytics_service.dart';
import 'package:glimpse/features/onboarding/onboarding_flow_controller.dart';
import 'package:glimpse/features/onboarding/onboarding_screen.dart';
import 'package:glimpse/features/onboarding/onboarding_story.dart';
import 'package:glimpse/shared/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'one persistent story scene carries the link through completion',
    (tester) async {
      var seeds = 0;
      var shareLessons = 0;
      var completions = 0;
      final events = <AnalyticsEvent>[];
      final coordinator = OnboardingFlowCoordinator(
        seedDemo: () async => ++seeds,
        markShareLessonSeen: () async => shareLessons++,
        markOnboardingSeen: () async => completions++,
        trackEvent: (event) async => events.add(event),
      );

      await tester.pumpWidget(_app(coordinator));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingStoryScene), findsOneWidget);
      expect(find.text('Find something worth keeping.'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      _expectStoryStep(tester, 1);
      expect(events, contains(AnalyticsEvent.onboardingStarted));

      await _tapCta(tester);
      expect(find.byType(OnboardingStoryScene), findsOneWidget);
      expect(find.text('Save it from anywhere.'), findsOneWidget);
      _expectStoryStep(tester, 2);

      await _tapVisible(tester, find.byTooltip('Previous step'));
      await tester.pumpAndSettle();
      expect(find.text('Find something worth keeping.'), findsOneWidget);

      await _tapCta(tester);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('onboarding-share-target')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Glimpse'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Gmail'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
      expect(
        find.image(const AssetImage(AppAssets.launcherIcon)),
        findsOneWidget,
      );

      await _tapCta(tester);
      expect(find.text('Glimpse remembers the details.'), findsOneWidget);
      _expectStoryStep(tester, 3);
      await tester.pumpAndSettle();
      expect(find.text('SEARCHABLE MEMORY'), findsOneWidget);
      for (final label in const [
        'Link received',
        'Thumbnail found',
        'Summary written',
        'Tags created',
        'Intent understood',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('ready-memory-card')), findsOneWidget);
      expect(
        events.where((event) => event == AnalyticsEvent.onboardingTransformed),
        hasLength(1),
      );

      await tester.tap(find.byKey(const ValueKey('onboarding-primary-cta')));
      await tester.pump();
      expect(
        find.text("Timed to when you'll actually need it."),
        findsOneWidget,
      );
      expect(find.text('Not a random ping—a well-timed one.'), findsOneWidget);
      _expectStoryStep(tester, 4);
      tester
          .state<OnboardingStorySceneState>(find.byType(OnboardingStoryScene))
          .setTimePassage(0.58);
      await tester.pumpAndSettle();
      expect(find.text('OCTOBER'), findsOneWidget);
      expect(find.text('Two weeks later'), findsOneWidget);
      for (var day = 1; day <= 14; day++) {
        expect(
          find.byKey(ValueKey('onboarding-calendar-day-$day')),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const ValueKey('onboarding-calendar-day-15')),
        findsNothing,
      );
      tester
          .state<OnboardingStorySceneState>(find.byType(OnboardingStoryScene))
          .setTimePassage(1);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('rediscover-notification')),
        findsOneWidget,
      );
      expect(
        find.image(const AssetImage(AppAssets.launcherIcon)),
        findsNWidgets(2),
      );

      await _tapCta(tester);
      expect(find.text('REDISCOVERED · 2 WEEKS LATER'), findsOneWidget);
      expect(find.text('It comes back when it matters.'), findsOneWidget);
      expect(find.text('Enter Glimpse'), findsOneWidget);
      expect(find.text('Temples'), findsOneWidget);
      expect(find.text('Gion nights'), findsOneWidget);
      _expectStoryStep(tester, 5);

      await _tapVisible(tester, find.byTooltip('Previous step'));
      await tester.pumpAndSettle();
      _expectStoryStep(tester, 4);
      expect(
        find.text("Timed to when you'll actually need it."),
        findsOneWidget,
      );

      await _tapCta(tester);
      _expectStoryStep(tester, 5);

      await _tapCta(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(seeds, 1);
      expect(shareLessons, 1);
      expect(completions, 1);
      expect(events, contains(AnalyticsEvent.onboardingCompleted));
    },
  );

  testWidgets(
    'skip is always available and does not seed or suppress the share lesson',
    (tester) async {
      var seeds = 0;
      var shareLessons = 0;
      var completions = 0;
      final coordinator = OnboardingFlowCoordinator(
        seedDemo: () async => ++seeds,
        markShareLessonSeen: () async => shareLessons++,
        markOnboardingSeen: () async => completions++,
        trackEvent: (_) async {},
      );

      await tester.pumpWidget(_app(coordinator));
      await _tapCta(tester);
      expect(find.text('Skip'), findsOneWidget);
      await _tapVisible(tester, find.text('Skip'));
      await tester.pumpAndSettle();

      expect(seeds, 0);
      expect(shareLessons, 0);
      expect(completions, 1);
    },
  );

  testWidgets('stalled completion exposes retry instead of a dead CTA', (
    tester,
  ) async {
    var attempts = 0;
    final coordinator = OnboardingFlowCoordinator(
      seedDemo: () async => 1,
      markShareLessonSeen: () async {},
      markOnboardingSeen: () {
        attempts++;
        if (attempts == 1) return Completer<void>().future;
        return Future.value();
      },
      trackEvent: (_) async {},
      criticalTimeout: const Duration(milliseconds: 20),
    );

    await tester.pumpWidget(_app(coordinator, disableAnimations: true));
    await _reachOpenedMemory(tester);
    await _tapCta(tester);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Try again'), findsOneWidget);
    expect(
      find.text('We couldn’t save your progress. Please try again.'),
      findsOneWidget,
    );

    await _tapCta(tester);
    await tester.pump(const Duration(milliseconds: 50));
    expect(attempts, 2);
  });

  testWidgets('compact phone and elevated text remain usable', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final coordinator = _coordinator();
    await tester.pumpWidget(
      _app(coordinator, textScale: 1.3, disableAnimations: true),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(OnboardingStoryScene), findsOneWidget);
    final semantics = tester.getSemantics(
      find.byKey(const ValueKey('onboarding-primary-cta')),
    );
    expect(semantics.getSemanticsData().flagsCollection.isButton, isTrue);

    for (var step = 0; step < 4; step++) {
      await _tapCta(tester);
      expect(
        tester.takeException(),
        isNull,
        reason: 'chapter ${step + 1} must fit the compact layout',
      );
    }
    expect(find.text('For your autumn in Kyoto'), findsOneWidget);
    expect(find.text('Temples'), findsOneWidget);
    expect(find.text('Gion nights'), findsOneWidget);
  });

  testWidgets('reduced motion renders completed product states directly', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_coordinator(), disableAnimations: true));
    await tester.pumpAndSettle();

    await _tapCta(tester);
    await _tapCta(tester);
    await tester.pumpAndSettle();
    expect(find.text('SEARCHABLE MEMORY'), findsOneWidget);

    await _tapCta(tester);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('rediscover-notification')),
      findsOneWidget,
    );
  });

  test('completion remains idempotent when optional work fails', () async {
    var criticalWrites = 0;
    final coordinator = OnboardingFlowCoordinator(
      seedDemo: () async => throw StateError('seed unavailable'),
      markShareLessonSeen: () async => throw StateError('prefs unavailable'),
      markOnboardingSeen: () async => criticalWrites++,
      trackEvent: (_) async => throw StateError('analytics unavailable'),
    );

    await coordinator.complete();
    await coordinator.complete();

    expect(criticalWrites, 1);
  });

  test('a hanging demo seed cannot block routing', () async {
    final hangingSeed = Completer<int>();
    var criticalWrites = 0;
    final coordinator = OnboardingFlowCoordinator(
      seedDemo: () => hangingSeed.future,
      markShareLessonSeen: () async {},
      markOnboardingSeen: () async => criticalWrites++,
      trackEvent: (_) async {},
    );

    await coordinator.complete().timeout(const Duration(milliseconds: 250));

    expect(criticalWrites, 1);
    hangingSeed.complete(1);
  });
}

OnboardingFlowCoordinator _coordinator() {
  return OnboardingFlowCoordinator(
    seedDemo: () async => 1,
    markShareLessonSeen: () async {},
    markOnboardingSeen: () async {},
    trackEvent: (_) async {},
  );
}

Widget _app(
  OnboardingFlowCoordinator coordinator, {
  double textScale = 1,
  bool disableAnimations = false,
}) {
  return ProviderScope(
    overrides: [
      onboardingFlowCoordinatorProvider.overrideWithValue(coordinator),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme(Colors.green),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: child!,
        );
      },
      home: const OnboardingScreen(),
    ),
  );
}

Future<void> _tapCta(WidgetTester tester) async {
  await _tapVisible(
    tester,
    find.byKey(const ValueKey('onboarding-primary-cta')),
  );
  await tester.pumpAndSettle();
}

Future<void> _reachOpenedMemory(WidgetTester tester) async {
  await _tapCta(tester);
  await _tapCta(tester);
  await _tapCta(tester);
  await _tapCta(tester);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void _expectStoryStep(WidgetTester tester, int step) {
  final semantics = tester.getSemantics(
    find.byKey(const ValueKey('onboarding-position-indicator')),
  );
  expect(semantics.label, 'Step $step of 5');
}
