import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/mindmap/cluster_card.dart';
import 'package:glimpse/features/rediscover/journey_visual.dart';
import 'package:glimpse/features/rediscover/rediscover_journey_provider.dart';
import 'package:glimpse/shared/theme/app_theme.dart';
import 'package:glimpse/features/url_detail/reader_selectable_text.dart';
import 'package:glimpse/core/services/saved_highlights_service.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    for (final (family, asset) in [
      ('Instrument Sans', 'assets/fonts/InstrumentSans-Regular.ttf'),
      ('Newsreader', 'assets/fonts/Newsreader-SemiBold.ttf'),
      (
        'packages/phosphor_flutter/PhosphorRegular',
        'packages/phosphor_flutter/lib/fonts/Phosphor.ttf',
      ),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });

  final themes = {
    'light': AppTheme.lightTheme(const Color(0xFF6750A4)),
    'dark': AppTheme.darkTheme(const Color(0xFF6750A4)),
    'green_dark': AppTheme.darkTheme(const Color(0xFF146C2E)),
    'amoled': AppTheme.amoledTheme(const Color(0xFF6750A4)),
    'monochrome_light': AppTheme.lightTheme(
      const Color(0xFF5F6368),
      schemeVariant: DynamicSchemeVariant.monochrome,
    ),
    'monochrome_dark': AppTheme.darkTheme(
      const Color(0xFF5F6368),
      schemeVariant: DynamicSchemeVariant.monochrome,
    ),
    'monochrome_amoled': AppTheme.amoledTheme(
      const Color(0xFF5F6368),
      schemeVariant: DynamicSchemeVariant.monochrome,
    ),
  };

  testWidgets('complete illustration library stays legible inside shapes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 1050);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: themes['light'],
        home: RepaintBoundary(
          key: const ValueKey('artwork-library'),
          child: Scaffold(
            body: GridView.count(
              crossAxisCount: 3,
              childAspectRatio: 1.15,
              children: [
                for (final artwork in RediscoverArtworkTheme.values)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RediscoverIllustration(artwork: artwork, size: 132),
                      const SizedBox(height: 6),
                      Text(artwork.name),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(GoogleFonts.pendingFonts);
    for (final image in tester.widgetList<Image>(find.byType(Image))) {
      await tester.runAsync(
        () => precacheImage(image.image, tester.element(find.byType(Scaffold))),
      );
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('artwork-library')),
      matchesGoldenFile('goldens/rediscover_illustrations.png'),
    );
  });

  for (final entry in themes.entries) {
    testWidgets('textured discovery ${entry.key}', (tester) async {
      final monochrome = entry.key.startsWith('monochrome');
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = monochrome
          ? const Size(360, 1150)
          : const Size(400, 850);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: entry.value,
          home: RepaintBoundary(
            key: const ValueKey('discovery'),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Text('Rediscover', style: entry.value.textTheme.titleLarge),
                    const SizedBox(height: 16),
                    _card(
                      monochrome ? 'Reading Recommendations' : 'Weekend trails',
                      monochrome ? 'books' : 'travel',
                      'A few places you saved for your next trip.',
                      '3 saves · From your past',
                    ),
                    const SizedBox(height: 12),
                    _card(
                      'Recipes to try',
                      'food',
                      'Come back to the meals you wanted to make.',
                      '5 saves · Still waiting',
                    ),
                    const SizedBox(height: 24),
                    Text('Interests', style: entry.value.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    if (monochrome) ...[
                      ClusterCard(
                        cluster: _interest('Software & AI', 20, [
                          'AI',
                          'Coding',
                        ]),
                        tier: ClusterCardTier.hero,
                        onTap: () {},
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Key takeaways',
                        style: entry.value.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      ReaderSelectableText(
                        text:
                            'Shark mentality: Maintain constant movement and growth to avoid the downfall that comes with stagnation.',
                        sectionKey: 'takeaway',
                        style: entry.value.textTheme.bodyLarge?.copyWith(
                          color: entry.value.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                        highlights: [
                          SavedHighlightsCodec.create(
                            id: 'highlight',
                            sectionKey: 'takeaway',
                            sourceText:
                                'Shark mentality: Maintain constant movement and growth to avoid the downfall that comes with stagnation.',
                            selectedText: 'Shark mentality',
                            createdAt: DateTime(2026, 9, 6),
                          )!,
                        ],
                        onAddHighlight: (_, _) async {},
                        onRemoveHighlight: (_) async {},
                      ),
                      const SizedBox(height: 20),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClusterCard(
                            cluster: _interest('AI agents', 15, [
                              'LLMs',
                              'Workflows',
                            ]),
                            tier: ClusterCardTier.medium,
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ClusterCard(
                            cluster: _interest('Product Design', 8, [
                              'UI',
                              'UX',
                            ]),
                            tier: ClusterCardTier.medium,
                            onTap: () {},
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(GoogleFonts.pendingFonts);
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        await tester.runAsync(
          () =>
              precacheImage(image.image, tester.element(find.byType(Scaffold))),
        );
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('discovery')),
        matchesGoldenFile('goldens/discovery_${entry.key}.png'),
      );
    });
  }
}

Widget _card(String title, String topic, String reason, String metadata) =>
    RediscoverArtworkCard(
      journey: RediscoverJourney(
        kind: RediscoverJourneyKind.forgottenGems,
        title: title,
        subtitle: reason,
        icon: Icons.bookmark,
        items: const [],
        signal: 1,
        topicAnchor: topic,
      ),
      title: title,
      supportingText: reason,
      metadata: metadata,
      height: 224,
      onTap: () {},
    );

InterestCluster _interest(String label, int count, List<String> topics) =>
    InterestCluster(
      id: label,
      label: label,
      saveCount: count,
      subtopics: topics,
      dominance: .5,
      coverImageUrl: null,
      accentColor: null,
    );
