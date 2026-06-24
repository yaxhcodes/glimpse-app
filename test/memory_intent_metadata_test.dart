import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';

void main() {
  group('MemoryIntentMetadata', () {
    test('round-trips through transcript enrichment JSON', () {
      const result = TranscriptEnrichmentResult(
        meaningfulTitle: 'Kyoto itinerary',
        summary: 'A practical Kyoto travel itinerary.',
        category: 'Travel',
        tags: ['kyoto', 'japan travel'],
        memoryIntent: MemoryIntentMetadata(
          primaryIntent: 'visit',
          secondaryIntents: ['inspiration'],
          intentConfidence: 0.86,
          lifeArea: 'travel',
          whySavedHypothesis:
              'The user may be considering a future Kyoto trip.',
          actionability: 'high',
          timeHorizon: 'someday',
          effortLevel: 'medium',
          costLevel: 'unknown',
          difficulty: 'unknown',
          skillLevel: 'unknown',
          location: 'Kyoto',
          freshnessSensitivity: 'evergreen',
          evergreenScore: 0.9,
        ),
      );

      final parsed = TranscriptEnrichmentResult.fromJson(result.toJson());

      expect(parsed, isNotNull);
      expect(parsed!.memoryIntent?.primaryIntent, 'visit');
      expect(parsed.memoryIntent?.secondaryIntents, ['inspiration']);
      expect(parsed.memoryIntent?.lifeArea, 'travel');
      expect(parsed.memoryIntent?.location, 'Kyoto');
      expect(parsed.memoryIntent?.evergreenScore, 0.9);
    });

    test('accepts top-level legacy aliases', () {
      final parsed = MemoryIntentMetadata.fromJsonOrNull({
        'intent': 'Learn',
        'secondaryIntents': ['Reference'],
        'intentConfidence': 1.4,
        'lifeArea': 'Education',
        'whySavedHypothesis': 'The user may want to learn this later.',
      });

      expect(parsed, isNotNull);
      expect(parsed!.primaryIntent, 'learn');
      expect(parsed.secondaryIntents, ['reference']);
      expect(parsed.intentConfidence, 1);
      expect(parsed.lifeArea, 'Education');
    });
  });
}
