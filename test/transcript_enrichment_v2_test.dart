import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';

void main() {
  group('TranscriptEnrichmentResult v2', () {
    test('parses and serializes ordered content sections', () {
      final result = TranscriptEnrichmentResult.fromJson({
        'schema_version': 2,
        'meaningful_title': 'Human Psychology · Rationalization',
        'summary':
            'People often decide first and justify the choice afterward.',
        'category': 'Mental Health',
        'tags': ['psychology', 'critical thinking'],
        'key_points': ['Decisions often come before their justifications.'],
        'content_sections': [
          {
            'title': 'The rationalization trap',
            'points': [
              'People often decide first and justify the decision afterward.',
              'That backward process is not rational inquiry.',
            ],
          },
          {
            'title': 'Open-mindedness and shared humanity',
            'points': [
              'Research should begin with a willingness to change.',
              'Every person has value beyond tribal loyalties.',
            ],
          },
        ],
        'notable_items': [
          {
            'text': 'We make a decision, and then build an argument for it.',
            'type': 'quote',
            'attribution': 'Roy Casagranda',
          },
        ],
        'mentions': [
          {
            'title': 'Roy Casagranda',
            'type': 'person',
            'why_mentioned': 'Speaker',
          },
        ],
        'transcript': 'Complete source transcript.',
      });

      expect(result, isNotNull);
      expect(result!.schemaVersion, 2);
      expect(result.contentSections, hasLength(2));
      expect(result.contentSections.last.points.last, contains('tribal'));
      expect(result.mentions.single.title, 'Roy Casagranda');
      expect(result.notableItems.single.type, 'quote');

      final roundTrip = TranscriptEnrichmentResult.fromJson(result.toJson());
      expect(roundTrip!.schemaVersion, 2);
      expect(roundTrip.contentSections, hasLength(2));
      expect(roundTrip.transcript, 'Complete source transcript.');
    });

    test('keeps legacy payloads valid without a migration', () {
      final result = TranscriptEnrichmentResult.fromJson({
        'meaningful_title': 'Legacy save',
        'summary': 'A useful older summary.',
        'category': 'Other',
        'tags': ['reference'],
        'key_points': ['One older takeaway.'],
      });

      expect(result, isNotNull);
      expect(result!.schemaVersion, 1);
      expect(result.contentSections, isEmpty);
      expect(result.steps.single.title, 'One older takeaway.');
    });

    test('deduplicates malformed section content', () {
      final result = TranscriptEnrichmentResult.fromJson({
        'meaningful_title': 'Structured save',
        'summary': 'Summary',
        'category': 'Education',
        'tags': ['learning'],
        'content_sections': [
          {
            'title': 'One section',
            'points': ['Keep this point.', 'Keep this point.'],
          },
          {
            'title': 'One section',
            'points': ['Duplicate section.'],
          },
          {'title': 'Empty section', 'points': <String>[]},
        ],
      });

      expect(result!.contentSections, hasLength(1));
      expect(result.contentSections.single.points, ['Keep this point.']);
    });
  });
}
