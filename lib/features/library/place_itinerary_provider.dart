import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/place_itinerary.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/transcript_enrichment_service.dart';
import 'library_entity.dart';
import 'library_places_model.dart';

final placeItinerariesProvider = StreamProvider<List<PlaceItinerary>>((ref) {
  return ref.watch(isarServiceProvider).watchPlaceItineraries();
});

final placeItineraryProvider = Provider.family<PlaceItinerary?, int>((ref, id) {
  final itineraries = ref.watch(placeItinerariesProvider).valueOrNull;
  if (itineraries == null) return null;
  for (final itinerary in itineraries) {
    if (itinerary.id == id) return itinerary;
  }
  return null;
});

class PlaceItineraryActions {
  const PlaceItineraryActions(this._ref);

  final Ref _ref;

  Future<int> save(PlaceItinerary itinerary) {
    itinerary.updatedAt = DateTime.now();
    return _ref.read(isarServiceProvider).savePlaceItinerary(itinerary);
  }

  Future<void> delete(int id) =>
      _ref.read(isarServiceProvider).deletePlaceItinerary(id);
}

final placeItineraryActionsProvider = Provider<PlaceItineraryActions>(
  PlaceItineraryActions.new,
);

PlaceItineraryStop itineraryStopFromEntity(LibraryEntity entity) {
  return PlaceItineraryStop()
    ..entityKey = entity.key
    ..provisionalKey = entity.provisionalKey
    ..catalogId = entity.mention.catalogId
    ..catalogSource = entity.mention.catalogSource
    ..sourceUrlIds = entity.sources
        .map((source) => source.urlId)
        .toList(growable: false)
    ..title = entity.title
    ..city = entity.mention.city
    ..country = entity.mention.country
    ..latitude = entity.mention.latitude
    ..longitude = entity.mention.longitude
    ..imageUrl = entity.placeImageUrl;
}

LibraryEntity? resolveItineraryStop(
  PlaceItineraryStop stop,
  Iterable<LibraryEntity> entities,
) {
  final catalogId = stop.catalogId?.trim() ?? '';
  final catalogSource = stop.catalogSource?.trim().toLowerCase() ?? '';
  final sourceIds = stop.sourceUrlIds.toSet();
  LibraryEntity? provisionalMatch;
  LibraryEntity? sourceMatch;
  for (final entity in entities) {
    if (entity.key == stop.entityKey) return entity;
    if (catalogId.isNotEmpty &&
        catalogSource.isNotEmpty &&
        entity.mention.catalogId?.trim() == catalogId &&
        entity.mention.catalogSource?.trim().toLowerCase() == catalogSource) {
      return entity;
    }
    if (provisionalMatch == null &&
        stop.provisionalKey.isNotEmpty &&
        entity.provisionalKey == stop.provisionalKey) {
      provisionalMatch = entity;
    }
    if (sourceMatch == null &&
        entity.sources.any((source) => sourceIds.contains(source.urlId))) {
      sourceMatch = entity;
    }
  }
  return provisionalMatch ?? sourceMatch;
}

List<List<PlaceItineraryStop>> routeSegments(
  Iterable<PlaceItineraryStop> stops, {
  int maxStopsPerSegment = 5,
}) {
  assert(maxStopsPerSegment >= 2);
  final mapped = stops.where((stop) => stop.hasCoordinates).toList();
  if (mapped.length < 2) return const [];
  if (mapped.length <= maxStopsPerSegment) return [List.unmodifiable(mapped)];
  final segments = <List<PlaceItineraryStop>>[];
  var start = 0;
  while (start < mapped.length - 1) {
    final end = (start + maxStopsPerSegment).clamp(0, mapped.length);
    final segment = mapped.sublist(start, end);
    if (segment.length >= 2) segments.add(List.unmodifiable(segment));
    if (end == mapped.length) break;
    start = end - 1;
  }
  return List.unmodifiable(segments);
}

Uri googleMapsRouteUri(List<PlaceItineraryStop> stops) {
  if (stops.length < 2 || stops.any((stop) => !stop.hasCoordinates)) {
    throw ArgumentError.value(
      stops,
      'stops',
      'A route needs at least two mapped stops',
    );
  }
  String coordinates(PlaceItineraryStop stop) =>
      '${stop.latitude},${stop.longitude}';
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'origin': coordinates(stops.first),
    'destination': coordinates(stops.last),
    if (stops.length > 2)
      'waypoints': stops
          .sublist(1, stops.length - 1)
          .map(coordinates)
          .join('|'),
  });
}

