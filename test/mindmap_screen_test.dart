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
    await Future.wait([instrumentSans.load(), materialIcons.load()]);
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
  });

  testWidgets('header, sections, and cards share the responsive grid', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpInterests(tester, themes: _fixtureThemes());

    expect(tester.getTopLeft(find.text('Interests')).dx, closeTo(20, 0.1));
    expect(tester.getTopLeft(find.text('Top signal')).dx, closeTo(20, 0.1));
    expect(
      tester.getTopLeft(find.byType(ClusterCard).first).dx,
      closeTo(20, 0.1),
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
