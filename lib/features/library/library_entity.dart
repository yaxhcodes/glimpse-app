import 'dart:convert';

import '../../core/models/saved_url.dart';
import '../../core/models/music_song.dart';
import '../../core/services/transcript_enrichment_service.dart';

enum LibraryEntityKind { book, movie, place, music }

enum LibraryItemStatus { unlisted, planning, active, dropped, completed }

extension LibraryItemStatusX on LibraryItemStatus {
  String labelFor(LibraryEntityKind kind) => switch ((this, kind)) {
    (LibraryItemStatus.unlisted, LibraryEntityKind.book) =>
      'Not in reading list',
    (LibraryItemStatus.unlisted, LibraryEntityKind.movie) => 'Not in watchlist',
    (LibraryItemStatus.unlisted, LibraryEntityKind.place) => 'Not listed',
    (LibraryItemStatus.unlisted, LibraryEntityKind.music) => 'Not listed',
    (LibraryItemStatus.planning, _) => 'Planning',
    (LibraryItemStatus.active, LibraryEntityKind.book) => 'Reading',
    (LibraryItemStatus.active, LibraryEntityKind.movie) => 'Watching',
    (LibraryItemStatus.active, LibraryEntityKind.place) => 'In progress',
    (LibraryItemStatus.active, LibraryEntityKind.music) => 'In progress',
    (LibraryItemStatus.dropped, _) => 'Dropped',
    (LibraryItemStatus.completed, LibraryEntityKind.book) => 'Read',
    (LibraryItemStatus.completed, LibraryEntityKind.movie) => 'Watched',
    (LibraryItemStatus.completed, LibraryEntityKind.place) => 'Visited',
    (LibraryItemStatus.completed, LibraryEntityKind.music) => 'Done',
  };

  static LibraryItemStatus fromStorage(String? raw) {
    final normalized = raw?.trim().toLowerCase() ?? '';
    for (final status in LibraryItemStatus.values) {
      if (status.name == normalized) return status;
    }
    return LibraryItemStatus.unlisted;
  }
}

extension LibraryEntityKindX on LibraryEntityKind {
  String get label => switch (this) {
    LibraryEntityKind.book => 'Books',
    LibraryEntityKind.movie => 'Movies & Shows',
    LibraryEntityKind.place => 'Places',
    LibraryEntityKind.music => 'Music',
  };

  String get singularLabel => switch (this) {
    LibraryEntityKind.book => 'Book',
    LibraryEntityKind.movie => 'Movie',
    LibraryEntityKind.place => 'Place',
    LibraryEntityKind.music => 'Music',
  };
}

class LibrarySourceReference {
  const LibrarySourceReference({
    required this.urlId,
    required this.title,
    required this.domain,
    required this.savedAt,
    required this.provisionalKey,
    required this.mention,
    this.thumbnailUrl,
    this.siblingCountries = const [],
  });

  final int urlId;
  final String title;
  final String domain;
  final DateTime savedAt;
  final String provisionalKey;
  final EnrichedMention mention;
  final String? thumbnailUrl;

  /// Countries of the other places mentioned in the same save. A bare name
  /// like "Chuy" is ambiguous on its own but not next to Ala Archa.
  final List<String> siblingCountries;
}

class LibraryEntity {
  const LibraryEntity({
    required this.key,
    required this.provisionalKey,
    required this.kind,
    required this.mention,
    required this.sources,
    required this.discoveredAt,
  });

  final String key;
  final String provisionalKey;
  final LibraryEntityKind kind;
  final EnrichedMention mention;
  final List<LibrarySourceReference> sources;
  final DateTime discoveredAt;

  String get title => kind == LibraryEntityKind.place
      ? LibraryIndex.placeDisplayTitle(mention.title)
      : mention.title;
  String? get artworkUrl => mention.artworkUrl;
  String? get placeImageUrl {
    final exactArtwork = mention.artworkUrl?.trim() ?? '';
    if (exactArtwork.isNotEmpty) return exactArtwork;
    for (final source in sources) {
      final thumbnail = source.thumbnailUrl?.trim() ?? '';
      if (thumbnail.isNotEmpty) return thumbnail;
    }
    return null;
  }

  List<String> get genres => mention.genres;
  LibraryItemStatus get status =>
      LibraryItemStatusX.fromStorage(mention.libraryStatus);
  int? get pageCount => mention.pageCount;
  int? get currentPage => mention.currentPage;
  double? get readingProgress {
    final page = currentPage;
    final total = pageCount;
    if (page == null || total == null || total <= 0) return null;
    return (page / total).clamp(0.0, 1.0).toDouble();
  }

  bool get needsResolution => switch (kind) {
    LibraryEntityKind.book =>
      mention.catalogId == null ||
          mention.creator == null ||
          mention.artworkUrl == null ||
          mention.genres.isEmpty ||
          mention.pageCount == null,
    LibraryEntityKind.movie =>
      mention.catalogId == null ||
          mention.artworkUrl == null ||
          mention.genres.isEmpty,
    LibraryEntityKind.place =>
      mention.catalogId == null || !mention.hasCoordinates,
    LibraryEntityKind.music => false,
  };

  Map<String, dynamic> toResolverJson() {
    final contextHints = kind == LibraryEntityKind.place
        ? _placeContextHints()
        : const <String>[];
    return {
      'client_key': key,
      'kind': kind.name,
      'subtype': mention.subtype,
      'title': mention.title,
      'creator': mention.creator,
      'year': mention.year,
      'city': mention.city,
      'country': mention.country,
      if (contextHints.isNotEmpty) 'context_hints': contextHints,
    };
  }

