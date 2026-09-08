import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/features/mindmap/cluster_card.dart';
import 'package:glimpse/features/mindmap/cluster_theme.dart';
import 'package:glimpse/features/mindmap/interest_clusters_provider.dart';
import 'package:glimpse/features/mindmap/mindmap_screen.dart';
import 'package:glimpse/shared/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import 'fixtures/interest_merge_fixtures.dart';

const _goldenBoundaryKey = ValueKey('interests-golden-boundary');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    final instrumentSans = FontLoader('Instrument Sans')
      ..addFont(rootBundle.load('assets/fonts/InstrumentSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/InstrumentSans-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/InstrumentSans-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/InstrumentSans-Bold.ttf'));
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    final phosphorIcons = FontLoader('packages/phosphor_flutter/PhosphorBold')
      ..addFont(
        rootBundle.load(
          'packages/phosphor_flutter/lib/fonts/Phosphor-Bold.ttf',
        ),
      );
    await Future.wait([
      instrumentSans.load(),
      materialIcons.load(),
      phosphorIcons.load(),
      (FontLoader('packages/phosphor_flutter/PhosphorFill')..addFont(
            rootBundle.load(
              'packages/phosphor_flutter/lib/fonts/Phosphor-Fill.ttf',
            ),
          ))
          .load(),
    ]);
  });

  testWidgets('defers the initial interest load until after the first frame', (
    tester,
  ) async {
    var loadCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          interestClusterThemesProvider.overrideWith((ref) async {
            loadCount++;
            return _fixtureThemes();
          }),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const MindmapScreen(embedded: true),
        ),
      ),
    );

    expect(loadCount, 0);

    await tester.pump();

    expect(loadCount, 1);
  });

  testWidgets('embedded interests stay above the shell navigation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final themes = List.generate(
      12,
      (index) => ClusterTheme(
        index: index,
        label: 'Interest ${index + 1}',
        summary: '',
        urls: List.generate(
          3,
          (urlIndex) => _savedUrl(index * 3 + urlIndex + 1),
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          interestClusterThemesProvider.overrideWith((ref) async => themes),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            extendBody: true,
            body: const MindmapScreen(embedded: true),
            bottomNavigationBar: NavigationBar(
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.interests_outlined),
                  label: 'Interests',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_outlined),
                  label: 'Search',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -10000));
    await tester.pumpAndSettle();

    final lastInterestRect = tester.getRect(find.text('Interest 12'));
    final navigationRect = tester.getRect(find.byType(NavigationBar));
    expect(lastInterestRect.bottom, lessThanOrEqualTo(navigationRect.top));
    expect(find.byTooltip('Rebuild map'), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Rebuild map'), findsOneWidget);
  });

  testWidgets('header, sections, and cards share the responsive grid', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpInterests(tester, themes: _fixtureThemes());

    final interestsTitle = tester.widget<Text>(find.text('Interests'));
    final titleContext = tester.element(find.text('Interests'));
    expect(
      interestsTitle.style?.fontSize,
      Theme.of(titleContext).textTheme.titleLarge?.fontSize,
    );
    expect(tester.getTopLeft(find.text('Interests')).dx, closeTo(16, 0.1));
    expect(tester.getTopLeft(find.text('Top signal')).dx, closeTo(16, 0.1));
    expect(
      tester.getTopLeft(find.byType(ClusterCard).first).dx,
      closeTo(16, 0.1),
    );

    tester.view.physicalSize = const Size(1000, 900);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpInterests(tester, themes: _fixtureThemes());

    const centeredInset = 120.0;
    expect(
      tester.getTopLeft(find.text('Interests')).dx,
      closeTo(centeredInset, 0.1),
    );
    expect(
      tester.getTopLeft(find.text('Top signal')).dx,
      closeTo(centeredInset, 0.1),
    );
    expect(
      tester.getTopLeft(find.byType(ClusterCard).first).dx,
      closeTo(centeredInset, 0.1),
    );
  });

  testWidgets('masonry balances fixed title-scale cards by rendered height', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpInterests(tester, themes: _fixtureThemes(includeFourth: true));

    final strong = _cardRect(tester, 'Dev Tools & OSS');
    final medium = _cardRect(tester, 'Product Design');
    final compact = _cardRect(tester, 'Nutrition & Wellness');
    final quietGrowing = _cardRect(tester, 'Startup Building');

    expect(strong.left, closeTo(quietGrowing.left, 0.1));
    expect(medium.left, closeTo(compact.left, 0.1));
    expect(strong.left, lessThan(medium.left));
    expect(quietGrowing.top, greaterThan(strong.bottom));
    expect(compact.top, greaterThan(medium.bottom));
  });

  testWidgets('header distinguishes grouped saves from total saves scanned', (
    tester,
  ) async {
    final themes = [
      ClusterTheme(
        index: 0,
        label: 'Recurring Topic',
        summary: '',
        urls: [_savedUrl(1), _savedUrl(2), _savedUrl(3)],
      ),
      ClusterTheme(
        index: 1,
        label: 'One-off Topic',
        summary: '',
        urls: [_savedUrl(4)],
      ),
    ];

    await _pumpInterests(tester, themes: themes);

    expect(find.text('1 pattern · 3 of 4 saves grouped'), findsOneWidget);
  });

  testWidgets('merged interest rows open their matching details', (
    tester,
  ) async {
    final themes = [
      _theme(index: 0, label: 'Top Signal', firstUrlId: 1, urlCount: 12),
      _theme(index: 1, label: 'Spirituality', firstUrlId: 20, urlCount: 10),
      _theme(index: 2, label: 'Wildlife & Nature', firstUrlId: 40, urlCount: 4),
      _theme(index: 3, label: 'Wildlife & Nature', firstUrlId: 50, urlCount: 4),
      _theme(index: 4, label: 'Music', firstUrlId: 60, urlCount: 6),
      _theme(
        index: 5,
        label: 'Finance & Economics',
        firstUrlId: 70,
        urlCount: 5,
      ),
    ];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const MindmapScreen(embedded: true),
        ),
        GoRoute(
          path: '/mindmap/cluster/:id',
          builder: (_, state) => MindmapClusterScreen(
            clusterId: int.parse(state.pathParameters['id']!),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          interestClusterThemesProvider.overrideWith((ref) async => themes),
        ],
        child: MaterialApp.router(
          theme: ThemeData(useMaterial3: true),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Music'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Music'));
    await tester.pumpAndSettle();

    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Wildlife & Nature'), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Finance & Economics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finance & Economics'));
    await tester.pumpAndSettle();

    expect(find.text('Finance & Economics'), findsOneWidget);
    expect(find.text('Music'), findsNothing);
  });

  testWidgets(
    'wildlife remains visible and opens its own saves after travel mentions',
    (tester) async {
      final themes = interestThemesWithIncidentalTravel();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const MindmapScreen(embedded: true),
          ),
          GoRoute(
            path: '/mindmap/cluster/:id',
            builder: (_, state) => MindmapClusterScreen(
              clusterId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            interestClusterThemesProvider.overrideWith((ref) async => themes),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: true),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Spirituality'), findsOneWidget);
      expect(find.text('Wildlife & Nature'), findsOneWidget);
      await tester.ensureVisible(find.text('Wildlife & Nature'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wildlife & Nature'));
      await tester.pumpAndSettle();
      expect(find.text('Wildlife & Nature'), findsOneWidget);
      expect(find.text('Puffling Rescue Patrol'), findsWidgets);
      expect(find.text('Reflection'), findsNothing);
    },
  );

  testWidgets('AMOLED interests overview', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpInterests(
      tester,
      themes: _fixtureThemes(),
      theme: AppTheme.amoledTheme(const Color(0xFF6750A4)),
      goldenBoundary: true,
    );

    await _expectInterestsGolden(tester, 'goldens/interests_amoled.png');
  });
}

