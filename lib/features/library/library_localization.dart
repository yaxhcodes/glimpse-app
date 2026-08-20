import '../../l10n/generated/app_localizations.dart';
import 'library_entity.dart';

String localizedLibraryKind(AppLocalizations strings, LibraryEntityKind kind) =>
    switch (kind) {
      LibraryEntityKind.book => strings.libraryBooks,
      LibraryEntityKind.movie => strings.libraryMoviesShows,
      LibraryEntityKind.place => strings.libraryPlaces,
    };

String localizedLibraryKindSingular(
  AppLocalizations strings,
  LibraryEntityKind kind,
) => switch (kind) {
  LibraryEntityKind.book => strings.libraryBook,
  LibraryEntityKind.movie => strings.libraryMovie,
  LibraryEntityKind.place => strings.libraryPlace,
};

String localizedLibraryListName(
  AppLocalizations strings,
  LibraryEntityKind kind,
) => switch (kind) {
  LibraryEntityKind.book => strings.libraryReadingList,
  LibraryEntityKind.movie => strings.libraryWatchlist,
  LibraryEntityKind.place => strings.libraryPlaces,
};

String localizedLibraryStatus(
  AppLocalizations strings,
  LibraryItemStatus status,
  LibraryEntityKind kind,
) => switch ((status, kind)) {
  (LibraryItemStatus.unlisted, LibraryEntityKind.book) =>
    strings.libraryNotInReadingList,
  (LibraryItemStatus.unlisted, LibraryEntityKind.movie) =>
    strings.libraryNotInWatchlist,
  (LibraryItemStatus.unlisted, LibraryEntityKind.place) =>
    strings.libraryNotListed,
  (LibraryItemStatus.planning, _) => strings.libraryPlanning,
  (LibraryItemStatus.active, LibraryEntityKind.book) => strings.libraryReading,
  (LibraryItemStatus.active, LibraryEntityKind.movie) =>
    strings.libraryWatching,
  (LibraryItemStatus.active, LibraryEntityKind.place) =>
    strings.libraryInProgress,
  (LibraryItemStatus.dropped, _) => strings.libraryDropped,
  (LibraryItemStatus.completed, LibraryEntityKind.book) => strings.libraryRead,
  (LibraryItemStatus.completed, LibraryEntityKind.movie) =>
    strings.libraryWatched,
  (LibraryItemStatus.completed, LibraryEntityKind.place) =>
    strings.libraryVisited,
};

String localizedLibraryCount(
  AppLocalizations strings,
  LibraryEntityKind kind,
  int count,
) => switch (kind) {
  LibraryEntityKind.book => strings.libraryBookCount(count),
  LibraryEntityKind.movie => strings.libraryMovieCount(count),
  LibraryEntityKind.place => strings.libraryPlaceCount(count),
};

String localizedLibraryGenre(AppLocalizations strings, String genre) =>
    switch (genre.trim()) {
      'Fantasy' => strings.libraryGenreFantasy,
      'Science Fiction' => strings.libraryGenreScienceFiction,
      'Mystery & Thriller' => strings.libraryGenreMysteryThriller,
      'Romance' => strings.libraryGenreRomance,
      'Horror' => strings.libraryGenreHorror,
      'Biography & Memoir' => strings.libraryGenreBiographyMemoir,
      'History' => strings.libraryGenreHistory,
      'Philosophy' => strings.libraryGenrePhilosophy,
      'Psychology' => strings.libraryGenrePsychology,
      'Business' => strings.libraryGenreBusiness,
      'Finance & Investing' => strings.libraryGenreFinanceInvesting,
      'Technology' => strings.libraryGenreTechnology,
      'Science' => strings.libraryGenreScience,
      'Self-Development' => strings.libraryGenreSelfDevelopment,
      'Health & Wellness' => strings.libraryGenreHealthWellness,
      'Politics & Society' => strings.libraryGenrePoliticsSociety,
      'Art & Design' => strings.libraryGenreArtDesign,
      'Travel' => strings.libraryGenreTravel,
      'Comics & Graphic Novels' => strings.libraryGenreComicsGraphicNovels,
      'Fiction' => strings.libraryGenreFiction,
      'Action' => strings.libraryGenreAction,
      'Adventure' => strings.libraryGenreAdventure,
      'Animation' => strings.libraryGenreAnimation,
      'Comedy' => strings.libraryGenreComedy,
      'Crime' => strings.libraryGenreCrime,
      'Documentary' => strings.libraryGenreDocumentary,
      'Drama' => strings.libraryGenreDrama,
      'Family' => strings.libraryGenreFamily,
      'Mystery' => strings.libraryGenreMystery,
      'Thriller' => strings.libraryGenreThriller,
      'War' => strings.libraryGenreWar,
      'Western' => strings.libraryGenreWestern,
      'Music' => strings.libraryGenreMusic,
      'Other' => strings.libraryGenreOther,
      final value => value,
    };

String localizedLibrarySubtype(AppLocalizations strings, String? subtype) {
  final value = subtype?.trim() ?? '';
  return switch (value.toLowerCase()) {
    'movie' || 'film' => strings.libraryMovie,
    'tv show' || 'tv_show' || 'television' => strings.librarySubtypeTvShow,
    'series' => strings.librarySubtypeSeries,
    'documentary' => strings.libraryGenreDocumentary,
    _ when value.isEmpty => '',
    _ => '${value[0].toUpperCase()}${value.substring(1)}',
  };
}
