import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/mindmap/cluster_pattern.dart';
import 'package:glimpse/features/mindmap/cluster_pattern_library.dart';
import 'package:glimpse/shared/theme/app_theme.dart';

const _contactSheetKey = ValueKey('interest-pattern-contact-sheet');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final instrumentSans = FontLoader('Instrument Sans')
      ..addFont(rootBundle.load('assets/fonts/InstrumentSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/InstrumentSans-SemiBold.ttf'));
    await instrumentSans.load();
  });

  test('routes every supported interest into its procedural grammar', () {
    const cases = <String, (String, PatternGrammar)>{
      'Nutrition & Wellness': ('food-nutrition', PatternGrammar.contourRings),
      'Healthy Recipes': ('cooking-recipes', PatternGrammar.contourRings),
      'Fitness': ('fitness', PatternGrammar.kineticTrack),
      'Mindfulness': ('wellness', PatternGrammar.concentricGeometry),
      'Movie Recommendations': ('movies', PatternGrammar.synthwave),
      'TV Series': ('tv-shows', PatternGrammar.synthwave),
      'Anime': ('anime-comics', PatternGrammar.synthwave),
      'Books & Essays': ('books-reading', PatternGrammar.editorialGrid),
      'Writing & Journaling': ('writing', PatternGrammar.editorialGrid),
      'Dev Tools & OSS': ('programming', PatternGrammar.circuitGrid),
      'AI Agents': ('artificial-intelligence', PatternGrammar.circuitGrid),
      'Gizmos & Gadgets': ('technology-gadgets', PatternGrammar.circuitGrid),
      'Design Systems': ('design', PatternGrammar.apertureFrames),
      'Photography': ('photography', PatternGrammar.apertureFrames),
      'Wildlife': ('wildlife', PatternGrammar.topographicMesh),
      'Trekking & Nature': ('nature-outdoors', PatternGrammar.topographicMesh),
      'Gardening': ('gardening', PatternGrammar.topographicMesh),
      'Travel Plans': ('travel', PatternGrammar.topographicMesh),
      'Investing': ('finance', PatternGrammar.dataGraph),
      'Website Growth': ('business', PatternGrammar.dataGraph),
      'Education': ('education', PatternGrammar.orbital),
      'Science & Research': ('science', PatternGrammar.orbital),
      'Astronomy': ('astronomy-space', PatternGrammar.orbital),
      'Music': ('music', PatternGrammar.waveform),
      'Podcasts': ('podcasts', PatternGrammar.waveform),
      'Gaming': ('gaming', PatternGrammar.synthwave),
      'Sports': ('sports', PatternGrammar.kineticTrack),
      'Cricket': ('cricket', PatternGrammar.kineticTrack),
      'Football': ('football', PatternGrammar.kineticTrack),
      'Formula 1': ('motorsport', PatternGrammar.kineticTrack),
      'Cycling': ('cycling', PatternGrammar.kineticTrack),
      'Fashion': ('fashion', PatternGrammar.ribbonMesh),
      'Beauty': ('beauty', PatternGrammar.ribbonMesh),
      'Pets': ('pets', PatternGrammar.organicCells),
      'Home Decor': ('home-interiors', PatternGrammar.architecturalBlueprint),
      'DIY Projects': ('diy-tools', PatternGrammar.architecturalBlueprint),
      'Automotive': ('automotive', PatternGrammar.kineticTrack),
      'Motorcycles': ('motorcycles', PatternGrammar.kineticTrack),
      'Productivity': ('productivity', PatternGrammar.circuitGrid),
      'Minimalism': ('minimalism', PatternGrammar.sparseGeometry),
      'Philosophy': ('philosophy', PatternGrammar.concentricGeometry),
      'Psychology': ('psychology', PatternGrammar.concentricGeometry),
      'History': ('history', PatternGrammar.editorialGrid),
      'Language Learning': ('languages', PatternGrammar.editorialGrid),
      'News': ('news', PatternGrammar.dataGraph),
      'Sustainability': ('sustainability', PatternGrammar.topographicMesh),
    };

    final reachedGrammars = <PatternGrammar>{};
    for (final entry in cases.entries) {
      final selection = resolveClusterPattern(
        label: entry.key,
        subtopics: const [],
      );
      expect(
        selection.categoryIds,
        contains(entry.value.$1),
        reason: entry.key,
      );
      expect(selection.recipe.grammar, entry.value.$2, reason: entry.key);
      expect(selection.isFallback, isFalse, reason: entry.key);
      reachedGrammars.add(selection.recipe.grammar);
    }

    expect(reachedGrammars, containsAll(PatternGrammar.values));
  });

  test('combines relevant categories while using the strongest recipe', () {
    final selection = resolveClusterPattern(
      label: 'Healthy Recipes',
      subtopics: const ['Nutrition', 'Cooking'],
    );

    expect(selection.categoryIds, contains('food-nutrition'));
    expect(selection.categoryIds, contains('cooking-recipes'));
    expect(selection.recipe.grammar, PatternGrammar.contourRings);
  });

  test('weights the primary label above a noisy subtopic', () {
    final selection = resolveClusterPattern(
      label: 'Dev Tools & OSS',
      subtopics: const ['Food & Cooking'],
    );

    expect(selection.categoryIds.first, 'programming');
    expect(selection.categoryIds, isNot(contains('cooking-recipes')));
    expect(selection.recipe.grammar, PatternGrammar.circuitGrid);
  });

  test('uses local semantic similarity before abstract fallback', () {
    final selection = resolveClusterPattern(
      label: 'Computing Internals',
      subtopics: const [],
    );

    expect(selection.categoryIds, contains('technology-gadgets'));
    expect(selection.recipe.grammar, PatternGrammar.circuitGrid);
    expect(selection.isFallback, isFalse);
  });

  test('unknown interests receive the sparse geometric fallback', () {
    final selection = resolveClusterPattern(
      label: 'Qzxv Plmnr',
      subtopics: const [],
    );

    expect(selection.categoryIds, const ['abstract']);
    expect(selection.recipe, same(abstractPatternRecipe));
    expect(selection.recipe.grammar, PatternGrammar.sparseGeometry);
    expect(selection.isFallback, isTrue);
  });

  test('recipe and seeded variation are deterministic per interest', () {
    final first = resolveClusterPattern(
      label: 'Movie Recommendations',
      subtopics: const ['Cinema'],
    );
    final repeated = resolveClusterPattern(
      label: 'Movie Recommendations',
      subtopics: const ['Cinema'],
    );
    final different = resolveClusterPattern(
      label: 'Classic Movie Recommendations',
      subtopics: const ['Cinema'],
    );

    expect(repeated.signature, first.signature);
    expect(repeated.recipe, same(first.recipe));
    expect(different.recipe.grammar, first.recipe.grammar);
    expect(different.seed, isNot(first.seed));
    expect(different.signature, isNot(first.signature));
  });

  test('library entries retain complete semantic recipe metadata', () {
    final ids = <String>{};
    for (final category in clusterPatternLibrary) {
      expect(ids.add(category.id), isTrue, reason: category.id);
      expect(category.aliases, isNotEmpty, reason: category.id);
      expect(category.recipe.density, inInclusiveRange(0, 1));
      expect(category.recipe.scale, greaterThan(0));
    }
    expect(clusterPatternLibrary, hasLength(46));
  });

  testWidgets('procedural grammar contact sheet — light', (tester) async {
    await _pumpContactSheet(
      tester,
      theme: AppTheme.lightTheme(const Color(0xFF6750A4)),
    );
    await _expectGolden(tester, 'goldens/interest_patterns_light.png');
  });

  testWidgets('procedural grammar contact sheet — AMOLED', (tester) async {
    await _pumpContactSheet(
      tester,
      theme: AppTheme.amoledTheme(const Color(0xFF6750A4)),
    );
    await _expectGolden(tester, 'goldens/interest_patterns_amoled.png');
  });
}