Future<void> _pumpInterests(
  WidgetTester tester, {
  required List<ClusterTheme> themes,
  ThemeData? theme,
  bool goldenBoundary = false,
}) async {
  final screen = goldenBoundary
      ? const RepaintBoundary(
          key: _goldenBoundaryKey,
          child: MindmapScreen(embedded: true),
        )
      : const MindmapScreen(embedded: true);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        interestClusterThemesProvider.overrideWith((ref) async => themes),
      ],
      child: MaterialApp(
        theme: theme ?? ThemeData(useMaterial3: true),
        home: screen,
      ),
    ),
  );
  if (theme != null) {
    await tester.runAsync(GoogleFonts.pendingFonts);
  }
  await tester.pumpAndSettle();
}

Future<void> _expectInterestsGolden(WidgetTester tester, String path) async {
  for (final element in tester.allElements) {
    element.renderObject?.markNeedsPaint();
  }
  await tester.pump();
  await expectLater(find.byKey(_goldenBoundaryKey), matchesGoldenFile(path));
}

List<ClusterTheme> _fixtureThemes({bool includeFourth = false}) {
  final fixtures = <(String, int, List<String>)>[
    ('Website Growth', 17, ['SEO', 'Revenue']),
    ('Dev Tools & OSS', 15, ['GitHub', 'OSS']),
    ('Product Design', 8, ['UI', 'UX']),
    ('Nutrition & Wellness', 5, ['Protein', 'Vegetarian']),
    if (includeFourth) ('Startup Building', 4, ['Marketing', 'Storytelling']),
  ];
  var nextId = 1;
  return [
    for (var index = 0; index < fixtures.length; index++)
      ClusterTheme(
        index: index,
        label: fixtures[index].$1,
        summary: '',
        urls: List.generate(
          fixtures[index].$2,
          (_) => _savedUrl(nextId++, tags: fixtures[index].$3),
        ),
      ),
  ];
}

Rect _cardRect(WidgetTester tester, String label) {
  final card = find.ancestor(
    of: find.text(label),
    matching: find.byType(ClusterCard),
  );
  return tester.getRect(card);
}

SavedUrl _savedUrl(int id, {List<String> tags = const ['Topic']}) {
  return SavedUrl()
    ..id = id
    ..rawUrl = 'https://example.com/$id'
    ..domain = 'example.com'
    ..title = 'Saved item $id'
    ..description = ''
    ..category = 'Other'
    ..categoryEmoji = '🔖'
    ..categories = const ['Other']
    ..tags = tags
    ..savedAt = DateTime(2026);
}

ClusterTheme _theme({
  required int index,
  required String label,
  required int firstUrlId,
  required int urlCount,
}) {
  return ClusterTheme(
    index: index,
    label: label,
    summary: '',
    urls: List.generate(urlCount, (offset) => _savedUrl(firstUrlId + offset)),
  );
}
