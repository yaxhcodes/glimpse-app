import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/ask/ask_answer_text.dart';

void main() {
  testWidgets(
    'answer supports citations, tables and large text on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SingleChildScrollView(
                child: AskAnswerText(
                  text:
                      '## A useful answer\n**Evidence** [2]\n\n| Option | Tradeoff |\n| --- | --- |\n| First | A longer explanation that wraps |\n| Second | Another explanation |',
                  style: const TextStyle(fontSize: 16),
                  onCitation: (index) => selected = index,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('[2]'));
      expect(selected, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('streamed citations are inert until validation completes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AskAnswerText(
            text: 'A partial answer [99]',
            style: TextStyle(fontSize: 16),
            onCitation: null,
            selectable: false,
          ),
        ),
      ),
    );
    expect(find.byType(InkWell), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
