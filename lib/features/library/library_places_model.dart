import 'library_entity.dart';

const allPlacesAreaKey = 'all';
const unsortedPlacesAreaKey = 'unsorted';

class PlaceArea {
  const PlaceArea({
    required this.key,
    required this.title,
    this.subtitle,
    required this.entities,
  });

  final String key;
  final String title;
  final String? subtitle;
  final List<LibraryEntity> entities;

  int get mappedCount =>
      entities.where((entity) => entity.mention.hasCoordinates).length;

  LibraryEntity? get newestEntity => entities.firstOrNull;
}

class PlaceAreaIndex {
  const PlaceAreaIndex._();

  static List<PlaceArea> build(Iterable<LibraryEntity> entities) {
    final groups = <String, _PlaceAreaBuilder>{};
    for (final entity in entities) {
      final city = _clean(entity.mention.city);
      final country = _clean(entity.mention.country);
      final key = _areaKey(city, country);
      groups
          .putIfAbsent(
            key,
            () => _PlaceAreaBuilder(city: city, country: country),
          )
          .entities
          .add(entity);
    }

    final areas = groups.entries.map((entry) {
      final builder = entry.value;
      builder.entities.sort((a, b) => b.discoveredAt.compareTo(a.discoveredAt));
      final title = builder.city ?? builder.country ?? 'Unsorted places';
      final subtitle = builder.city != null ? builder.country : null;
      return PlaceArea(
        key: entry.key,
        title: title,
        subtitle: subtitle,
        entities: List.unmodifiable(builder.entities),
      );
    }).toList();

    areas.sort((a, b) {
      if (a.key == unsortedPlacesAreaKey) return 1;
      if (b.key == unsortedPlacesAreaKey) return -1;
      final newest = b.entities.first.discoveredAt.compareTo(
        a.entities.first.discoveredAt,
      );
      return newest != 0 ? newest : a.title.compareTo(b.title);
    });
    return List.unmodifiable(areas);
  }

  static String keyFor(LibraryEntity entity) =>
      _areaKey(_clean(entity.mention.city), _clean(entity.mention.country));

  static String _areaKey(String? city, String? country) {
    if (city == null && country == null) return unsortedPlacesAreaKey;
    return '${_normalize(city ?? '')}|${_normalize(country ?? '')}';
  }

  static String? _clean(String? value) {
    final cleaned = value?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    return cleaned.isEmpty ? null : cleaned;
  }

  static String _normalize(String value) => value.toLowerCase();
}

Map<String, String?> uniquePlaceImageUrls(Iterable<LibraryEntity> entities) {
  final used = <String>{};
  return {
    for (final entity in entities)
      entity.key: switch (entity.placeImageUrl?.trim() ?? '') {
        final url when url.isEmpty => null,
        final url when used.add(url) => url,
        _ => null,
      },
  };
}

class _PlaceAreaBuilder {
  _PlaceAreaBuilder({required this.city, required this.country});

  final String? city;
  final String? country;
  final List<LibraryEntity> entities = [];
}
