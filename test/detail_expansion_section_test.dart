import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/url_detail/detail_expansion_section.dart';

void main() {
  testWidgets('detail section is collapsed until requested', (tester) async {
    const transcript = 'Complete transcript without truncation.';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DetailExpansionSection(
            title: 'Transcript & Caption',
            accent: Colors.indigo,
            child: Text(transcript),
          ),
        ),
      ),
    );

    expect(find.text('Transcript & Caption'), findsOneWidget);
    expect(find.text(transcript), findsNothing);

    await tester.tap(find.text('Transcript & Caption'));
    await tester.pumpAndSettle();

    expect(find.text(transcript), findsOneWidget);
  });

  test('transcript paragraphs preserve every word in source order', () {
    const transcript =
        'First idea is introduced. A second sentence adds context. '
        'The third closes the opening thought. A fourth begins a new idea. '
        'The fifth develops it. The sixth completes it.';

    final paragraphs = splitTranscriptParagraphs(transcript);

    expect(paragraphs, hasLength(2));
    expect(paragraphs.join(' '), transcript);
  });

  test('existing natural paragraph breaks remain intact', () {
    const transcript = 'Opening paragraph.\n\nFollow-up paragraph.';

    expect(splitTranscriptParagraphs(transcript), [
      'Opening paragraph.',
      'Follow-up paragraph.',
    ]);
  });
}
