import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';
import 'package:glimpse/features/url_detail/notable_term_grid.dart';

void main() {
  Widget buildGrid({required double width}) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: NotableTermGrid(
              children: const [
                SizedBox(key: ValueKey('one'), height: 68),
                SizedBox(key: ValueKey('two'), height: 68),
                SizedBox(key: ValueKey('three'), height: 68),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('uses two full rows of compact tiles on phone widths', (
    tester,
  ) async {
    await tester.pumpWidget(buildGrid(width: 360));

    final first = tester.getRect(find.byKey(const ValueKey('one')));
    final second = tester.getRect(find.byKey(const ValueKey('two')));
    final third = tester.getRect(find.byKey(const ValueKey('three')));

    expect(first.width, 176);
    expect(second.left, 184);
    expect(second.top, first.top);
    expect(third.left, first.left);
    expect(third.top, 76);
  });

  testWidgets('falls back to full-width rows on narrow layouts', (
    tester,
  ) async {
    await tester.pumpWidget(buildGrid(width: 280));

    final first = tester.getRect(find.byKey(const ValueKey('one')));
    final second = tester.getRect(find.byKey(const ValueKey('two')));

    expect(first.width, 280);
    expect(second.left, first.left);
    expect(second.top, 76);
  });

  test('uses the grid only for short label-like terms', () {
    const shortTerms = [
      EnrichedNotableItem(text: 'Handstand', type: 'term', label: 'Skill'),
      EnrichedNotableItem(text: 'Crow pose', type: 'term', label: 'Skill'),
    ];

    expect(shouldUseCompactTermGrid(shortTerms), isTrue);
  });

  test('keeps descriptive terms in full-width rows', () {
    const descriptiveTerms = [
      EnrichedNotableItem(
        text: 'Progressive overload',
        type: 'term',
        label: 'Training principle',
        whyImportant: 'Increase resistance gradually as strength improves.',
      ),
    ];

    expect(shouldUseCompactTermGrid(descriptiveTerms), isFalse);
  });

  test('keeps long term titles in full-width rows', () {
    const longTerms = [
      EnrichedNotableItem(
        text: 'Scapular stabilization during overhead movement',
        type: 'term',
        label: 'Technique',
      ),
    ];

    expect(shouldUseCompactTermGrid(longTerms), isFalse);
  });
}
