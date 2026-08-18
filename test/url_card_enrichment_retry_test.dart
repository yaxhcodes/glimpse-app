import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/url_processing_status.dart';
import 'package:glimpse/core/providers/usage_providers.dart';
import 'package:glimpse/shared/widgets/enrichment_retry_button.dart';
import 'package:glimpse/shared/widgets/url_card.dart';

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
    ..tags = ['instagram']
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
  testWidgets('shows retry inline with metadata when AI access returns', (
    tester,
  ) async {
    await tester.pumpWidget(_app(hasAiSaveAccess: true));

    final retry = find.text('Retry');
    final source = find.text('Instagram');
    expect(retry, findsOneWidget);
    expect(source, findsOneWidget);
    expect(
      (tester.getCenter(retry).dy - tester.getCenter(source).dy).abs(),
      lessThan(8),
    );
    expect(
      tester.getSize(find.byType(EnrichmentRetryButton)).height,
      lessThanOrEqualTo(32),
    );
  });

  testWidgets('hides retry while the free AI allowance is exhausted', (
    tester,
  ) async {
    await tester.pumpWidget(_app(hasAiSaveAccess: false));

    expect(find.text('Retry'), findsNothing);
  });
}
