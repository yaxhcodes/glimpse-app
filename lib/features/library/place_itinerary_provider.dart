import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/place_itinerary.dart';
import '../../core/providers/service_providers.dart';
import 'library_entity.dart';

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
