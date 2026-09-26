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

  /// One area per country, largest first. City-level areas fragment a trip
  /// into dozens of one-place chips; a country is how people browse.
  static List<PlaceArea> byCountry(Iterable<LibraryEntity> entities) {
    final groups = <String, List<LibraryEntity>>{};
    final titles = <String, String>{};
    for (final entity in entities) {
      final country = _clean(entity.mention.country);
      final key = country == null
          ? unsortedPlacesAreaKey
          : '$_countryPrefix${_normalize(country)}';
      groups.putIfAbsent(key, () => []).add(entity);
      if (country != null) titles.putIfAbsent(key, () => country);
    }
    final areas = [
      for (final MapEntry(:key, :value) in groups.entries)
        PlaceArea(
          key: key,
          title: titles[key] ?? 'Unsorted places',
          entities: List.unmodifiable(
            [...value]
              ..sort((a, b) => b.discoveredAt.compareTo(a.discoveredAt)),
          ),
        ),
    ];
    areas.sort((a, b) {
      if (a.key == unsortedPlacesAreaKey) return 1;
      if (b.key == unsortedPlacesAreaKey) return -1;
      final size = b.entities.length.compareTo(a.entities.length);
      return size != 0 ? size : a.title.compareTo(b.title);
    });
    return List.unmodifiable(areas);
  }

  /// Whether [entity] belongs to [areaKey], which may be a country area or
  /// a city-level area saved by an older plan.
  static bool contains(String areaKey, LibraryEntity entity) {
    if (areaKey == allPlacesAreaKey) return true;
    if (areaKey == unsortedPlacesAreaKey) {
      return _clean(entity.mention.country) == null;
    }
    if (areaKey.startsWith(_countryPrefix)) {
      final country = _clean(entity.mention.country);
      return country != null &&
          areaKey == '$_countryPrefix${_normalize(country)}';
    }
    return keyFor(entity) == areaKey;
  }

  /// Plans made before country areas stored a `city|country` key.
  static bool planInArea(String? planAreaKey, String areaKey) {
    if (planAreaKey == null) return false;
    if (areaKey == allPlacesAreaKey || planAreaKey == areaKey) return true;
    if (!areaKey.startsWith(_countryPrefix)) return false;
    return planAreaKey.endsWith('|${areaKey.substring(_countryPrefix.length)}');
  }

  static const _countryPrefix = 'country:';

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