const _grammarExamples = <(String, PatternGrammar)>[
  ('AI Agents', PatternGrammar.circuitGrid),
  ('Website Growth', PatternGrammar.dataGraph),
  ('Trekking & Nature', PatternGrammar.topographicMesh),
  ('Music', PatternGrammar.waveform),
  ('Movie Recommendations', PatternGrammar.synthwave),
  ('Astronomy', PatternGrammar.orbital),
  ('Formula 1', PatternGrammar.kineticTrack),
  ('Books & Essays', PatternGrammar.editorialGrid),
  ('Psychology', PatternGrammar.concentricGeometry),
  ('Photography', PatternGrammar.apertureFrames),
  ('Fashion', PatternGrammar.ribbonMesh),
  ('Nutrition', PatternGrammar.contourRings),
  ('Home Decor', PatternGrammar.architecturalBlueprint),
  ('Pets', PatternGrammar.organicCells),
  ('Minimalism', PatternGrammar.sparseGeometry),
];

Future<void> _pumpContactSheet(
  WidgetTester tester, {
  required ThemeData theme,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(960, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: RepaintBoundary(
        key: _contactSheetKey,
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var index = 0; index < _grammarExamples.length; index++)
                  _PatternPreview(
                    label: _grammarExamples[index].$1,
                    expectedGrammar: _grammarExamples[index].$2,
                    toneIndex: index,
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expectGolden(WidgetTester tester, String path) async {
  for (final element in tester.allElements) {
    element.renderObject?.markNeedsPaint();
  }
  await tester.pump();
  await expectLater(find.byKey(_contactSheetKey), matchesGoldenFile(path));
}

class _PatternPreview extends StatelessWidget {
  const _PatternPreview({
    required this.label,
    required this.expectedGrammar,
    required this.toneIndex,
  });

  final String label;
  final PatternGrammar expectedGrammar;
  final int toneIndex;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selection = resolveClusterPattern(label: label, subtopics: const []);
    assert(selection.recipe.grammar == expectedGrammar);
    final tones = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
    ];
    final tone = tones[toneIndex % tones.length];
    final surface = colorScheme.surfaceContainerLow;
    final isDark = colorScheme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 298,
        height: 160,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Color.alphaBlend(
                      tone.withValues(alpha: isDark ? 0.085 : 0.065),
                      surface,
                    ),
                    surface,
                    surface,
                  ],
                  stops: const [0, 0.58, 1],
                ),
              ),
            ),
            CustomPaint(
              painter: ClusterPatternPainter(
                selection: selection,
                tone: tone,
                surface: surface,
                baseOpacity: isDark ? 0.09 : 0.082,
                contentSafeRegion: const PatternSafeRegion(
                  left: 0.04,
                  top: 0.42,
                  right: 0.96,
                  bottom: 1,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    selection.recipe.grammar.name,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
