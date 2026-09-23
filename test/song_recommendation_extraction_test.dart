import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';
import 'package:glimpse/features/library/library_entity.dart';

void main() {
  test('five recommended songs survive storage and enter Songs separately', () {
    final result = TranscriptEnrichmentResult.fromJson({
      'entities': [
        for (var i = 0; i < 5; i++)
          {
            'name': i < 2 ? 'Same title' : 'Song $i',
            'type': i.isEven ? 'song' : 'track',
            'artist': 'Artist $i',
            'why_mentioned': 'Recommended in the reel.',
          },
        {'name': 'Album', 'type': 'album', 'artist': 'Artist 0'},
        {'name': 'Artist', 'type': 'artist', 'creator': 'Someone'},
        {'name': 'Unknown artist', 'type': 'song'},
      ],
    })!;
    final restored = TranscriptEnrichmentResult.fromJson(result.toJson())!;
    final save = SavedUrl()
      ..id = 1
      ..rawUrl = 'https://example.com/reel'
      ..title = 'Five songs'
      ..description = ''
      ..category = 'Music'
      ..categories = ['Music']
      ..tags = []
      ..categoryEmoji = ''
      ..domain = 'example.com'
      ..savedAt = DateTime(2026, 9, 23)
      ..enrichmentJson = jsonEncode(restored.toJson());
    final songs = LibraryIndex.build([save]).entities;
    expect(songs, hasLength(5));
    expect(songs.every((song) => song.kind == LibraryEntityKind.music), isTrue);
    expect(songs.map((song) => song.mention.creator).toSet(), {
      for (var i = 0; i < 5; i++) 'Artist $i',
    });
    expect(songs.where((song) => song.title == 'Same title'), hasLength(2));
    expect(songs.every((song) => song.sources.single.urlId == 1), isTrue);
  });
}
