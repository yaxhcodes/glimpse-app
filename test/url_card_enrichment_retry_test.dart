import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/url_processing_status.dart';
import 'package:glimpse/core/providers/usage_providers.dart';
import 'package:glimpse/shared/widgets/enrichment_retry_button.dart';
import 'package:glimpse/shared/widgets/url_card.dart';
import 'package:glimpse/features/url_detail/url_detail_provider.dart';
import 'package:glimpse/shared/widgets/expressive_loading_indicator.dart';

SavedUrl _metadataOnlyUrl() {
  return SavedUrl()
    ..id = 42
    ..rawUrl = 'https://www.instagram.com/reel/example'
    ..domain = 'instagram.com'
    ..title = 'Saved Instagram post'
    ..description = ''
    ..category = 'Social'
    ..categoryEmoji = ''
    ..categories = ['Social']
    ..tags = ['instagram', 'philosophy']
    ..summary = 'Saved Instagram post from an exhausted free allowance.'
    ..savedAt = DateTime(2026, 8, 15)
    ..processingStatus = UrlProcessingStatus.completed;
}

Widget _app({required bool hasAiSaveAccess}) {
  return ProviderScope(
    overrides: [aiSaveAvailableProvider.overrideWithValue(hasAiSaveAccess)],
    child: MaterialApp(
      home: Scaffold(
        body: UrlCard(savedUrl: _metadataOnlyUrl(), tagFrequency: const {}),
      ),
    ),
  );
}

void main() {
  testWidgets('Cards track a retry started from Details until it finishes', (
    tester,
  ) async {
    await tester.pumpWidget(_app(hasAiSaveAccess: true));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(UrlCard)),
    );
    expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
    container.read(retryingUrlIdsProvider.notifier).state = {42};
    await tester.pump();
    expect(find.byType(ExpressiveLoadingIndicator), findsOneWidget);
    expect(find.text('Trying that step again'), findsOneWidget);
    // The detail is announced, not printed: one status line per card.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'Trying this processing step again',
      ),
      findsOneWidget,
    );
    expect(find.text('Trying this processing step again'), findsNothing);
    expect(find.byType(EnrichmentRetryButton), findsNothing);
    container.read(retryingUrlIdsProvider.notifier).state = {};
    await tester.pump();
    expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
    expect(find.text('Trying that step again'), findsNothing);
  });

  testWidgets('Plain saves stay quiet even when AI access returns', (
    tester,
  ) async {
    await tester.pumpWidget(_app(hasAiSaveAccess: true));
    expect(find.byType(EnrichmentRetryButton), findsNothing);
    // Unread state is a dot now, not the word.
    expect(find.text('Unread'), findsNothing);
    expect(find.text('Instagram'), findsOneWidget);
  });

  testWidgets('list cards never show tag chips or a retry button', (
    tester,
  ) async {
    await tester.pumpWidget(_app(hasAiSaveAccess: true));

    expect(find.text('Retry'), findsNothing);
    expect(find.byType(EnrichmentRetryButton), findsNothing);
    expect(find.text('philosophy'), findsNothing);
  });

  testWidgets('a source page can drop the repeated source name', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [aiSaveAvailableProvider.overrideWithValue(true)],
        child: MaterialApp(
          home: Scaffold(
            body: UrlCard(
              savedUrl: _metadataOnlyUrl(),
              tagFrequency: const {},
              showSourceName: false,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Instagram'), findsNothing);
  });
}
