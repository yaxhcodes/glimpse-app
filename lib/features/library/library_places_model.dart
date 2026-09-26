import 'library_entity.dart';
import 'place_geography.dart';
import 'place_locality_provider.dart';

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

  /// The area key of a country, as [byCountry] keys it.
  static String countryKey(String country) =>
      '$_countryPrefix${_normalize(country.replaceAll(RegExp(r'\s+'), ' ').trim())}';

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

/// Places in one city, or [title] null for the places whose city holds only
/// them (one-place headings fragment the list the way city chips once did).
class PlaceCityGroup {
  const PlaceCityGroup({
    required this.key,
    required this.title,
    required this.entities,
  });

  final String key;
  final String? title;
  final List<LibraryEntity> entities;
}

/// Places in one state, prefecture or province, or [title] null for places
/// the geocoder could not place in one.
class PlaceRegionGroup {
  const PlaceRegionGroup({
    required this.key,
    required this.title,
    required this.cities,
  });

  final String key;
  final String? title;
  final List<PlaceCityGroup> cities;

  List<LibraryEntity> get entities => [
    for (final city in cities) ...city.entities,
  ];

  int get length =>
      cities.fold(0, (total, city) => total + city.entities.length);
}

/// Region and city for grouping a country's places.
class PlaceSubdivisions {
  const PlaceSubdivisions._();

  static const otherRegionKey = 'region:';

  static String? regionOf(LibraryEntity entity, PlaceLocality? locality) {
    final region = locality?.region?.trim() ?? '';
    if (region.isEmpty || isNonLatinName(region)) return null;
    final country = _norm(entity.mention.country);
    final short = shortRegionName(region);
    // City-states geocode to themselves ("Singapore, Singapore").
    if (_norm(short) == country || _norm(region) == country) return null;
    return short;
  }

  /// The saved city, else the geocoded town. Skips a "city" that only
  /// repeats the region (the resolver falls back to the state when a place
  /// has no town), the country or the place's own name — unless the
  /// geocoder also calls the town that, as with Kyoto in Kyoto.
  static String? cityOf(LibraryEntity entity, PlaceLocality? locality) {
    final region = locality?.region ?? '';
    final town = _norm(locality?.city);
    final geocodedTown = locality?.city;
    final skip = {
      _norm(region),
      _norm(shortRegionName(region)),
      _norm(entity.mention.country),
      _norm(entity.title),
    }..removeAll({'', town});
    for (final candidate in [
      entity.mention.city,
      if (geocodedTown != null && !isNonLatinName(geocodedTown)) geocodedTown,
    ]) {
      final city = candidate?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
      if (city.isEmpty || skip.contains(_norm(city))) continue;
      return city;
    }
    return null;
  }

  /// Groups [entities] (already newest first) by region, then city. Larger
  /// groups lead; the unnamed groups go last.
  static List<PlaceRegionGroup> group(
    Iterable<LibraryEntity> entities, {
    required PlaceLocality? Function(LibraryEntity entity) localityOf,
  }) {
    final regions = <String, List<LibraryEntity>>{};
    final regionTitles = <String, String>{};
    final cityTitles = <String, String?>{};
    for (final entity in entities) {
      final locality = localityOf(entity);
      final region = regionOf(entity, locality);
      final key = region == null ? otherRegionKey : 'region:${_norm(region)}';
      regions.putIfAbsent(key, () => []).add(entity);
      if (region != null) regionTitles.putIfAbsent(key, () => region);
      cityTitles[entity.key] = cityOf(entity, locality);
    }

    final groups = [
      for (final MapEntry(:key, value: members) in regions.entries)
        PlaceRegionGroup(
          key: key,
          title: regionTitles[key],
          cities: _cities(key, members, cityTitles),
        ),
    ];
    groups.sort((a, b) {
      if (a.title == null) return 1;
      if (b.title == null) return -1;
      final size = b.length.compareTo(a.length);
      return size != 0 ? size : a.title!.compareTo(b.title!);
    });
    return List.unmodifiable(groups);
  }

  static List<PlaceCityGroup> _cities(
    String regionKey,
    List<LibraryEntity> members,
    Map<String, String?> cityTitles,
  ) {
    final byCity = <String, List<LibraryEntity>>{};
    final titles = <String, String>{};
    for (final entity in members) {
      final city = cityTitles[entity.key];
      final key = city == null ? '' : _norm(city);
      byCity.putIfAbsent(key, () => []).add(entity);
      if (city != null) titles.putIfAbsent(key, () => city);
    }
    final named = <PlaceCityGroup>[];
    final rest = <LibraryEntity>[];
    for (final MapEntry(:key, value: places) in byCity.entries) {
      if (key.isEmpty || places.length < 2) {
        rest.addAll(places);
      } else {
        named.add(
          PlaceCityGroup(
            key: '$regionKey|$key',
            title: titles[key],
            entities: List.unmodifiable(places),
          ),
        );
      }
    }
    named.sort((a, b) {
      final size = b.entities.length.compareTo(a.entities.length);
      return size != 0 ? size : a.title!.compareTo(b.title!);
    });
    if (rest.isNotEmpty) {
      final order = {for (final (i, e) in members.indexed) e.key: i};
      rest.sort((a, b) => order[a.key]!.compareTo(order[b.key]!));
      named.add(
        PlaceCityGroup(
          key: '$regionKey|',
          title: null,
          entities: List.unmodifiable(rest),
        ),
      );
    }
    return List.unmodifiable(named);
  }

  /// A saved "place" that is the whole state it sits in ("Madhya Pradesh"
  /// in Madhya Pradesh): the area, not a pin.
  static bool isWholeRegion(LibraryEntity entity, PlaceLocality? locality) {
    final region = regionOf(entity, locality);
    if (region == null) return false;
    final title = _norm(entity.title);
    return title == _norm(region) ||
        title == _norm(locality?.region) ||
        _norm(shortRegionName(entity.title)) == _norm(region);
  }

  static String _norm(String? value) =>
      value?.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase() ?? '';
}

class _PlaceAreaBuilder {
  _PlaceAreaBuilder({required this.city, required this.country});

  final String? city;
  final String? country;
  final List<LibraryEntity> entities = [];
}