  List<String> _placeContextHints() {
    final hints = <String>[];
    final seen = <String>{};

    void add(String? value) {
      if (hints.length >= 8) return;
      final cleaned = value?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
      if (cleaned.isEmpty) return;
      final bounded = cleaned.length <= 300
          ? cleaned
          : cleaned.substring(0, 300).trimRight();
      final normalized = bounded.toLowerCase();
      if (seen.add(normalized)) hints.add(bounded);
    }

    add(mention.whyMentioned);
    // Ahead of the free text so the eight-hint cap never drops them.
    if ((mention.country?.trim() ?? '').isEmpty) {
      for (final source in sources) {
        source.siblingCountries.forEach(add);
      }
    }
    for (final source in sources) {
      add(source.title);
      add(source.mention.whyMentioned);
    }
    return hints;
  }
}

class LibrarySnapshot {
  const LibrarySnapshot({required this.entities});

  final List<LibraryEntity> entities;

  List<LibraryEntity> ofKind(LibraryEntityKind kind) =>
      entities.where((entity) => entity.kind == kind).toList(growable: false);

  LibraryEntity? byKey(String key) {
    for (final entity in entities) {
      if (entity.key == key) return entity;
    }
    return null;
  }
}

class LibraryIndex {
  const LibraryIndex._();

  static LibrarySnapshot build(
    Iterable<SavedUrl> urls, {
    Set<String> hiddenKeys = const {},
  }) {
    final candidates = <_LibraryCandidate>[];
    for (final url in urls) {
      candidates.addAll(_candidatesForUrl(url));
    }

    return _buildFromCandidates(candidates, hiddenKeys: hiddenKeys);
  }

