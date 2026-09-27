import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/analytics_service.dart';
import 'package:glimpse/features/onboarding/onboarding_flow_controller.dart';
import 'package:glimpse/features/onboarding/onboarding_screen.dart';
import 'package:glimpse/features/onboarding/onboarding_stages.dart';
import 'package:glimpse/l10n/l10n.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glimpse/core/providers/analytics_provider.dart';
import 'package:glimpse/core/providers/dev_simulation_providers.dart';
import 'package:glimpse/core/services/usage_limits.dart';

OnboardingFlowCoordinator flow({
  Future<void> Function()? complete,
  Future<int> Function()? seed,
  Future<void> Function(bool)? prepare,
  Future<void> Function(AnalyticsEvent)? track,
}) => OnboardingFlowCoordinator(
  seedDemo: seed ?? () async => 1,
  markOnboardingSeen: complete ?? () async {},
  prepareCompletion: prepare,
  trackEvent: track ?? (_) async {},
  criticalTimeout: const Duration(milliseconds: 100),
);

Widget app(
  OnboardingFlowCoordinator coordinator, {
  Locale locale = const Locale('en'),
  double scale = 1,
  bool dark = false,
  bool reducedMotion = true,
}) => ProviderScope(
  overrides: [onboardingFlowCoordinatorProvider.overrideWithValue(coordinator)],
  child: MaterialApp(
    theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        disableAnimations: reducedMotion,
      ),
      child: child!,
    ),
    home: const OnboardingScreen(),
  ),
);

final _cta = find.byKey(const ValueKey('onboarding-primary-cta'));
final _chapterCount = OnboardingFlowCoordinator.chapters.length;

Future<void> next(WidgetTester tester) async {
  await tester.tap(_cta);
  await tester.pumpAndSettle();
}

String ctaLabel(WidgetTester tester) =>
    (tester.widget<FilledButton>(_cta).child! as Text).data!;

