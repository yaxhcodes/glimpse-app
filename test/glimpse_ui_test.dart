import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/services/digest_prefs.dart';
import 'package:glimpse/features/home/home_provider.dart';
import 'package:glimpse/shared/widgets/premium_swipe_card.dart';
import 'package:glimpse/shared/widgets/notifications/curated_notification_media.dart';
import 'package:glimpse/core/services/notification_router.dart';
import 'package:glimpse/features/glimpses/glimpse.dart';
import 'package:glimpse/features/glimpses/glimpse_activity.dart';
import 'package:glimpse/features/glimpses/glimpse_activity_provider.dart';
import 'package:glimpse/features/glimpses/glimpse_period_overview.dart';
import 'package:glimpse/features/glimpses/glimpse_activity_chart.dart';
import 'package:glimpse/features/glimpses/glimpse_engine.dart';
import 'package:glimpse/features/digest/notifications_screen.dart';
import 'package:glimpse/features/glimpses/glimpse_detail_screen.dart';
import 'package:glimpse/features/glimpses/glimpse_card_menu.dart';
import 'package:glimpse/features/glimpses/glimpse_service.dart';
import 'package:glimpse/features/glimpses/glimpses_screen.dart';
import 'package:glimpse/features/glimpses/glimpse_history_screen.dart';
import 'package:glimpse/features/glimpses/glimpse_weekly_preparation.dart';
import 'package:glimpse/features/glimpses/glimpse_weekly_settings.dart';
import 'package:glimpse/l10n/l10n.dart';
import 'package:glimpse/shared/theme/app_theme.dart';
import 'glimpse_engine_test.dart' show candidate, save, stored;

class _FakeIsar extends Fake implements IsarService {}

class _Service extends GlimpseService {
  _Service() : super(_FakeIsar());
  final actions = <GlimpseAction>[];
  @override
  Future<void> openKey(String key) async {
    actions.add(GlimpseAction.opened);
  }

  @override
  Future<void> act(
    Glimpse glimpse,
    GlimpseAction action, {
    DateTime? at,
  }) async {
    actions.add(action);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    for (final (family, asset) in [
      ('Instrument Sans', 'assets/fonts/InstrumentSans-Regular.ttf'),
      ('Newsreader', 'assets/fonts/Newsreader-SemiBold.ttf'),
      (
        'packages/phosphor_flutter/PhosphorBold',
        'packages/phosphor_flutter/lib/fonts/Phosphor-Bold.ttf',
      ),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });

  final idea = candidate(expires: DateTime(2100));
  final urls = {
    for (var id = 4; id <= 21; id++)
      id: save(id, DateTime(2026, 9, 1 + id % 8))
        ..title =
            '${id % 3 == 0
                ? 'Quantum physics'
                : id % 3 == 1
                ? 'Recipe'
                : 'Music'} $id'
        ..tags = [],
    1: save(1, DateTime(2026, 8, 1))..title = 'Making reversible decisions',
    2: save(2, DateTime(2026, 9, 7))..title = 'A week of useful ideas',
    3: save(3, DateTime(2026, 9, 8))..title = 'Today’s small discoveries',
  };
  // Text-only saves keep golden fixtures independent of network favicon loading.
  for (final url in urls.values) {
    url.rawUrl = 'glimpse:${url.id}';
    url.domain = '';
  }

  final activity = buildGlimpseActivity((
    urls.values.toList(),
    DateTime(2026, 9, 8, 21),
  ));
  final recaps = buildGlimpses(
    GlimpseBuildRequest(urls.values.toList(), [], activity.now),
  );
  final weekly = recaps.firstWhere((g) => g.key == 'weekly:2026-09-07');
  final daily = recaps.firstWhere((g) => g.key == 'daily:2026-09-08');
  final connection = Glimpse.fromJson({
    ...candidate(
      kind: GlimpseKind.connection,
      key: 'connection:2:1',
      ids: [2, 1],
    ).toJson(),
    'evidence': idea.evidence.map((e) => e.toJson()).toList(),
  });

  Widget scope(Widget child, _Service service) => ProviderScope(
    overrides: [
      prepareWeeklyReviewProvider.overrideWith((ref) async {}),
      weeklyReviewEnabledProvider.overrideWith((ref) async => false),
      glimpsesProvider.overrideWith(
        (ref) async => [
          stored(idea),
          stored(weekly),
          stored(daily),
          stored(connection),
        ],
      ),
      glimpseSourcesProvider.overrideWith((ref) async => urls),
      glimpseServiceProvider.overrideWithValue(service),
      glimpseActivityProvider.overrideWith((ref) async => activity),
    ],
    child: child,
  );

