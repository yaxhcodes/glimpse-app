import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/title_resolver.dart';

SavedUrl _url({
  required String title,
  List<String> tags = const [],
  String domain = 'instagram.com',
  String? summary,
}) {
  return SavedUrl()
    ..rawUrl = 'https://example.com/x'
    ..domain = domain
    ..title = title
    ..description = ''
    ..category = 'Travel'
    ..categoryEmoji = '🌍'
    ..categories = []
    ..tags = tags
    ..savedAt = DateTime(2024, 6, 1)
    ..summary = summary;
}

void main() {
  group('TitleResolver', () {
    test('Daniel & Dinah Instagram handle → two rarest tags', () {
      final u = _url(
        title: 'Daniel & Dinah | Adventure Travel on Instagram',
        tags: [
          'new zealand',
          'hiking',
          'copland track',
          'adventure travel',
          'instagram',
        ],
      );
      final freq = {
        'new zealand': 3,
        'hiking': 20,
        'copland track': 1,
        'adventure travel': 8,
      };
      expect(
        TitleResolver.resolve(u, tagFrequency: freq),
        'Copland Track · New Zealand',
      );
    });

    test('Kristina pipe title → Kepler Track · Luxmore Hut', () {
      final u = _url(
        title:
            'Kristina | New Zealand travel, hiking & outdoors on Instagram',
        tags: [
          'kepler track',
          'luxmore hut',
          'new zealand',
          'hiking',
          'instagram',
        ],
      );
      final freq = {
        'kepler track': 1,
        'luxmore hut': 1,
        'new zealand': 5,
        'hiking': 15,
      };
      expect(
        TitleResolver.resolve(u, tagFrequency: freq),
        'Kepler Track · Luxmore Hut',
      );
    });

    test('legitimate technical title kept as-is', () {
      final u = _url(
        title: 'How to configure Webpack 5 for production',
        tags: ['webpack', 'javascript'],
        domain: 'dev.to',
      );
      expect(
        TitleResolver.resolve(u, tagFrequency: {'webpack': 2, 'javascript': 5}),
        'How to configure Webpack 5 for production',
      );
    });

    test('Josh McCabe on Instagram → tags', () {
      final u = _url(
        title: 'Josh McCabe on Instagram',
        tags: [
          'cordillera huayhuash',
          'peru',
          'hiking',
          'instagram',
        ],
      );
      final freq = {
        'cordillera huayhuash': 1,
        'peru': 2,
        'hiking': 30,
      };
      expect(
        TitleResolver.resolve(u, tagFrequency: freq),
        'Cordillera Huayhuash · Peru',
      );
    });
  });
}