double page(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView)).controller!.page!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('five chapters tell the story and finish with the demo save', (
    tester,
  ) async {
    var finished = 0;
    var seeded = 0;
    final events = <AnalyticsEvent>[];
    await tester.pumpWidget(
      app(
        flow(
          complete: () async => finished++,
          seed: () async => ++seeded,
          track: (e) async => events.add(e),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Keep what catches your mind.'), findsOneWidget);
    expect(ctaLabel(tester), 'Get started');
    await next(tester);
    expect(find.text('Save from anywhere.'), findsOneWidget);
    expect(ctaLabel(tester), 'Next');
    await next(tester);
    expect(find.text('Glimpse reads it for you.'), findsOneWidget);
    // Reduced motion shows the finished page, as a real save's reader.
    expect(find.text('Three ideas that fixed my focus'), findsOneWidget);
    expect(find.text('Key takeaways'), findsOneWidget);
    await next(tester);
    expect(find.text('Find anything again.'), findsOneWidget);
    expect(find.text('Two-minute rule'), findsOneWidget);
    await next(tester);
    expect(find.text('Gets better with every save.'), findsOneWidget);
    expect(ctaLabel(tester), 'Start saving');
    expect(
      find.text('Free includes 30 AI-read saves. Upgrade whenever you like.'),
      findsOneWidget,
    );
    await tester.tap(_cta);
    await tester.pumpAndSettle();
    expect(finished, 1);
    expect(seeded, 1);
    expect(
      events.where((e) => OnboardingFlowCoordinator.chapters.contains(e)),
      OnboardingFlowCoordinator.chapters,
    );
    expect(events, contains(AnalyticsEvent.onboardingCompleted));
  });

  testWidgets('system back steps to the previous chapter', (tester) async {
    await tester.pumpWidget(app(flow()));
    await tester.pumpAndSettle();
    await next(tester);
    await next(tester);
    expect(page(tester), 2);
    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pumpAndSettle();
    expect(page(tester), 1);
  });

  testWidgets('primary action stays put above the device inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(app(flow()));
    await tester.pumpAndSettle();
    final first = tester.getRect(_cta);
    expect(first.bottom, lessThanOrEqualTo(915 - 24));
    for (var chapter = 1; chapter < _chapterCount; chapter++) {
      await next(tester);
      expect(tester.getRect(_cta), first);
    }
  });

  testWidgets('skip does not seed, and the last chapter has no skip', (
    tester,
  ) async {
    var seeds = 0;
    bool? pro;
    await tester.pumpWidget(
      app(
        flow(
          seed: () async => ++seeds,
          prepare: (v) async {
            pro = v;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < _chapterCount - 1; i++) {
      await next(tester);
    }
    expect(find.text('Skip').hitTestable(), findsNothing);
    await tester.drag(find.byType(PageView), const Offset(600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(seeds, 0);
    expect(pro, false);
  });

  testWidgets('failed completion remains retryable', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      app(
        flow(
          complete: () async {
            if (++attempts == 1) throw StateError('disk');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(
      find.text('Couldn’t save your progress. Please try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  testWidgets('the share demo loops only while it is on screen', (
    tester,
  ) async {
    await tester.pumpWidget(app(flow(), reducedMotion: false));
    await tester.pumpAndSettle();
    await tester.tap(_cta);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 8));
    expect(tester.binding.hasScheduledFrame, isTrue);
    // Leaving the page stops the loop; the later stages play once and rest.
    for (var i = 0; i < 3; i++) {
      await tester.tap(_cta);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();
    expect(page(tester), _chapterCount - 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('tap and swipe share one paged surface', (tester) async {
    await tester.pumpWidget(app(flow(), reducedMotion: false));
    await tester.pumpAndSettle();
    await tester.tap(_cta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(page(tester), inExclusiveRange(0, 1));
    // A second tap mid-animation is ignored rather than skipping a page.
    await tester.tap(_cta);
    await tester.pump(const Duration(seconds: 1));
    expect(page(tester), 1);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    // Once the share demo is off screen its loop stops, so this settles.
    await tester.pumpAndSettle();
    expect(page(tester), 2);
  });

  test('every bundled artwork is present', () async {
    for (final art in OnboardingArt.all) {
      final data = await rootBundle.load(OnboardingArt.path(art));
      expect(data.lengthInBytes, greaterThan(1000), reason: art);
    }
  });

  testWidgets('follows the app theme instead of forcing its own', (
    tester,
  ) async {
    await tester.pumpWidget(app(flow(), dark: true));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Theme.of(context).colorScheme.surface,
    );
  });

  for (final dark in [false, true]) {
    for (final locale in ['en', 'ja', 'es', 'fr', 'pt', 'de']) {
      testWidgets(
        '$locale ${dark ? 'dark' : 'light'} compact phone and large text stay usable',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            app(flow(), locale: Locale(locale), scale: 1.6, dark: dark),
          );
          await tester.pumpAndSettle();
          for (var i = 0; i < _chapterCount; i++) {
            expect(tester.takeException(), isNull);
            expect(tester.getRect(_cta).bottom, lessThanOrEqualTo(640));
            if (i < _chapterCount - 1) await next(tester);
          }
        },
      );
    }
  }

  test('replaying onboarding resets the completed coordinator', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        analyticsServiceProvider.overrideWithValue(_QuietAnalytics()),
        hasSeenOnboardingProvider.overrideWith(
          (ref) => HasSeenOnboardingNotifier(initial: false),
        ),
      ],
    );
    addTearDown(container.dispose);
    final coordinator = container.read(onboardingFlowCoordinatorProvider);
    await coordinator.skip();
    expect(container.read(hasSeenOnboardingProvider), isTrue);
    await container.read(hasSeenOnboardingProvider.notifier).reset();
    expect(container.read(hasSeenOnboardingProvider), isFalse);
    await coordinator.skip();
    expect(container.read(hasSeenOnboardingProvider), isTrue);
  });

  test('published plan allowances do not expose development ceilings', () {
    expect(UsageLimits.planAllowance(UsageFeature.aiSave), 30);
    expect(UsageLimits.planAllowance(UsageFeature.ask), 30);
    expect(UsageLimits.planAllowance(UsageFeature.search), 30);
    expect(UsageLimits.planAllowance(UsageFeature.aiSave, isPro: true), 500);
  });

  test(
    'completion is idempotent and optional seed cannot block routing',
    () async {
      var routes = 0;
      final coordinator = flow(
        complete: () async {
          routes++;
        },
        seed: () => Completer<int>().future,
      );
      await Future.wait([coordinator.complete(), coordinator.complete()]);
      await coordinator.complete();
      expect(routes, 1);
    },
  );
}

class _QuietAnalytics implements AnalyticsService {
  @override
  Future<void> trackEvent(
    AnalyticsEvent event, {
    AnalyticsScreen? screen,
  }) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
