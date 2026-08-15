import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/shared/widgets/url_card.dart';

void main() {
  testWidgets('selection keeps the URL thumbnail and overlays its circle', (
    tester,
  ) async {
    var toggles = 0;
    final url = SavedUrl()
      ..id = 1
      ..rawUrl = 'https://example.com/selected-save'
      ..domain = 'example.com'
      ..title = 'Selected save'
      ..description = 'A saved item used to verify selection presentation.'
      ..category = 'Articles'
      ..categoryEmoji = 'article'
      ..categories = const ['Articles']
      ..tags = const []
      ..savedAt = DateTime(2026, 8, 14);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: UrlCard(
              savedUrl: url,
              tagFrequency: const {},
              selectionMode: true,
              isSelected: true,
              onSelectionTap: () => toggles++,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('url-card-selection-thumbnail')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('selection-selected')), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.text('Selected save'));
    expect(toggles, 1);
  });
}