  static List<_LibraryCandidate> _candidatesForUrl(SavedUrl url) {
    try {
      final result = _enrichmentOf(url);
      final music = musicOf(url, result);
      if (result == null && music.isEmpty) return const [];
      final candidates = <_LibraryCandidate>[];
      final mentions = [
        ...music,
        for (final mention in result?.mentions ?? const <EnrichedMention>[])
          if (mention.type != 'music') mention,
      ];
      List<String> siblingCountriesOf(EnrichedMention self) => {
        for (final other in mentions)
          if (!identical(other, self) &&
              other.type == 'place' &&
              (other.country?.trim() ?? '').isNotEmpty)
            other.country!.trim(),
      }.toList(growable: false);
      for (final mention in mentions) {
        final kind = kindForMention(mention);
        if (kind == null || !_isV1Subtype(kind, mention.subtype)) continue;
        if (kind == LibraryEntityKind.place &&
            (_isTravelDirection(mention.title) || _isWholeCountry(mention))) {
          continue;
        }
        final provisional = provisionalKeyFor(kind, mention);
        if (provisional.isEmpty) continue;
        candidates.add(
          _LibraryCandidate(
            kind: kind,
            mention: mention,
            provisionalKey: provisional,
            genreSignals: _localGenreSignals(url, mention),
            source: LibrarySourceReference(
              urlId: url.id,
              title: url.title,
              domain: url.domain,
              savedAt: url.savedAt,
              provisionalKey: provisional,
              mention: mention,
              thumbnailUrl: url.thumbnailUrl,
              siblingCountries: kind == LibraryEntityKind.place
                  ? siblingCountriesOf(mention)
                  : const [],
            ),
          ),
        );
      }
      return List.unmodifiable(candidates);
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  static LibrarySnapshot _buildFromCandidates(
    Iterable<_LibraryCandidate> candidates, {
    required Set<String> hiddenKeys,
  }) {
    final catalogKeysByProvisional = <String, Set<String>>{};
    for (final candidate in candidates) {
      final catalogKey = canonicalCatalogKey(candidate.kind, candidate.mention);
      if (catalogKey == null) continue;
      catalogKeysByProvisional
          .putIfAbsent(candidate.provisionalKey, () => <String>{})
          .add(catalogKey);
    }

    final grouped = <String, _LibraryEntityBuilder>{};
    for (final candidate in candidates) {
      final catalogKey = canonicalCatalogKey(candidate.kind, candidate.mention);
      final knownCatalogKeys =
          catalogKeysByProvisional[candidate.provisionalKey] ??
          const <String>{};
      final key =
          catalogKey ??
          (knownCatalogKeys.length == 1
              ? knownCatalogKeys.single
              : candidate.provisionalKey);
      if (hiddenKeys.contains(key) ||
          hiddenKeys.contains(candidate.provisionalKey)) {
        continue;
      }
      grouped
          .putIfAbsent(
            key,
            () => _LibraryEntityBuilder(
              key: key,
              provisionalKey: candidate.provisionalKey,
              kind: candidate.kind,
            ),
          )
          .add(candidate);
    }

    final entities = grouped.values.map((builder) => builder.build()).toList()
      ..sort((a, b) => b.discoveredAt.compareTo(a.discoveredAt));
    return LibrarySnapshot(entities: List.unmodifiable(entities));
  }

  static const _artistSubtypes = {
    'artist',
    'band',
    'group',
    'musician',
    'singer',
    'rapper',
    'composer',
    'producer',
    'dj',
  };

  /// Reels mostly name who they are about ("Pink Floyd", "Karan Aujla")
  /// rather than a specific track; those are artists in the library.
  static bool isArtistMention(EnrichedMention mention) {
    if (mention.type != 'music') return false;
    if ((mention.creator?.trim() ?? '').isNotEmpty) return false;
    final subtype = mention.subtype?.trim().toLowerCase() ?? '';
    if (subtype.isNotEmpty && !_artistSubtypes.contains(subtype)) return false;
    final name = mention.title.trim();
    if (name.isEmpty || name.length > 80) return false;
    if (name.split(RegExp(r'\s+')).length > 6) return false;
    return !RegExp(r'https?://|www\.', caseSensitive: false).hasMatch(name);
  }

  /// Text a save says about itself, where "X" by Y pairings are written.
  static List<String> musicContext(
    TranscriptEnrichmentResult result,
    SavedUrl url,
  ) => [
    url.title,
    result.meaningfulTitle,
    result.summary,
    ?result.brief,
    for (final step in result.steps) ...[step.title, ?step.description],
  ];

  /// Every song and artist a save carries, as the Library shows them. Songs
  /// reach a save in many shapes — a track link, a tagged item, a mention,
  /// an artist's note ("Artist of the song Is This Love"), a takeaway
  /// ("Hysteria by Def Leppard is…", "Time from The Dark Side of the Moon…")
  /// or a quoted title in the summary — and all of them land in Songs.
  /// Artists stay artists only when no song of theirs is named.
  static List<EnrichedMention> musicOf(
    SavedUrl url,
    TranscriptEnrichmentResult? result,
  ) {
    final context = result == null
        ? <String>[url.title]
        : musicContext(result, url);
    final storedMusic = [
      for (final mention in result?.mentions ?? const <EnrichedMention>[])
        if (mention.type == 'music' && !_isVisualArtist(mention)) mention,
    ];
    final taggedSongs = [
      for (final item in result?.notableItems ?? const [])
        if (item.text.trim().isNotEmpty &&
            MusicSongQuery.isSongItem(type: item.type, label: item.label))
          EnrichedMention(
            title: item.text.trim(),
            type: 'music',
            subtype: 'song',
            creator: (item.attribution?.trim().isEmpty ?? true)
                ? null
                : item.attribution!.trim(),
            whyMentioned: item.whyImportant,
          ),
    ];
    final byKey = <String, EnrichedMention>{};
    void add(EnrichedMention mention) {
      // Albums and artists that carry a creator are not songs.
      final isSong =
          MusicSongQuery.tryCreate(
            title: mention.title,
            artist: mention.creator,
            type: mention.subtype ?? 'song',
          ) !=
          null;
      if (!isSong && !isArtistMention(mention)) return;
      final key = provisionalKeyFor(LibraryEntityKind.music, mention);
      final existing = byKey[key];
      // A stored copy carries the person's status; it wins over a re-derived
      // one.
      if (existing == null ||
          (existing.libraryStatus == null && mention.libraryStatus != null)) {
        byKey[key] = mention;
      }
    }

    pairMusicMentions([
      ...storedMusic,
      ...taggedSongs,
    ], context: context).nonNulls.forEach(add);
    derivedSongs(url, result).forEach(add);

    final creators = {
      for (final mention in byKey.values)
        if ((mention.creator?.trim() ?? '').isNotEmpty)
          _normalized(mention.creator!),
    };
    return [
      for (final mention in byKey.values)
        if (!isArtistMention(mention) ||
            !creators.contains(_normalized(mention.title)))
          mention,
    ];
  }

  static final _visualArtistWords = RegExp(
    r'sketch|paint|illustrat|drawing|cartoon|sculpt|photograph',
    caseSensitive: false,
  );

  /// A painter filed under music ("documented the famine through his
  /// sketches") is not someone to listen to.
  static bool _isVisualArtist(EnrichedMention mention) =>
      _visualArtistWords.hasMatch(mention.whyMentioned ?? '');

  /// Songs a save carries without a mention for them: the save itself when
  /// it is a track link, quoted songs its text cites by artist ('the 2009 hit
  /// "Fireflies" by Owl City'), takeaways that open with a song by an artist
  /// ("Hysteria by Def Leppard is recommended…"), and, in a save about one
  /// artist, takeaways that open with a song from an album ("Time from The
  /// Dark Side of the Moon…").
  static List<EnrichedMention> derivedSongs(
    SavedUrl url,
    TranscriptEnrichmentResult? result,
  ) {
    final songs = <String, EnrichedMention>{};
    void add(String title, String artist, String? why) {
      final cleanTitle = _trimTitle(title);
      final cleanArtist = artist.trim();
      if (!_plausibleSongTitle(cleanTitle) ||
          _normalized(cleanTitle) == _normalized(cleanArtist) ||
          MusicSongQuery.tryCreate(
                title: cleanTitle,
                artist: cleanArtist,
                type: 'song',
              ) ==
              null) {
        return;
      }
      final song = EnrichedMention(
        title: cleanTitle,
        type: 'music',
        subtype: 'song',
        creator: cleanArtist,
        whyMentioned: why,
      );
      songs.putIfAbsent(
        provisionalKeyFor(LibraryEntityKind.music, song),
        () => song,
      );
    }

    if (savedSongMention(url) case final song?) {
      songs[provisionalKeyFor(LibraryEntityKind.music, song)] = song;
    }
    if (result == null) return songs.values.toList(growable: false);

    final text = musicContext(result, url).join('\n');
    for (final match in _quotedSongBy.allMatches(text)) {
      final artist = _capitalisedName
          .firstMatch(text.substring(match.end))
          ?.group(1);
      if (artist != null) add(match.group(1)!, artist, null);
    }

    // Line patterns ("X by Y") also describe books and films, so they only
    // run on saves that are about music, and never re-file a title the save
    // already names as something else.
    final aboutMusic =
        result.mentions.any((mention) => mention.type == 'music') ||
        result.notableItems.any(
          (item) =>
              MusicSongQuery.isSongItem(type: item.type, label: item.label),
        ) ||
        _musicWords.hasMatch('${result.meaningfulTitle}\n${result.summary}');
    if (!aboutMusic) return songs.values.toList(growable: false);
    final otherTitles = {
      for (final mention in result.mentions)
        if (mention.type != 'music') _normalized(mention.title),
    };
    final subject = _subjectArtist(result);
    final lines = [
      for (final step in result.steps) ...[step.title, ?step.description],
      ...result.summary.split(RegExp(r'(?<=[.!?])\s+')),
    ];
    for (final raw in lines) {
      final line = raw.trim().replaceFirst(
        RegExp(r'^(?:the\s+)?(?:song|track|single)\s+', caseSensitive: false),
        '',
      );
      if (_songByArtistLine.firstMatch(line) case final match?) {
        if (!otherTitles.contains(_normalized(_trimTitle(match.group(1)!)))) {
          add(match.group(1)!, match.group(2)!, raw.trim());
        }
      } else if (subject != null) {
        if (_songFromAlbumLine.firstMatch(line) case final match?) {
          if (!otherTitles.contains(_normalized(_trimTitle(match.group(1)!)))) {
            add(match.group(1)!, subject, raw.trim());
          }
        }
      }
    }
    return songs.values.toList(growable: false);
  }

  static final _musicWords = RegExp(
    r'\b(songs?|tracks?|music|musical|albums?|playlists?|lyrics?|singer)\b',
    caseSensitive: false,
  );

  /// The one artist a save is about: "Pink Floyd · Essential Song
  /// Recommendations" with Pink Floyd among its music mentions.
  static String? _subjectArtist(TranscriptEnrichmentResult result) {
    final lead = result.meaningfulTitle.split('·').first.trim();
    if (lead.isEmpty) return null;
    for (final mention in result.mentions) {
      if (mention.type == 'music' &&
          _normalized(mention.title) == _normalized(lead)) {
        return mention.title.trim();
      }
    }
    return null;
  }

  static const _titleWord = r"[\p{Lu}\d][\p{L}\d'’&\-]*";
  static const _titleJoiner =
      r'(?:a|an|the|in|of|on|to|for|and|or|my|me|you|your|with|without|at)';
  static const _titlePattern =
      '($_titleWord(?:\\s+(?:$_titleWord|$_titleJoiner))*)';

  static final _songByArtistLine = RegExp(
    '^$_titlePattern\\s+by\\s+'
    "((?:[\\p{Lu}\\d][\\p{L}\\d'’&\\-]*)(?:\\s+(?:[\\p{Lu}\\d&][\\p{L}\\d'’&\\-]*|of|the|and|de|da|y))*)",
    unicode: true,
  );

  static final _songFromAlbumLine = RegExp(
    '^$_titlePattern\\s+from\\s+(?:the\\s+(?:album|record|ep)\\s+)?[\\p{Lu}\\d]',
    unicode: true,
  );

  static final _quotedSongBy = RegExp(
    r'["“]([^"”\n]{1,80})["”]\s+by\s+(?:the\s+(?:band|project|group|duo|artist|singer|rapper)\s+)?',
  );

  static String _trimTitle(String title) =>
      title.trim().replaceFirst(RegExp('(?:\\s+$_titleJoiner)+\$'), '').trim();

  /// Rejects what the line patterns can catch that is not a song: a lone
  /// verb ("Created by …") or article.
  static bool _plausibleSongTitle(String title) {
    if (title.isEmpty || title.length > 80) return false;
    final words = title.split(RegExp(r'\s+'));
    if (words.length > 10) return false;
    if (words.length == 1) {
      final word = words.single.toLowerCase();
      if (word.endsWith('ed') && word.length > 4) return false;
      if (const {
        'the',
        'this',
        'that',
        'it',
        'he',
        'she',
        'they',
        'we',
        'i',
      }.contains(word)) {
        return false;
      }
    }
    return true;
  }

  static const _songWords = ['song', 'track', 'single', 'tune'];
  static const _artistWords = [
    'artist',
    'band',
    'singer',
    'musician',
    'rapper',
    'composer',
    'producer',
    'duo',
    'vocalist',
    'lyricist',
    'songwriter',
    'guitarist',
    'drummer',
    'frontman',
    'member',
    'featured',
  ];

  /// Enrichment rarely stores a song as one mention with its artist. It files
  /// "How Many Bugs" and Teal Peel as two creator-less mentions, or keeps only
  /// Whitesnake with "Artist of the song Is This Love" as the reason. Rebuilds
  /// songs from what the save says so each can be looked up (and get its
  /// cover): a track takes its artist as creator, an artist whose song is
  /// named becomes that song, and an artist folded into a song is dropped.
  /// The result is aligned with [mentions]; null marks a folded mention.
  static List<EnrichedMention?> pairMusicMentions(
    List<EnrichedMention> mentions, {
    Iterable<String> context = const [],
  }) {
    bool isLoose(EnrichedMention m) =>
        m.type == 'music' && (m.creator?.trim() ?? '').isEmpty;
    bool says(EnrichedMention m, List<String> words) {
      final why = ' ${m.whyMentioned?.toLowerCase() ?? ''} ';
      final subtype = m.subtype?.trim().toLowerCase() ?? '';
      return words.contains(subtype) ||
          words.any((word) => why.contains(' $word'));
    }

    bool isTrack(EnrichedMention m) =>
        says(m, _songWords) && !says(m, _artistWords);

    final paired = List<EnrichedMention?>.of(mentions);
    final loose = [
      for (var i = 0; i < mentions.length; i++)
        if (isLoose(mentions[i])) i,
    ];
    if (loose.isEmpty) return paired;
    final text = [
      ...context,
      for (final m in mentions) ?m.whyMentioned,
    ].join('\n');
    final looseTitles = {for (final i in loose) _normalized(mentions[i].title)};

    for (final i in loose) {
      final m = mentions[i];
      // "Artist of the song Is This Love" names a song but is about the
      // artist; so does "…his music video for the song Scream" on Michael
      // Jackson. A note naming some other song makes this the artist.
      final namedSong = _songInReason(m.whyMentioned);
      final isArtist =
          says(m, _artistWords) ||
          (namedSong != null && _normalized(namedSong) != _normalized(m.title));
      if (!isArtist) {
        // A track: "How Many Bugs" by Teal Peel.
        final artist = _artistAfterBy(text, m.title);
        if (artist != null && _normalized(artist) != _normalized(m.title)) {
          paired[i] = m.copyWith(creator: artist, subtype: 'song');
        }
        continue;
      }
      // An artist: "Artist of the song Is This Love", or "Is This Love by
      // Whitesnake" elsewhere in the save.
      final song = namedSong ?? _songBefore(text, m.title);
      if (song != null &&
          _normalized(song) != _normalized(m.title) &&
          !looseTitles.contains(_normalized(song))) {
        paired[i] = m.copyWith(
          title: song,
          creator: m.title.trim(),
          subtype: 'song',
        );
      }
    }

    // Nothing in the text ties them, but one track and one artist in the
    // same save still belong together.
    final unpaired = [
      for (final i in loose)
        if (isLoose(paired[i]!)) i,
    ];
    if (unpaired.length == 2) {
      final [a, b] = unpaired;
      final songIndex = isTrack(mentions[a]) && says(mentions[b], _artistWords)
          ? a
          : isTrack(mentions[b]) && says(mentions[a], _artistWords)
          ? b
          : -1;
      if (songIndex >= 0) {
        final artistIndex = songIndex == a ? b : a;
        paired[songIndex] = mentions[songIndex].copyWith(
          creator: mentions[artistIndex].title.trim(),
          subtype: 'song',
        );
      }
    }

    final creators = {
      for (final m in paired.nonNulls)
        if (m.type == 'music' && !isLoose(m)) _normalized(m.creator!),
    };
    for (final i in loose) {
      final m = paired[i];
      if (m != null && isLoose(m) && creators.contains(_normalized(m.title))) {
        paired[i] = null;
      }
    }
    return paired;
  }

  static final _capitalisedName = RegExp(
    r"^([\p{Lu}\d][\p{L}\d'’&\-]*(?:\s+(?:[\p{Lu}\d&][\p{L}\d'’&\-]*|of|the|and|de|da|y))*)",
    unicode: true,
  );

  /// `"How Many Bugs" by Teal Peel` → Teal Peel. Only capitalised words, so
  /// "…by Teal Peel is noted for…" stops at the name.
  static String? _artistAfterBy(String text, String title) {
    final name = _normalizedSpace(title);
    if (name.isEmpty) return null;
    final lower = text.toLowerCase();
    var from = 0;
    while (true) {
      final at = lower.indexOf(name.toLowerCase(), from);
      if (at < 0) return null;
      from = at + name.length;
      final rest = text.substring(from);
      final by = RegExp(r'''^["”’']?\s+by\s+''').firstMatch(rest);
      if (by == null) continue;
      final artist = _capitalisedName
          .firstMatch(rest.substring(by.end))
          ?.group(1)
          ?.trim();
      if (artist != null && artist.isNotEmpty) return artist;
    }
  }

  /// "Artist of the song Is This Love." → Is This Love. The title ends
  /// where the capitalised run does, so "his song Stronger was inspired…"
  /// gives Stronger.
  static String? _songInReason(String? reason) {
    final text = reason?.trim() ?? '';
    final lead = RegExp(
      r"""\b(?:song|track|single|hit)\s+(?:called\s+|titled\s+)?["“‘']?""",
      caseSensitive: false,
    ).firstMatch(text);
    if (lead == null) return null;
    final title = RegExp(
      '^$_titlePattern',
      unicode: true,
    ).firstMatch(text.substring(lead.end))?.group(1);
    if (title == null) return null;
    final song = _trimTitle(title);
    return _plausibleSongTitle(song) ? song : null;
  }

  /// `Is This Love by Whitesnake` → Is This Love, quoted titles first. The
  /// unquoted title is the run of capitalised words (small joining words
  /// allowed) right before "by", so a sentence around it is left out.
  static String? _songBefore(String text, String artist) {
    final name = _normalizedSpace(artist).toLowerCase();
    if (name.isEmpty) return null;
    final lower = text.toLowerCase();
    String? unquoted;
    for (
      var at = lower.indexOf(' by $name');
      at >= 0;
      at = lower.indexOf(' by $name', at + 1)
    ) {
      final before = text.substring(0, at);
      final quoted = RegExp(r'["“]([^"”\n]{1,80})["”]$').firstMatch(before);
      if (quoted != null) return quoted.group(1)!.trim();
      unquoted ??= _titleRun
          .firstMatch(before.split(RegExp(r'[\n•:;!?]|\.\s')).last.trimRight())
          ?.group(1);
    }
    if (unquoted == null || unquoted.split(' ').length > 10) return null;
    return unquoted;
  }

  static final _titleRun = RegExp(
    r"(?:^|\s)([\p{Lu}\d][\p{L}\d'’&\-]*(?:\s+(?:[\p{Lu}\d][\p{L}\d'’&\-]*|a|an|the|in|of|on|to|for|and|my|me|you|your|it|is|at|with|without|from))*)$",
    unicode: true,
  );

  static String _normalizedSpace(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  static TranscriptEnrichmentResult? _enrichmentOf(SavedUrl url) {
    final raw = url.enrichmentJson;
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return TranscriptEnrichmentResult.fromJson(
      Map<String, dynamic>.from(decoded),
    );
  }

  /// A save that is itself a track (a Spotify or YouTube Music link) is a
  /// song in the library, not only the songs its enrichment mentions.
  static EnrichedMention? savedSongMention(SavedUrl url) {
    final uri = Uri.tryParse(url.rawUrl.trim());
    if (uri == null || !_isTrackLink(uri)) return null;
    final parsed = _songAndArtist(url.title);
    if (parsed == null) return null;
    final (title, artist) = parsed;
    if (MusicSongQuery.tryCreate(title: title, artist: artist, type: 'song') ==
        null) {
      return null;
    }
    final artwork = url.thumbnailUrl?.trim() ?? '';
    final description = url.description.trim();
    return EnrichedMention(
      title: title,
      type: 'music',
      subtype: 'song',
      creator: artist,
      posterUrl: artwork.isEmpty ? null : artwork,
      whyMentioned: description.isEmpty ? null : description,
    );
  }

  static bool _isTrackLink(Uri uri) {
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    return switch (host) {
      'open.spotify.com' => segments.contains('track'),
      'music.youtube.com' => uri.queryParameters.containsKey('v'),
      'music.apple.com' =>
        segments.contains('song') || uri.queryParameters.containsKey('i'),
      'soundcloud.com' || 'm.soundcloud.com' => segments.length == 2,
      _ => false,
    };
  }

  /// "High and Dry by Radiohead", "Sparkle by RADWIMPS from Your Name",
  /// "Shadow of the Day - song and lyrics by Linkin Park | Spotify".
  static (String, String)? _songAndArtist(String rawTitle) {
    var text = rawTitle
        .replaceFirst(RegExp(r'\s*[|·]\s*(Spotify|YouTube Music)\s*$'), '')
        .trim();
    text = text.replaceFirst(
      RegExp(r'\s+-\s+(song|single)( and lyrics)? by\s+', caseSensitive: false),
      ' by ',
    );
    final by = text.toLowerCase().lastIndexOf(' by ');
    if (by <= 0) return null;
    final title = text.substring(0, by).trim();
    final artist = text
        .substring(by + 4)
        .replaceFirst(RegExp(r'\s+(from|feat\.?|ft\.?)\s+.*$'), '')
        .trim();
    if (title.isEmpty || artist.isEmpty) return null;
    return (title, artist);
  }

  static final _directionStart = RegExp(
    r'^(alight|board|catch|take|walk|drive|head|turn|get off|get on|go)\b',
    caseSensitive: false,
  );

  /// Route steps ("Alight from bus to Balykchy – to Konorchek Canyon") that
  /// extraction sometimes files as places.
  static bool _isTravelDirection(String title) =>
      _directionStart.hasMatch(title.trim());

  /// "Kyrgyzstan" or "India" named as the subject of a travel reel is the
  /// area the places sit in, not a pin; the country chips already cover it.
  static bool _isWholeCountry(EnrichedMention mention) {
    final title = _normalized(mention.title);
    final country = _normalized(mention.country ?? '');
    final city = _normalized(mention.city ?? '');
    return title.isNotEmpty &&
        title == country &&
        (city.isEmpty || city == title);
  }

  /// Booking-site names append a sales pitch after slashes ("Yurt Camp at
  /// Song-Kul Lake/Comfortable yurts/Incredible View"); keep the name.
  static String placeDisplayTitle(String rawTitle) {
    final title = rawTitle.trim().replaceAll(
      RegExp(r'^["“”«»]+|["“”«»]+$'),
      '',
    );
    final parts = title.split('/');
    if (parts.length < 3) return title;
    final head = parts.first.trim();
    return head.split(RegExp(r'\s+')).length >= 2 ? head : title;
  }

  static LibraryEntityKind? kindForMention(EnrichedMention mention) {
    return switch (mention.type) {
      'book' => LibraryEntityKind.book,
      'movie' => LibraryEntityKind.movie,
      'place' => LibraryEntityKind.place,
      'music' => LibraryEntityKind.music,
      _ => null,
    };
  }

  static String provisionalKeyFor(
    LibraryEntityKind kind,
    EnrichedMention mention,
  ) {
    final title = kind == LibraryEntityKind.music
        ? MusicSongQuery.normalize(mention.title)
        : _normalized(mention.title);
    if (title.isEmpty) return '';
    return switch (kind) {
      LibraryEntityKind.book =>
        'book:$title|${_normalized(mention.creator ?? '')}',
      LibraryEntityKind.movie =>
        'movie:$title|${_normalized(mention.year ?? '')}|'
            '${_normalized(mention.subtype ?? 'movie')}',
      LibraryEntityKind.place =>
        'place:$title|${_normalized(mention.city ?? '')}|'
            '${_normalized(mention.country ?? '')}',
      LibraryEntityKind.music when isArtistMention(mention) =>
        'music:$title||artist',
      LibraryEntityKind.music =>
        'music:$title|${MusicSongQuery.normalize(mention.creator ?? '')}|track',
    };
  }

  static String? canonicalCatalogKey(
    LibraryEntityKind kind,
    EnrichedMention mention,
  ) {
    final id = mention.catalogId?.trim();
    final source = mention.catalogSource?.trim().toLowerCase();
    if (id == null || id.isEmpty || source == null || source.isEmpty) {
      return null;
    }
    return '${kind.name}:catalog:$source:${_normalized(id)}';
  }

  static bool _isV1Subtype(LibraryEntityKind kind, String? subtype) {
    final value = subtype?.trim().toLowerCase();
    if (kind == LibraryEntityKind.book && value == 'manga') return false;
    if (kind == LibraryEntityKind.movie && value == 'anime') return false;
    return true;
  }

  static List<String> _localGenreSignals(
    SavedUrl url,
    EnrichedMention mention,
  ) {
    return [
      mention.title,
      if (mention.whyMentioned != null) mention.whyMentioned!,
      url.title,
      url.description,
      if (url.summary != null) url.summary!,
      url.category,
      ...url.categories,
      ...url.tags,
    ].where((value) => value.trim().isNotEmpty).toList(growable: false);
  }

  static String _normalized(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// Incremental front-end for [LibraryIndex].
///
/// Isar emits the complete URL list whenever any saved item changes. This
/// cache keeps parsed Library candidates per URL and only reparses records
/// whose Library-relevant fields changed. Grouping remains delegated to the
/// same pure implementation used by [LibraryIndex.build].
class LibraryIndexCache {
  final Map<int, _LibraryCacheEntry> _entries = {};
  List<int> _lastUrlIds = const [];
  Set<String> _lastHiddenKeys = const {};
  LibrarySnapshot? _snapshot;
  int _parsedUrlCount = 0;

  int get parsedUrlCount => _parsedUrlCount;

  LibrarySnapshot build(
    Iterable<SavedUrl> urls, {
    Set<String> hiddenKeys = const {},
  }) {
    final orderedUrls = urls.toList(growable: false);
    final seenIds = <int>{};
    var candidatesChanged = false;

    for (final url in orderedUrls) {
      seenIds.add(url.id);
      final fingerprint = _LibraryUrlFingerprint.fromUrl(url);
      final cached = _entries[url.id];
      if (cached != null && cached.fingerprint == fingerprint) continue;
      _entries[url.id] = _LibraryCacheEntry(
        fingerprint: fingerprint,
        candidates: LibraryIndex._candidatesForUrl(url),
      );
      _parsedUrlCount++;
      candidatesChanged = true;
    }

    final removedIds = _entries.keys
        .where((id) => !seenIds.contains(id))
        .toList(growable: false);
    if (removedIds.isNotEmpty) {
      for (final id in removedIds) {
        _entries.remove(id);
      }
      candidatesChanged = true;
    }

    final orderedIds = orderedUrls.map((url) => url.id).toList(growable: false);
    final orderChanged = !_listEquals(orderedIds, _lastUrlIds);
    final hiddenChanged = !_setEquals(hiddenKeys, _lastHiddenKeys);
    if (!candidatesChanged && !orderChanged && !hiddenChanged) {
      return _snapshot ?? const LibrarySnapshot(entities: []);
    }

    final candidates = <_LibraryCandidate>[];
    for (final url in orderedUrls) {
      candidates.addAll(_entries[url.id]?.candidates ?? const []);
    }
    _lastUrlIds = List.unmodifiable(orderedIds);
    _lastHiddenKeys = Set.unmodifiable(hiddenKeys);
    return _snapshot = LibraryIndex._buildFromCandidates(
      candidates,
      hiddenKeys: hiddenKeys,
    );
  }
}

class _LibraryCacheEntry {
  const _LibraryCacheEntry({
    required this.fingerprint,
    required this.candidates,
  });

  final _LibraryUrlFingerprint fingerprint;
  final List<_LibraryCandidate> candidates;
}

class _LibraryUrlFingerprint {
  _LibraryUrlFingerprint.fromUrl(SavedUrl url)
    : enrichmentJson = url.enrichmentJson,
      title = url.title,
      description = url.description,
      summary = url.summary,
      domain = url.domain,
      thumbnailUrl = url.thumbnailUrl,
      category = url.category,
      categories = List.unmodifiable(url.categories),
      tags = List.unmodifiable(url.tags),
      savedAt = url.savedAt;

  final String? enrichmentJson;
  final String title;
  final String description;
  final String? summary;
  final String domain;
  final String? thumbnailUrl;
  final String category;
  final List<String> categories;
  final List<String> tags;
  final DateTime savedAt;

  @override
  bool operator ==(Object other) {
    return other is _LibraryUrlFingerprint &&
        other.enrichmentJson == enrichmentJson &&
        other.title == title &&
        other.description == description &&
        other.summary == summary &&
        other.domain == domain &&
        other.thumbnailUrl == thumbnailUrl &&
        other.category == category &&
        _listEquals(other.categories, categories) &&
        _listEquals(other.tags, tags) &&
        other.savedAt == savedAt;
  }

  @override
  int get hashCode => Object.hash(
    enrichmentJson,
    title,
    description,
    summary,
    domain,
    thumbnailUrl,
    category,
    Object.hashAll(categories),
    Object.hashAll(tags),
    savedAt,
  );
}

bool _listEquals<T>(List<T> first, List<T> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

bool _setEquals<T>(Set<T> first, Set<T> second) {
  return first.length == second.length && first.containsAll(second);
}

class LibraryGenreNormalizer {
  const LibraryGenreNormalizer._();

  static const _bookGenres = <String, List<String>>{
    'Fantasy': ['fantasy'],
    'Science Fiction': ['science fiction', 'sci fi', 'sci-fi'],
    'Mystery & Thriller': ['mystery', 'thriller', 'detective', 'suspense'],
    'Romance': ['romance'],
    'Horror': ['horror'],
    'Biography & Memoir': ['biography', 'memoir', 'autobiography'],
    'History': ['history', 'historical'],
    'Philosophy': ['philosophy'],
    'Psychology': ['psychology'],
    'Business': [
      'business',
      'economics',
      'entrepreneurship',
      'management',
      'marketing',
      'startup',
    ],
    'Finance & Investing': [
      'finance',
      'financial',
      'investing',
      'investment',
      'trading',
      'stock market',
      'personal finance',
    ],
    'Technology': [
      'technology',
      'computers',
      'computer science',
      'programming',
      'software',
      'artificial intelligence',
      'machine learning',
      'data science',
      'algorithm',
    ],
    'Science': ['science', 'biology', 'physics', 'chemistry', 'astronomy'],
    'Self-Development': ['self help', 'self-help', 'personal development'],
    'Health & Wellness': [
      'health',
      'wellness',
      'fitness',
      'nutrition',
      'medicine',
    ],
    'Politics & Society': [
      'politics',
      'political',
      'society',
      'social science',
      'sociology',
    ],
    'Art & Design': ['art', 'design', 'architecture', 'photography'],
    'Travel': ['travel', 'journey', 'guidebook'],
    'Comics & Graphic Novels': ['comic', 'graphic novel'],
    'Fiction': ['fiction', 'novel', 'literature'],
  };

  static const _movieGenres = <String, List<String>>{
    'Action': ['action'],
    'Adventure': ['adventure'],
    'Animation': ['animation'],
    'Comedy': ['comedy'],
    'Crime': ['crime'],
    'Documentary': ['documentary'],
    'Drama': ['drama'],
    'Family': ['family'],
    'Fantasy': ['fantasy'],
    'Horror': ['horror'],
    'Mystery': ['mystery'],
    'Romance': ['romance'],
    'Science Fiction': ['science fiction', 'sci fi', 'sci-fi'],
    'Thriller': ['thriller', 'suspense'],
    'War': ['war', 'military'],
    'Western': ['western'],
    'Music': ['music', 'musical'],
  };

  static List<String> normalize(LibraryEntityKind kind, Iterable<String> raw) {
    if (kind == LibraryEntityKind.place || kind == LibraryEntityKind.music) {
      return const [];
    }
    final taxonomy = kind == LibraryEntityKind.book
        ? _bookGenres
        : _movieGenres;
    final haystack = raw.map((genre) => genre.toLowerCase()).toList();
    final matches = <String>[];
    for (final entry in taxonomy.entries) {
      if (haystack.any(
        (genre) => entry.value.any((alias) => genre.contains(alias)),
      )) {
        matches.add(entry.key);
      }
    }
    if (matches.contains('Science Fiction')) {
      matches.remove('Science');
      matches.remove('Fiction');
    }
    return matches.isEmpty ? const ['Other'] : List.unmodifiable(matches);
  }
}

class _LibraryCandidate {
  const _LibraryCandidate({
    required this.kind,
    required this.mention,
    required this.provisionalKey,
    required this.genreSignals,
    required this.source,
  });

  final LibraryEntityKind kind;
  final EnrichedMention mention;
  final String provisionalKey;
  final List<String> genreSignals;
  final LibrarySourceReference source;
}

class _LibraryEntityBuilder {
  _LibraryEntityBuilder({
    required this.key,
    required this.provisionalKey,
    required this.kind,
  });

  final String key;
  final String provisionalKey;
  final LibraryEntityKind kind;
  final List<LibrarySourceReference> _sources = [];
  final Set<String> _genreSignals = {};
  EnrichedMention? _mention;

  void add(_LibraryCandidate candidate) {
    if (_sources.every((source) => source.urlId != candidate.source.urlId)) {
      _sources.add(candidate.source);
    }
    _genreSignals.addAll(candidate.genreSignals);
    _mention = _mergeMentions(_mention, candidate.mention, kind);
  }

  LibraryEntity build() {
    _sources.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final mention = _mention!;
    final hasCatalogGenres =
        kind == LibraryEntityKind.movie && _hasCatalogGenres(mention);
    final genres = LibraryGenreNormalizer.normalize(kind, {
      ...mention.rawGenres,
      ...mention.genres.where((genre) => genre != 'Other'),
      if (!hasCatalogGenres) ..._genreSignals,
    });
    return LibraryEntity(
      key: key,
      provisionalKey: provisionalKey,
      kind: kind,
      mention: mention.copyWith(genres: genres),
      sources: List.unmodifiable(_sources),
      discoveredAt: _sources.first.savedAt,
    );
  }

  static EnrichedMention _mergeMentions(
    EnrichedMention? current,
    EnrichedMention candidate,
    LibraryEntityKind kind,
  ) {
    if (current == null) {
      final raw = {...candidate.rawGenres, ...candidate.genres};
      return candidate.copyWith(
        genres: LibraryGenreNormalizer.normalize(kind, raw),
        rawGenres: raw.toList(growable: false),
      );
    }
    final currentHasCatalogGenres =
        kind == LibraryEntityKind.movie && _hasCatalogGenres(current);
    final candidateHasCatalogGenres =
        kind == LibraryEntityKind.movie && _hasCatalogGenres(candidate);
    final rawGenres = <String>{
      if (!candidateHasCatalogGenres || currentHasCatalogGenres)
        ...current.rawGenres,
      if (!candidateHasCatalogGenres || currentHasCatalogGenres)
        ...current.genres.where((genre) => genre != 'Other'),
      if (!currentHasCatalogGenres || candidateHasCatalogGenres)
        ...candidate.rawGenres,
      if (!currentHasCatalogGenres || candidateHasCatalogGenres)
        ...candidate.genres.where((genre) => genre != 'Other'),
    };
    String? richer(String? a, String? b) {
      final first = a?.trim() ?? '';
      final second = b?.trim() ?? '';
      if (first.isEmpty) return second.isEmpty ? null : second;
      if (second.length > first.length) return second;
      return first;
    }

    return EnrichedMention(
      title: richer(current.title, candidate.title) ?? current.title,
      type: current.type,
      subtype: richer(current.subtype, candidate.subtype),
      creator: richer(current.creator, candidate.creator),
      year: richer(current.year, candidate.year),
      whyMentioned: richer(current.whyMentioned, candidate.whyMentioned),
      posterUrl: richer(current.posterUrl, candidate.posterUrl),
      genres: LibraryGenreNormalizer.normalize(kind, rawGenres),
      rawGenres: rawGenres.toList(growable: false),
      catalogId: richer(current.catalogId, candidate.catalogId),
      catalogSource: richer(current.catalogSource, candidate.catalogSource),
      city: richer(current.city, candidate.city),
      country: richer(current.country, candidate.country),
      latitude: current.latitude ?? candidate.latitude,
      longitude: current.longitude ?? candidate.longitude,
      matchConfidence:
          (current.matchConfidence ?? 0) >= (candidate.matchConfidence ?? 0)
          ? current.matchConfidence
          : candidate.matchConfidence,
      libraryStatus: current.libraryStatus ?? candidate.libraryStatus,
      pageCount: current.pageCount ?? candidate.pageCount,
      currentPage: _laterPage(current.currentPage, candidate.currentPage),
      plot: richer(current.plot, candidate.plot),
      imdbRating: current.imdbRating ?? candidate.imdbRating,
    );
  }

  static bool _hasCatalogGenres(EnrichedMention mention) {
    final source = mention.catalogSource?.trim() ?? '';
    return source.isNotEmpty &&
        (mention.rawGenres.isNotEmpty ||
            mention.genres.any((genre) => genre != 'Other'));
  }

  static int? _laterPage(int? first, int? second) {
    if (first == null) return second;
    if (second == null) return first;
    return first >= second ? first : second;
  }
}
