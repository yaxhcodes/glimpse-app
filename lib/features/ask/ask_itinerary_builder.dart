import '../library/library_entity.dart';
import '../library/library_places_model.dart';
import 'ask_provider.dart';

class AskItineraryDraft {
  const AskItineraryDraft({
    required this.name,
    required this.areaKey,
    required this.areaTitle,
    required this.country,
    required this.entities,
  });

  final String name;
  final String areaKey;
  final String areaTitle;
  final String? country;
  final List<LibraryEntity> entities;
}

class AskItineraryBuilder {
  const AskItineraryBuilder._();

  static AskItineraryDraft? fromMessage(
    ChatMessage message,
    LibrarySnapshot snapshot,
  ) {
    final places = snapshot.ofKind(LibraryEntityKind.place);
    if (places.isEmpty) return null;

    final ordered = <LibraryEntity>[];
    final seen = <String>{};
    final handledSourceIds = <int>{};

    void add(LibraryEntity entity) {
      if (seen.add(entity.key)) ordered.add(entity);
    }

    for (final section in message.sections) {
      final candidates = _placesForSource(places, section.source.id);
      if (candidates.isEmpty) continue;
      final matches = candidates
          .where(
            (entity) => _mentionsPlace(
              heading: section.heading,
              summary: section.summary,
              title: entity.title,
            ),
          )
          .toList(growable: false);
      if (matches.isNotEmpty) {
        matches.forEach(add);
        handledSourceIds.add(section.source.id);
      } else if (candidates.length == 1) {
        add(candidates.single);
        handledSourceIds.add(section.source.id);
      }
    }

    for (final source in message.sources) {
      if (handledSourceIds.contains(source.id)) continue;
      for (final entity in _placesForSource(places, source.id)) {
        add(entity);
      }
    }
    if (ordered.isEmpty) return null;

    final areas = PlaceAreaIndex.build(ordered);
    final area = areas.reduce(
      (current, candidate) =>
          candidate.entities.length > current.entities.length
          ? candidate
          : current,
    );
    final hasNamedArea = area.key != unsortedPlacesAreaKey;
    return AskItineraryDraft(
      name: hasNamedArea ? 'A day in ${area.title}' : 'A day from my saves',
      areaKey: area.key,
      areaTitle: area.title,
      country:
          area.subtitle ??
          (area.entities.isEmpty ? null : area.entities.first.mention.country),
      entities: List.unmodifiable(ordered),
    );
  }

  static List<LibraryEntity> _placesForSource(
    Iterable<LibraryEntity> places,
    int sourceId,
  ) => places
      .where(
        (entity) => entity.sources.any((source) => source.urlId == sourceId),
      )
      .toList(growable: false);

  static bool _mentionsPlace({
    required String heading,
    required String summary,
    required String title,
  }) {
    final normalizedTitle = _normalize(title);
    if (normalizedTitle.length < 4) return false;
    final normalizedHeading = _normalize(heading);
    final normalizedSummary = _normalize(summary);
    return normalizedHeading.contains(normalizedTitle) ||
        (normalizedHeading.length >= 4 &&
            normalizedTitle.contains(normalizedHeading)) ||
        normalizedSummary.contains(normalizedTitle);
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