/// The plan made from save [urlId], if one was.
PlaceItinerary? itineraryFromSaveId(Iterable<PlaceItinerary> plans, int urlId) {
  for (final plan in plans) {
    if (plan.sourceUrlId == urlId) return plan;
  }
  return null;
}

/// Lays a save out as a plan: the days and order its itinerary gives, or its
/// places in the order it names them. Stops are the Library's copies of those
/// places, so they carry the resolved pins; a stop the Library could not
/// resolve keeps its name and waits for a location.
PlaceItinerary itineraryFromSave({
  required int urlId,
  required String name,
  required EnrichedItinerary? plan,
  required List<EnrichedMention> savePlaces,
  required Iterable<LibraryEntity> libraryPlaces,
  DateTime? now,
}) {
  final created = now ?? DateTime.now();
  final steps = plan == null
      ? [
          for (final place in savePlaces)
            (
              day: 1,
              stop: EnrichedItineraryStop(
                name: place.title,
                note: place.whyMentioned,
              ),
            ),
        ]
      : [
          for (final day in plan.days)
            for (final stop in day.stops) (day: day.day, stop: stop),
        ];

  final stops = <PlaceItineraryStop>[];
  final seen = <String>{};
  for (final (:day, :stop) in steps) {
    final mention = _savePlaceNamed(stop.name, savePlaces);
    final entity = placeEntityForSaveStop(
      mention?.title ?? stop.name,
      urlId,
      libraryPlaces,
    );
    final PlaceItineraryStop built;
    if (entity != null) {
      built = itineraryStopFromEntity(entity);
    } else {
      built = PlaceItineraryStop()
        ..title = LibraryIndex.placeDisplayTitle(mention?.title ?? stop.name)
        ..city = mention?.city
        ..country = mention?.country;
      if (mention != null) {
        built.provisionalKey = LibraryIndex.provisionalKeyFor(
          LibraryEntityKind.place,
          mention,
        );
      }
    }
    // One visit per place and day; a place the plan returns to on another
    // day stays on both.
    if (!seen.add('$day|${built.entityKey}|${_placeKey(built.title)}')) {
      continue;
    }
    stops.add(
      built
        ..day = day
        ..time = stop.time
        ..travel = stop.travel
        ..note = stop.note ?? (plan == null ? null : mention?.whyMentioned),
    );
  }

  // Without days of its own, a save's places are still more than a day
  // when they span a country; keep its order and split by time.
  if (plan == null && estimateStops(stops).exceedsADay) assignDays(stops);

  final countries = <String, int>{};
  for (final stop in stops) {
    final country = stop.country?.trim() ?? '';
    if (country.isNotEmpty) countries[country] = (countries[country] ?? 0) + 1;
  }
  final country = countries.entries
      .fold<MapEntry<String, int>?>(
        null,
        (best, entry) =>
            best == null || entry.value > best.value ? entry : best,
      )
      ?.key;

  return PlaceItinerary()
    ..name = name
    ..sourceUrlId = urlId
    ..areaKey = country == null
        ? unsortedPlacesAreaKey
        : PlaceAreaIndex.countryKey(country)
    ..areaTitle = country
    ..country = country
    ..createdAt = created
    ..updatedAt = created
    ..stops = stops;
}

/// The Library's place for a stop named [name] in save [urlId]: the entity
/// that save contributed under that name, else one titled the same.
LibraryEntity? placeEntityForSaveStop(
  String name,
  int urlId,
  Iterable<LibraryEntity> places,
) {
  final key = _placeKey(name);
  if (key.isEmpty) return null;
  LibraryEntity? titled;
  for (final entity in places) {
    for (final source in entity.sources) {
      if (source.urlId == urlId && _placeKey(source.mention.title) == key) {
        return entity;
      }
    }
    if (titled == null && _placeKey(entity.title) == key) titled = entity;
  }
  return titled;
}

EnrichedMention? _savePlaceNamed(String name, List<EnrichedMention> places) {
  final key = _placeKey(name);
  if (key.isEmpty) return null;
  for (final place in places) {
    if (_placeKey(place.title) == key) return place;
  }
  // "Skazka" for "Skazka Canyon": the stop may shorten the place's name.
  if (key.length < 4) return null;
  for (final place in places) {
    final title = _placeKey(place.title);
    if (title.contains(key) || key.contains(title) && title.length >= 4) {
      return place;
    }
  }
  return null;
}

