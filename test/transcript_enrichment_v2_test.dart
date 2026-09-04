import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/ai/ai_transport.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('schema v5 keeps notification blurbs and notable destinations', () {
    final result = TranscriptEnrichmentResult.fromJson({
      'schema_version': 5,
      'meaningful_title': 'Research tools',
      'summary': 'A useful collection of research tools.',
      'notification_blurb':
          'A concise guide to useful research tools and their practical strengths.',
      'notable_items': [
        {'text': 'OpenAlex', 'type': 'dataset', 'url': 'https://openalex.org/'},
      ],
    });

    expect(result?.schemaVersion, 5);
    expect(result?.notificationBlurb, contains('research tools'));
    expect(result?.notableItems.single.destinationUri?.host, 'openalex.org');
    expect(result?.toJson()['notification_blurb'], result?.notificationBlurb);
  });

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

    test('preserves schema v3 catalog metadata through a round trip', () {
      final result = TranscriptEnrichmentResult.fromJson({
        'schema_version': 3,
        'meaningful_title': 'A reading list',
        'summary': 'Books worth returning to.',
        'category': 'Books',
        'tags': ['reading'],
        'mentions': [
          {
            'title': 'The Left Hand of Darkness',
            'type': 'book',
            'subtype': 'novel',
            'creator': 'Ursula K. Le Guin',
            'year': '1969',
            'genres': ['Science Fiction'],
            'raw_genres': ['Science fiction'],
            'artwork_url': 'https://covers.example/left-hand.jpg',
            'catalog_id': 'OL20532W',
            'catalog_source': 'open_library',
            'match_confidence': 0.97,
            'user_library_status': 'active',
            'current_page': 42,
          },
          {
            'title': 'Blade Runner',
            'type': 'movie',
            'year': '1982',
            'why_mentioned': 'A defining science-fiction film.',
          },
          {
            'title': 'Kyoto',
            'type': 'place',
            'city': 'Kyoto',
            'country': 'Japan',
            'latitude': 35.0116,
            'longitude': 135.7681,
          },
        ],
        'books': [
          {
            'title': 'The Left Hand of Darkness',
            'author': 'Ursula K. Le Guin',
            'page_count': 304,
          },
        ],
        'movies': [
          {
            'title': 'Blade Runner',
            'year': '1982',
            'type': 'movie',
            'genres': ['Action', 'Drama', 'Science Fiction'],
            'raw_genres': ['Action', 'Drama', 'Sci-Fi'],
            'catalog_id': 'tt0083658',
            'catalog_source': 'omdb',
            'plot': 'A blade runner pursues four escaped replicants.',
            'imdb_rating': 8.1,
          },
        ],
      });

      final roundTrip = TranscriptEnrichmentResult.fromJson(result!.toJson())!;
      final book = roundTrip.mentions.firstWhere(
        (mention) => mention.type == 'book',
      );
      final movie = roundTrip.mentions.firstWhere(
        (mention) => mention.type == 'movie',
      );
      final place = roundTrip.mentions.firstWhere(
        (mention) => mention.type == 'place',
      );

      expect(roundTrip.schemaVersion, 3);
      expect(book.creator, 'Ursula K. Le Guin');
      expect(book.genres, ['Science Fiction']);
      expect(book.catalogId, 'OL20532W');
      expect(book.artworkUrl, 'https://covers.example/left-hand.jpg');
      expect(book.matchConfidence, 0.97);
      expect(book.libraryStatus, 'active');
      expect(book.pageCount, 304);
      expect(book.currentPage, 42);
      expect(movie.genres, ['Action', 'Drama', 'Science Fiction']);
      expect(movie.catalogId, 'tt0083658');
      expect(movie.catalogSource, 'omdb');
      expect(movie.plot, 'A blade runner pursues four escaped replicants.');
      expect(movie.imdbRating, 8.1);
      expect(movie.whyMentioned, 'A defining science-fiction film.');
      expect(place.city, 'Kyoto');
      expect(place.latitude, closeTo(35.0116, 0.00001));
      expect(place.longitude, closeTo(135.7681, 0.00001));
    });

    test('continues to parse legacy top-level entity arrays', () {
      final result = TranscriptEnrichmentResult.fromJson({
        'schema_version': 2,
        'meaningful_title': 'Legacy recommendations',
        'summary': 'Older structured entities.',
        'category': 'Books',
        'tags': ['books'],
        'books': [
          {
            'title': 'Piranesi',
            'author': 'Susanna Clarke',
            'genre': 'Fantasy',
            'cover_url': 'https://covers.example/piranesi.jpg',
          },
        ],
        'movies': [
          {
            'title': 'Arrival',
            'year': '2016',
            'type': 'movie',
            'poster_url': 'https://posters.example/arrival.jpg',
          },
        ],
        'places': [
          {'name': 'Louvre Museum', 'city': 'Paris', 'country': 'France'},
        ],
      });

      expect(result!.mentions.map((mention) => mention.type), [
        'book',
        'movie',
        'place',
      ]);
      expect(result.mentions.first.creator, 'Susanna Clarke');
      expect(result.mentions[1].subtype, 'movie');
      expect(result.mentions.last.city, 'Paris');
    });

    test('prefers structured titles over duplicate generic sections', () {
      final result = TranscriptEnrichmentResult.fromJson({
        'meaningful_title': 'International drama recommendations',
        'summary': 'Series worth watching.',
        'category': 'Movies & TV',
        'tags': ['k-drama'],
        'mentions': [
          {
            'title': 'Reply 1988',
            'type': 'other',
            'why_mentioned': 'The central subject of the recommendation.',
          },
          {
            'title': '愛のあとにくるもの',
            'type': 'other',
            'why_mentioned': 'A Japanese drama recommendation.',
          },
        ],
        'movies': [
          {
            'title': 'Reply 1988',
            'type': 'show',
            'poster_url': 'https://posters.example/reply-1988.jpg',
          },
          {'title': '愛のあとにくるもの', 'type': 'show'},
        ],
        'entities': [
          {
            'name': 'Reply 1988',
            'type': 'reference',
            'why_mentioned': 'The same recommended series.',
          },
          {
            'name': 'Netflix',
            'type': 'platform',
            'why_mentioned': 'A streaming service.',
          },
        ],
        'notable_items': [
          {'text': 'Reply 1988', 'type': 'product', 'label': 'K-Drama'},
          {'text': '愛のあとにくるもの', 'type': 'reference'},
          {
            'text': '20 episodes of almost 2 hours each',
            'type': 'term',
            'label': 'Format',
          },
        ],
      });

      expect(result, isNotNull);
      expect(result!.mentions.map((mention) => (mention.title, mention.type)), [
        ('Reply 1988', 'movie'),
        ('愛のあとにくるもの', 'movie'),
        ('Netflix', 'tool'),
      ]);
      expect(result.notableItems.map((item) => item.text), [
        '20 episodes of almost 2 hours each',
      ]);
    });

    test('preserves useful game, music, and tool entities', () {
      final result = TranscriptEnrichmentResult.fromJson({
        'meaningful_title': 'Offline game recommendations',
        'summary': 'Games and services worth remembering.',
        'category': 'Gaming',
        'tags': ['offline games'],
        'entities': [
          {
            'name': 'Oxenfree',
            'type': 'mobile_game',
            'why_mentioned': 'A narrative game available through Netflix.',
          },
          {
            'name': 'From the Sky',
            'type': 'song',
            'why_mentioned': 'A Gojira track.',
          },
          {
            'name': 'Just Join IT',
            'type': 'platform',
            'why_mentioned': 'A client-finding platform in Poland.',
          },
        ],
      });

      expect(result!.mentions.map((mention) => mention.type), [
        'game',
        'music',
        'tool',
      ]);
      expect(
        TranscriptEnrichmentResult.fromJson(
          result.toJson(),
        )!.mentions.map((mention) => mention.title),
        ['Oxenfree', 'From the Sky', 'Just Join IT'],
      );
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

    test('does not turn film analysis into a movie recommendation', () {
      final isRecommendation = hasMovieRecommendationIntentForEnrichment({
        'meaningful_title': 'Bollywood · Demographic Coding and Bias',
        'summary':
            'An analysis of how social groups are represented in popular film.',
        'memory_intent': {'primary_intent': 'learn'},
      }, hasMovieMentions: true);

      expect(isRecommendation, isFalse);
    });

    test('recognizes an actual movie watchlist from structured intent', () {
      final isRecommendation = hasMovieRecommendationIntentForEnrichment({
        'meaningful_title': 'Indonesian Horror Films',
        'summary': 'Three unsettling films for a future movie night.',
        'memory_intent': {'primary_intent': 'watch_later'},
      }, hasMovieMentions: true);

      expect(isRecommendation, isTrue);
    });

    test('uses localized topics when the provider omits tags', () async {
      SharedPreferences.setMockInitialValues({});
      final service = TranscriptEnrichmentService(
        transport: _StaticEnrichmentTransport({
          'schema_version': 4,
          'output_locale': 'ja',
          'meaningful_title': '内面世界の構築 · 目的と意味',
          'summary': '人生における意味と目的について説明しています。',
          'category': 'Spirituality & Philosophy',
          'tags': <String>[],
          'topics': ['人生の目的', '内面的な成長', '実存的意味'],
          'key_points': ['内面世界を構築することが方向性をもたらします。'],
          'caption': 'build your inner world.',
        }),
      );

      final result = await service.enrichUrl(
        rawUrl: 'https://www.instagram.com/reel/JAPANESE_TAGS_TEST/',
        title: 'Original title',
        description: '',
        thumbnailUrl: null,
        domain: 'instagram.com',
        outputLocale: 'ja',
        forceRefresh: true,
      );

      expect(result?.category, 'Spirituality & Philosophy');
      expect(result?.tags, ['人生の目的', '内面的な成長', '実存的意味']);
    });
  });
}

class _StaticEnrichmentTransport extends AiTransport {
  _StaticEnrichmentTransport(this.response);

  final Map<String, dynamic> response;

  @override
  Future<Map<String, dynamic>> postEnrichment({
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 180),
  }) async => Map<String, dynamic>.from(response);
}
