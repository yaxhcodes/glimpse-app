import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/saved_media_resolver.dart';

SavedUrl _url({String? thumbnailUrl, String? enrichmentJson}) {
  return SavedUrl()
    ..rawUrl = 'https://www.instagram.com/reel/example'
    ..domain = 'instagram.com'
    ..title = 'Instagram save'
    ..description = ''
    ..category = 'Instagram'
    ..categoryEmoji = ''
    ..categories = ['Instagram']
    ..tags = ['health']
    ..thumbnailUrl = thumbnailUrl
    ..enrichmentJson = enrichmentJson
    ..savedAt = DateTime(2026, 7, 7);
}

void main() {
  group('SavedMediaResolver', () {
    test('uses enrichment media as fallback candidates', () {
      final url = _url(
        thumbnailUrl: 'https://cdninstagram.com/old.jpg',
        enrichmentJson: '''
{
  "thumbnail_url": "https://cdninstagram.com/old.jpg",
  "image_urls": [
    "https://cdninstagram.com/frame-1.jpg",
    "https://example.com/frame-2.jpg"
  ]
}
''',
      );

      expect(SavedMediaResolver.imageCandidates(url), [
        'https://cdninstagram.com/old.jpg',
        'https://cdninstagram.com/frame-1.jpg',
        'https://example.com/frame-2.jpg',
      ]);
    });

    test('adds referer headers for Instagram CDN media', () {
      expect(
        SavedMediaResolver.imageHttpHeaders(
          'https://scontent.cdninstagram.com/v/t51.29350-15/example.jpg',
        ),
        {'Referer': 'https://www.instagram.com/'},
      );
    });

    test('does not add headers for ordinary media', () {
      expect(
        SavedMediaResolver.imageHttpHeaders('https://example.com/image.jpg'),
        isNull,
      );
    });
  });
}
