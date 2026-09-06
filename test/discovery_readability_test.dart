import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/saved_highlights_service.dart';
import 'package:glimpse/features/url_detail/reader_selectable_text.dart';
import 'package:glimpse/shared/theme/app_theme.dart';
import 'package:glimpse/shared/theme/topic_visual.dart';
import 'package:glimpse/shared/widgets/hyphenated_title.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + .05) / (math.min(first, second) + .05);
}

void main() {
  test('discovery text remains readable across all seeded palettes', () {
    for (final accent in AppAccentColor.values.where(
      (a) => a.seedColor != null,
    )) {
      for (final brightness in Brightness.values) {
        final cs = ColorScheme.fromSeed(
          seedColor: accent.seedColor!,
          brightness: brightness,
          dynamicSchemeVariant: accent.schemeVariant,
        );
        for (final topic in ['software', 'food']) {
          final visual = TopicVisual.forCategory(topic);
          expect(
            contrast(visual.foreground(cs), visual.container(cs)),
            greaterThanOrEqualTo(4.5),
            reason: '${accent.name} $brightness interest icon',
          );
          for (final opacity in [.45, .58]) {
            final surface = TopicVisual.forCategory(
              topic,
            ).cardSurface(cs, opacity: opacity);
            for (final foreground in [cs.onSurface, cs.onSurfaceVariant]) {
              expect(
                contrast(foreground, surface),
                greaterThanOrEqualTo(5),
                reason: '${accent.name} $brightness $topic',
              );
            }
          }
        }
      }
    }
  });

  testWidgets(
    'monochrome saved highlights pair readable ink with their background',
    (tester) async {
      for (final brightness in Brightness.values) {
        final cs = ColorScheme.fromSeed(
          seedColor: const Color(0xFF5F6368),
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(colorScheme: cs),
            home: Scaffold(
              body: ReaderSelectableText(
                text: 'Shark mentality: Keep moving.',
                sectionKey: 'brief',
                style: TextStyle(color: cs.onSurfaceVariant),
                highlights: [
                  SavedHighlightsCodec.create(
                    id: 'h',
                    sectionKey: 'brief',
                    sourceText: 'Shark mentality: Keep moving.',
                    selectedText: 'Shark mentality',
                    createdAt: DateTime(2026),
                  )!,
                ],
                onAddHighlight: (_, _) async {},
                onRemoveHighlight: (_) async {},
              ),
            ),
          ),
        );
        final text = tester.widget<Text>(
          find.descendant(
            of: find.byType(ReaderSelectableText),
            matching: find.byType(Text),
          ),
        );
        final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
        final highlight = spans.singleWhere(
          (span) => span.text == 'Shark mentality',
        );
        expect(
          contrast(highlight.style!.color!, highlight.style!.backgroundColor!),
          greaterThanOrEqualTo(5),
        );
        expect(text.textSpan!.toPlainText(), 'Shark mentality: Keep moving.');
      }
    },
  );

  testWidgets(
    'only overlong words receive visible hyphens and preserve their label',
    (tester) async {
      for (final width in [140.0, 600.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                child: const HyphenatedTitle(
                  text: 'Reading Recommendations',
                  style: TextStyle(fontSize: 23),
                ),
              ),
            ),
          ),
        );
        final title = tester.widget<Text>(
          find.descendant(
            of: find.byType(HyphenatedTitle),
            matching: find.byType(Text),
          ),
        );
        expect(title.data!.replaceAll('-\n', ''), 'Reading Recommendations');
        expect(title.semanticsLabel, 'Reading Recommendations');
        expect(title.data!.contains('-\n'), width == 140);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
