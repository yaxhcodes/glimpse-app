import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glimpse/features/onboarding/onboarding_visual_scene.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/analytics_service.dart';
import 'package:glimpse/core/services/entitlement_service.dart';
import 'package:glimpse/features/onboarding/onboarding_flow_controller.dart';
import 'package:glimpse/features/onboarding/onboarding_screen.dart';
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
  bool pro = false,
  Locale locale = const Locale('en'),
  double scale = 1,
  bool dark = false,
  bool reducedMotion = true,
}) => ProviderScope(
  overrides: [
    onboardingFlowCoordinatorProvider.overrideWithValue(coordinator),
    isProUserProvider.overrideWithValue(pro),
  ],
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

Future<void> next(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('onboarding-primary-cta')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  testWidgets('seven visual chapters retain navigation and can finish free', (
    tester,
  ) async {
    var finished = 0;
    var seeded = 0;
    final events = <AnalyticsEvent>[];
    await tester.pumpWidget(
      app(
        flow(
          complete: () async {
            finished++;
          },
          seed: () async => ++seeded,
          track: (e) async => events.add(e),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Keep what catches your mind.'), findsOneWidget);
    await next(tester);
    expect(
      find.byKey(const ValueKey('onboarding-preview-1-0')),
      findsOneWidget,
    );
    await next(tester);
    await tester.tap(find.byTooltip('Previous chapter'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('onboarding-preview-1-0')),
      findsOneWidget,
    );
    await next(tester);
    await next(tester);
    expect(find.text('Discovered in your saves'), findsOneWidget);
    await next(tester);
    expect(
      find.byKey(const ValueKey('onboarding-preview-4-0')),
      findsOneWidget,
    );
    await next(tester);
    expect(find.text('Come back with a reason.'), findsOneWidget);
    await next(tester);
    expect(find.text('Start with Free'), findsOneWidget);
    expect(find.text('Explore Pro'), findsOneWidget);
    await tester.tap(find.text('Start with Free'));
    await tester.pumpAndSettle();
    expect(finished, 1);
    expect(seeded, 1);
    expect(
      events.where((e) => e == AnalyticsEvent.onboardingChapterReader).length,
      1,
    );
  });
  testWidgets('primary action stays above the device inset on every chapter', (
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
    for (
      var chapter = 0;
      chapter < OnboardingChapterController.count;
      chapter++
    ) {
      expect(
        tester
            .getRect(find.byKey(const ValueKey('onboarding-primary-cta')))
            .bottom,
        883,
      );
      if (chapter < OnboardingChapterController.count - 1) await next(tester);
    }
  });
  testWidgets('pricing transition keeps the page viewport stable', (tester) async {
    await tester.pumpWidget(app(flow(), reducedMotion: false));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await next(tester);
    }
    final viewport = tester.getRect(find.byType(PageView));
    await tester.tap(find.byKey(const ValueKey('onboarding-primary-cta')));
    await tester.pump();
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.getRect(find.byType(PageView)), viewport);
    }
    await tester.pumpAndSettle();
    expect(find.text('Start with Free').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Previous chapter'));
    await tester.pump();
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.getRect(find.byType(PageView)), viewport);
    }
    await tester.pumpAndSettle();
  });
  testWidgets('visual motion finishes once and never gates navigation', (
    tester,
  ) async {
    await tester.pumpWidget(app(flow(), reducedMotion: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-primary-cta')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final scene = find.byKey(const ValueKey('onboarding-preview-1-0'));
    final opacity = find
        .ancestor(of: scene, matching: find.byType(Opacity))
        .first;
    expect(tester.widget<Opacity>(opacity).opacity, lessThan(1));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(opacity).opacity, 1);
    await next(tester);
    await tester.tap(find.byTooltip('Previous chapter'));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(opacity).opacity, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
  test('every locale and brightness has its complete image set', () async {
    for (final locale in ['en', 'de', 'es', 'fr', 'pt', 'ja']) {
      for (final brightness in ['light', 'dark']) {
        for (var chapter = 1; chapter <= 5; chapter++) {
          for (final part in OnboardingScene.partsFor(chapter)) {
            final path = chapter <= 3
                ? 'assets/onboarding/${const ['enrichment', 'interests', 'discovered'][chapter - 1]}.webp'
                : 'assets/onboarding/previews/${locale}_${brightness}_${chapter}_$part.webp';
            final data = await rootBundle.load(path);
            expect(data.lengthInBytes, greaterThan(100));
          }
        }
      }
    }
  });
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
  testWidgets(
    'dark canvas follows app brightness with bundled editorial artwork',
    (tester) async {
      await tester.pumpWidget(app(flow(), dark: true));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName.endsWith('opening.webp'),
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'tap and swipe share one paged surface and repeated taps stay bounded',
    (tester) async {
      await tester.pumpWidget(app(flow(), reducedMotion: false));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('onboarding-primary-cta')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final page = tester
          .widget<PageView>(find.byType(PageView))
          .controller!
          .page!;
      expect(page, greaterThan(0));
      expect(page, lessThan(1));
      await tester.tap(find.byKey(const ValueKey('onboarding-primary-cta')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        1,
      );
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        2,
      );
    },
  );
  testWidgets('skip does not seed or open Pro', (tester) async {
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
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(seeds, 0);
    expect(pro, false);
  });
  testWidgets('Pro intent is prepared before routing', (tester) async {
    final order = <String>[];
    await tester.pumpWidget(
      app(
        flow(
          prepare: (pro) async => order.add('pro:$pro'),
          complete: () async => order.add('route'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < OnboardingChapterController.count - 1; i++) {
      await next(tester);
    }
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('onboarding-primary-cta')),
          )
          .child,
      isA<Text>().having((text) => text.data, 'label', 'Explore Pro'),
    );
    await tester.tap(find.text('Explore Pro'));
    await tester.pumpAndSettle();
    expect(order, ['pro:true', 'route']);
  });
  testWidgets('existing subscribers can continue without an upsell', (
    tester,
  ) async {
    await tester.pumpWidget(app(flow(), pro: true));
    await tester.pumpAndSettle();
    for (var i = 0; i < OnboardingChapterController.count - 1; i++) {
      await next(tester);
    }
    expect(find.text('Continue with Pro'), findsOneWidget);
    expect(find.text('Explore Pro'), findsNothing);
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
  for (final dark in [false, true]) {
    for (final locale in ['en', 'ja', 'es', 'fr', 'pt', 'de']) {
      testWidgets(
        '$locale ${dark ? 'dark' : 'light'} compact phone and large text remain usable',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            app(flow(), locale: Locale(locale), scale: 1.6, dark: dark),
          );
          await tester.pumpAndSettle();
          for (var i = 0; i < OnboardingChapterController.count; i++) {
            expect(tester.takeException(), isNull);
            expect(
              tester
                  .getRect(find.byKey(const ValueKey('onboarding-primary-cta')))
                  .bottom,
              lessThanOrEqualTo(640),
            );
            if (i < OnboardingChapterController.count - 1) await next(tester);
          }
        },
      );
    }
  }
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
