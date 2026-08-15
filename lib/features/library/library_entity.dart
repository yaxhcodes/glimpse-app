import 'dart:convert';

import '../../core/models/saved_url.dart';
import '../../core/services/transcript_enrichment_service.dart';

enum LibraryEntityKind { book, movie, place }

enum LibraryItemStatus { unlisted, planning, active, dropped, completed }

extension LibraryItemStatusX on LibraryItemStatus {
  String labelFor(LibraryEntityKind kind) => switch ((this, kind)) {
    (LibraryItemStatus.unlisted, LibraryEntityKind.book) =>
      'Not in reading list',
    (LibraryItemStatus.unlisted, LibraryEntityKind.movie) => 'Not in watchlist',
    (LibraryItemStatus.unlisted, LibraryEntityKind.place) => 'Not listed',
    (LibraryItemStatus.planning, _) => 'Planning',
    (LibraryItemStatus.active, LibraryEntityKind.book) => 'Reading',
    (LibraryItemStatus.active, LibraryEntityKind.movie) => 'Watching',
    (LibraryItemStatus.active, LibraryEntityKind.place) => 'In progress',
    (LibraryItemStatus.dropped, _) => 'Dropped',
    (LibraryItemStatus.completed, LibraryEntityKind.book) => 'Read',
    (LibraryItemStatus.completed, LibraryEntityKind.movie) => 'Watched',
    (LibraryItemStatus.completed, LibraryEntityKind.place) => 'Visited',
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
    LibraryEntityKind.movie => 'Movies',
    LibraryEntityKind.place => 'Places',
  };

  String get singularLabel => switch (this) {
    LibraryEntityKind.book => 'Book',
    LibraryEntityKind.movie => 'Movie',
    LibraryEntityKind.place => 'Place',
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
  });

  final int urlId;
  final String title;
  final String domain;
  final DateTime savedAt;
  final String provisionalKey;
  final EnrichedMention mention;
  final String? thumbnailUrl;
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

  String get title => mention.title;
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
    final raw = url.enrichmentJson;
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];
      final result = TranscriptEnrichmentResult.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (result == null) return const [];
      final candidates = <_LibraryCandidate>[];
      for (final mention in result.mentions) {
        final kind = kindForMention(mention);
        if (kind == null || !_isV1Subtype(kind, mention.subtype)) continue;
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

  static LibraryEntityKind? kindForMention(EnrichedMention mention) {
    return switch (mention.type) {
      'book' => LibraryEntityKind.book,
      'movie' => LibraryEntityKind.movie,
      'place' => LibraryEntityKind.place,
      _ => null,
    };
  }

  static String provisionalKeyFor(
    LibraryEntityKind kind,
    EnrichedMention mention,
  ) {
    final title = _normalized(mention.title);
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
    if (kind == LibraryEntityKind.place) return const [];
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
    final genres = LibraryGenreNormalizer.normalize(kind, {
      ...mention.rawGenres,
      ...mention.genres.where((genre) => genre != 'Other'),
      ..._genreSignals,
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
    final rawGenres = {
      ...current.rawGenres,
      ...current.genres.where((genre) => genre != 'Other'),
      ...candidate.rawGenres,
      ...candidate.genres,
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
    );
  }

  static int? _laterPage(int? first, int? second) {
    if (first == null) return second;
    if (second == null) return first;
    return first >= second ? first : second;
  }
}