String _placeKey(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();

/// A rough sense of how long a run of stops takes: a visit at each, plus
/// driving between pins. Deliberately approximate; shown as "about".
class ItineraryEstimate {
  const ItineraryEstimate({required this.hours, required this.km});

  final double hours;
  final double km;

  bool get exceedsADay => hours > itineraryDayHours;

  /// Days this would take at [itineraryDayHours] a day.
  int get days => (hours / itineraryDayHours).ceil().clamp(1, 99);
}

/// Hours of visiting and travel one day holds.
const itineraryDayHours = 9.0;
const _visitHours = 1.5;
const _roadFactor = 1.3;
const _speedKmh = 50.0;

ItineraryEstimate estimateStops(Iterable<PlaceItineraryStop> stops) {
  var hours = 0.0;
  var km = 0.0;
  PlaceItineraryStop? previous;
  for (final stop in stops) {
    hours += _visitHours;
    if (previous != null) {
      final leg = _roadKm(previous, stop);
      km += leg;
      hours += leg / _speedKmh;
    }
    if (stop.hasCoordinates) previous = stop;
  }
  return ItineraryEstimate(hours: hours, km: km);
}

/// The time [day] of a plan takes, counting the drive from wherever the
/// day before ended.
ItineraryEstimate estimateDay(List<PlaceItineraryStop> stops, int day) {
  final first = stops.indexWhere((stop) => stop.dayNumber == day);
  if (first < 0) return const ItineraryEstimate(hours: 0, km: 0);
  PlaceItineraryStop? before;
  for (var i = first - 1; i >= 0; i--) {
    if (stops[i].hasCoordinates) {
      before = stops[i];
      break;
    }
  }
  final own = estimateStops(stops.where((stop) => stop.dayNumber == day));
  final firstMapped = stops
      .skip(first)
      .where((stop) => stop.dayNumber == day && stop.hasCoordinates)
      .firstOrNull;
  if (before == null || firstMapped == null) return own;
  final leg = _roadKm(before, firstMapped);
  return ItineraryEstimate(
    hours: own.hours + leg / _speedKmh,
    km: own.km + leg,
  );
}

/// Files [stops] into days of about [itineraryDayHours] each, keeping their
/// order; the drive to a day's first stop counts toward that day.
void assignDays(List<PlaceItineraryStop> stops) {
  var day = 1;
  var hours = 0.0;
  PlaceItineraryStop? previous;
  for (final stop in stops) {
    final leg = previous == null ? 0.0 : _roadKm(previous, stop) / _speedKmh;
    final cost = leg + _visitHours;
    if (hours > 0 && hours + cost > itineraryDayHours) {
      day++;
      hours = cost;
    } else {
      hours += cost;
    }
    stop.day = day;
    if (stop.hasCoordinates) previous = stop;
  }
}

/// A drivable order for stops with no order of their own: start at the
/// westernmost pin and keep going to the nearest unvisited one. Stops without
/// a pin go last, in their original order.
List<PlaceItineraryStop> routeOrder(List<PlaceItineraryStop> stops) {
  final mapped = stops.where((stop) => stop.hasCoordinates).toList();
  final unmapped = stops.where((stop) => !stop.hasCoordinates);
  if (mapped.length < 3) return [...mapped, ...unmapped];
  mapped.sort((a, b) => a.longitude!.compareTo(b.longitude!));
  final ordered = [mapped.removeAt(0)];
  while (mapped.isNotEmpty) {
    final last = ordered.last;
    var nearest = 0;
    for (var i = 1; i < mapped.length; i++) {
      if (_roadKm(last, mapped[i]) < _roadKm(last, mapped[nearest])) {
        nearest = i;
      }
    }
    ordered.add(mapped.removeAt(nearest));
  }
  return [...ordered, ...unmapped];
}

double _roadKm(PlaceItineraryStop a, PlaceItineraryStop b) {
  if (!a.hasCoordinates || !b.hasCoordinates) return 0;
  const earthKm = 6371.0;
  double rad(double degrees) => degrees * math.pi / 180;
  final dLat = rad(b.latitude! - a.latitude!);
  final dLon = rad(b.longitude! - a.longitude!);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude!)) *
          math.cos(rad(b.latitude!)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earthKm * math.asin(math.sqrt(h)) * _roadFactor;
}

/// "about 6 h · 180 km", for a day or a whole plan.
String describeEstimate(ItineraryEstimate estimate) {
  final halfHours = (estimate.hours * 2).round() / 2;
  final hours = estimate.hours < 1
      ? 'under 1 h'
      : 'about ${halfHours == halfHours.roundToDouble() ? halfHours.round() : halfHours} h';
  if (estimate.km < 5) return hours;
  final km = estimate.km < 50
      ? estimate.km.round()
      : (estimate.km / 10).round() * 10;
  return '$hours · $km km';
}