  for (final dark in [false, true]) {
    testWidgets(
      'notification cards ${dark ? 'dark' : 'light'} use compact accented footers',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark
                ? AppTheme.darkTheme(const Color(0xFF6750A4))
                : AppTheme.lightTheme(const Color(0xFF6750A4)),
            home: RepaintBoundary(
              key: const ValueKey('notifications'),
              child: Scaffold(
                appBar: AppBar(title: const Text('Notifications')),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final (type, title, body) in [
                      (
                        'glimpse',
                        'Making reversible decisions',
                        'Separate reversible choices from irreversible choices before deciding.',
                      ),
                      (
                        'resurface',
                        'An earlier idea worth revisiting',
                        'A passage you highlighted about making space for focused work.',
                      ),
                      (
                        'new_interest',
                        'A new thread: decision making',
                        'Read these earlier ideas alongside your latest save.',
                      ),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: CuratedNotificationListTile(
                          entry: {
                            'type': type,
                            'topic': title,
                            'body': body,
                            'date': '2026-09-09',
                            'read': type == 'resurface',
                          },
                          sources: type == 'new_interest'
                              ? [urls[1]!, urls[2]!, urls[3]!, urls[4]!]
                              : const [],
                          onClear: () {},
                          onTap: () {},
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('+2'), findsOneWidget);
        expect(find.text('Clear'), findsNothing);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('notifications')),
          matchesGoldenFile(
            'goldens/notifications_compact_${dark ? 'dark' : 'light'}.png',
          ),
        );
        tester.view.physicalSize = const Size(360, 800);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'weekly summary settings ${dark ? 'dark' : 'light'} persists toggle',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: dark
                  ? AppTheme.darkTheme(const Color(0xFF6750A4))
                  : AppTheme.lightTheme(const Color(0xFF6750A4)),
              home: Consumer(
                builder: (context, ref, _) => Scaffold(
                  body: TextButton(
                    onPressed: () => showWeeklyReviewSettings(context, ref),
                    child: const Text('Open settings'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open settings'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Weekly AI summary'), findsOneWidget);
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          false,
        );
        expect(await WeeklyReviewPreferences.enabled(), false);
        await expectLater(
          find.byType(BottomSheet),
          matchesGoldenFile(
            'goldens/glimpse_settings_${dark ? 'dark' : 'light'}.png',
          ),
        );
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(await WeeklyReviewPreferences.enabled(), true);
        Navigator.of(tester.element(find.byType(SwitchListTile))).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open settings'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          true,
        );
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(await WeeklyReviewPreferences.enabled(), false);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('Your Glimpses ${dark ? 'dark' : 'light'} monthly layout', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        scope(
          MaterialApp(
            theme: dark
                ? AppTheme.darkTheme(const Color(0xFF6750A4))
                : AppTheme.lightTheme(const Color(0xFF6750A4)),
            home: const RepaintBoundary(
              key: ValueKey('history'),
              child: GlimpseHistoryScreen(),
            ),
          ),
          _Service(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final name in [
          'music',
          'food',
          'science',
          'philosophy',
          'general',
        ]) {
          await precacheImage(
            ResizeImage(
              AssetImage('assets/rediscover/illustrations/$name.webp'),
              width: 36,
            ),
            tester.element(find.byType(GlimpseHistoryScreen)),
          );
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final dayStyle = tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('glimpse-selected-day')),
          )
          .style!;
      final luminances = [
        dayStyle.backgroundColor!.resolve({})!.computeLuminance(),
        dayStyle.foregroundColor!.resolve({})!.computeLuminance(),
      ]..sort();
      expect(
        (luminances.last + .05) / (luminances.first + .05),
        greaterThanOrEqualTo(4.5),
      );
      await expectLater(
        find.byKey(const ValueKey('history')),
        matchesGoldenFile(
          'goldens/glimpse_history_${dark ? 'dark' : 'light'}.png',
        ),
      );
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text('August 2026'), findsOneWidget);
      expect(find.text('Weekly review'), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Previous month',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'Rediscover ${dark ? 'dark' : 'light'} leads with useful saves',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          scope(
            MaterialApp(
              theme: dark
                  ? AppTheme.darkTheme(const Color(0xFF6750A4))
                  : AppTheme.lightTheme(const Color(0xFF6750A4)),
              home: const RepaintBoundary(
                key: ValueKey('glimpses'),
                child: GlimpsesScreen(),
              ),
            ),
            _Service(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          for (final name in [
            'music',
            'food',
            'science',
            'philosophy',
            'general',
          ]) {
            await precacheImage(
              ResizeImage(
                AssetImage('assets/rediscover/illustrations/$name.webp'),
                width: 112,
              ),
              tester.element(find.byType(GlimpsesScreen)),
            );
          }
        });
        await tester.pumpAndSettle();
        expect(find.text('Your Glimpses'), findsOneWidget);
        expect(find.text('Rediscover'), findsOneWidget);
        expect(find.text('Saves by day'), findsNothing);
        expect(find.text('Top topics'), findsNothing);
        expect(find.text('Weekly review'), findsOneWidget);
        expect(find.text('Expand this brief'), findsNothing);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('glimpses')),
          matchesGoldenFile('goldens/glimpses_${dark ? 'dark' : 'light'}.png'),
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('large German text remains usable on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      scope(
        MaterialApp(
          locale: const Locale('de'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const GlimpsesScreen(),
        ),
        _Service(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GlimpsesScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      scope(
        MaterialApp(
          locale: const Locale('de'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const GlimpseHistoryScreen(),
        ),
        _Service(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final action in [GlimpseAction.later, GlimpseAction.lessLikeThis]) {
    testWidgets('Rediscover menu sends $action without opening the save', (
      tester,
    ) async {
      final service = _Service();
      await tester.pumpWidget(
        scope(const MaterialApp(home: GlimpsesScreen()), service),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(GlimpseCardMenu).first);
      await tester.pumpAndSettle();
      expect(find.text('Set aside for three days'), findsOneWidget);
      await tester.tap(
        find.text(action == GlimpseAction.later ? 'Not now' : 'Less like this'),
      );
      await tester.pumpAndSettle();
      expect(service.actions, [action]);
      expect(find.byType(GlimpseDetailScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('single notification opens save directly and Back returns Home', (
    tester,
  ) async {
    final service = _Service();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Home root')),
        ),
        GoRoute(
          path: '/url/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Save ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/glimpses/detail',
          builder: (_, state) =>
              GlimpseDetailScreen(glimpseKey: state.extra as String),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      scope(MaterialApp.router(routerConfig: router), service),
    );
    await tester.pumpAndSettle();
    NotificationRouter.openFromPayload(
      tester.element(find.text('Home root')),
      '{"route":"glimpse","glimpseKey":"idea:1","linkIds":[1]}',
    );
    await tester.pumpAndSettle();
    expect(find.text('Save 1'), findsOneWidget);
    expect(find.byType(GlimpseDetailScreen), findsNothing);
    expect(service.actions, [GlimpseAction.opened]);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Home root'), findsOneWidget);
  });
  testWidgets('multi-save notification opens the collective brief', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Home root')),
        ),
        GoRoute(
          path: '/glimpses/detail',
          builder: (_, state) =>
              GlimpseDetailScreen(glimpseKey: state.extra as String),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      scope(MaterialApp.router(routerConfig: router), _Service()),
    );
    await tester.pumpAndSettle();
    NotificationRouter.openFromPayload(
      tester.element(find.text('Home root')),
      '{"route":"glimpse","glimpseKey":"weekly:2026-09-07","linkIds":[2,3]}',
    );
    await tester.pumpAndSettle();
    expect(find.text('Weekly review'), findsWidgets);
    expect(find.text('Start here'), findsOneWidget);
    expect(find.text('Expand this brief'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Explore these saves'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Explore these saves'), findsOneWidget);
  });

  testWidgets('Clear appears only during swipe and does not open the save', (
    tester,
  ) async {
    var opened = 0;
    var cleared = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CuratedNotificationListTile(
            entry: const {
              'type': 'glimpse',
              'topic': 'Worth revisiting',
              'body': 'An earlier idea',
            },
            onTap: () => opened++,
            onClear: () => cleared++,
          ),
        ),
      ),
    );
    expect(find.text('Clear'), findsNothing);
    await tester.tap(find.text('Worth revisiting'));
    expect(opened, 1);
    final card = find.byType(PremiumSwipeCard);
    final gesture = await tester.startGesture(tester.getCenter(card));
    await gesture.moveBy(const Offset(-20, 0));
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    expect(find.text('Clear'), findsOneWidget);
    expect(cleared, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(cleared, 0);
    expect(find.text('Clear'), findsNothing);
    await tester.drag(card, Offset(-tester.getSize(card).width * .8, 0));
    await tester.pumpAndSettle();
    expect(cleared, 1);
    expect(opened, 1);
  });

  testWidgets('grouped notification previews survive Clear and Undo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await DigestPrefs.addDigestToHistory(
      ids: [1],
      summaries: [],
      topic: 'Single save',
      notifId: 'single',
    );
    await DigestPrefs.addDigestToHistory(
      ids: [2, 1, 3, 4, 2, 999],
      summaries: [],
      topic: 'Related saves',
      notifId: 'group',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          urlStreamProvider.overrideWith(
            (ref) => Stream.value(urls.values.toList()),
          ),
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Clear'), findsNothing);
    expect(find.byType(CuratedNotificationThumbStack), findsOneWidget);
    expect(
      tester
          .widget<CuratedNotificationThumbStack>(
            find.byType(CuratedNotificationThumbStack),
          )
          .urls
          .map((u) => u.id),
      [2, 1, 3, 4],
    );
    expect(find.text('+2'), findsOneWidget);
    expect(find.byType(CuratedNotificationThumbStripItem), findsNWidgets(2));
    final group = find.ancestor(
      of: find.text('Related saves'),
      matching: find.byType(PremiumSwipeCard),
    );
    await tester.drag(group, Offset(-tester.getSize(group).width * .8, 0));
    await tester.pumpAndSettle();
    expect(find.text('Related saves'), findsNothing);
    expect(find.text('Single save'), findsOneWidget);
    expect((await DigestPrefs.loadHistory()).length, 1);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Related saves'), findsOneWidget);
    expect(find.byType(CuratedNotificationThumbStack), findsOneWidget);
    expect((await DigestPrefs.loadHistory()).first['topic'], 'Related saves');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'selected day opens only that day and topic opens only its saves',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GlimpsePeriodOverview(
                period: activity.month(activity.now),
                now: activity.now,
                showChart: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chartButton = find.descendant(
        of: find.byType(GlimpseActivityChart),
        matching: find.byKey(const ValueKey('glimpse-selected-day')),
      );
      await tester.ensureVisible(chartButton);
      await tester.tap(chartButton);
      await tester.pumpAndSettle();
      expect(find.text('Today’s small discoveries'), findsOneWidget);
      expect(find.text('Recipe 7'), findsOneWidget);
      expect(find.text('Quantum physics 15'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(3));
      Navigator.of(tester.element(find.text('Recipe 7'))).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Recipes & Cooking'));
      await tester.tap(find.text('Recipes & Cooking'));
      await tester.pumpAndSettle();
      expect(find.text('Recipe 4'), findsOneWidget);
      expect(find.text('Music 5'), findsNothing);
      expect(
        tester
            .widget<ListView>(find.byType(ListView))
            .childrenDelegate
            .estimatedChildCount,
        11,
      );
      await tester.scrollUntilVisible(
        find.text('Recipe 16'),
        100,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Recipe 16'), findsOneWidget);
    },
  );
  testWidgets('history has activity without the repeated summary banner', (
    tester,
  ) async {
    await tester.pumpWidget(
      scope(MaterialApp(home: const GlimpseHistoryScreen()), _Service()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Saves by day'), findsOneWidget);
    expect(find.text('Top topics'), findsOneWidget);
    expect(find.textContaining('Topics included'), findsNothing);
    expect(find.byType(Card), findsNothing);
  });
  for (final dark in [false, true]) {
    testWidgets(
      'Rediscover detail ${dark ? 'dark' : 'light'} preserves why and starting save',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          scope(
            MaterialApp(
              theme: dark
                  ? AppTheme.darkTheme(const Color(0xFF6750A4))
                  : AppTheme.lightTheme(const Color(0xFF6750A4)),
              home: const RepaintBoundary(
                key: ValueKey('detail'),
                child: GlimpseDetailScreen(glimpseKey: 'connection:2:1'),
              ),
            ),
            _Service(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await precacheImage(
            const ResizeImage(
              AssetImage('assets/rediscover/illustrations/philosophy.webp'),
              width: 132,
            ),
            tester.element(find.byType(GlimpseDetailScreen)),
          );
        });
        await tester.pumpAndSettle();
        expect(find.text('Why today'), findsOneWidget);
        expect(find.text('Start here'), findsOneWidget);
        expect(find.text('Making reversible decisions'), findsOneWidget);
        expect(find.text('A week of useful ideas'), findsOneWidget);
        expect(find.text('Expand this brief'), findsNothing);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('detail')),
          matchesGoldenFile(
            'goldens/glimpse_detail_${dark ? 'dark' : 'light'}.png',
          ),
        );
      },
    );
  }
}
