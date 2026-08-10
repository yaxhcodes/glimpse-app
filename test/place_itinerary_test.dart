import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/place_itinerary.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';
import 'package:glimpse/features/library/library_entity.dart';
import 'package:glimpse/features/library/place_itinerary_provider.dart';

void main() {
  test('splits long routes into overlapping five-stop segments', () {
    final stops = [for (var index = 0; index < 9; index++) _stop(index)];

    final segments = routeSegments(stops);

    expect(segments.map((segment) => segment.length), [5, 5]);
    expect(segments.first.last.title, segments.last.first.title);
    expect(segments.last.last.title, 'Stop 8');
  });

  test('omits unmapped stops and requires two mapped stops', () {
    final mapped = _stop(1);
    final unmapped = PlaceItineraryStop()..title = 'Unknown';

    expect(routeSegments([mapped, unmapped]), isEmpty);
    expect(routeSegments([mapped, _stop(2), unmapped]).single, hasLength(2));
  });

  test('relinks a stop by catalog identity before source fallback', () {
    final expected = _entity(
      key: 'resolved-key',
      provisionalKey: 'changed-provisional',
      catalogId: 'geo-1',
      sourceId: 2,
    );
    final stop = PlaceItineraryStop()
      ..entityKey = 'old-key'
      ..provisionalKey = 'old-provisional'
      ..catalogId = 'geo-1'
      ..catalogSource = 'geoapify'
      ..sourceUrlIds = [1];

    expect(resolveItineraryStop(stop, [expected]), same(expected));
  });

  test('builds an encoded Google Maps URL in manual stop order', () {
    final uri = googleMapsRouteUri([_stop(1), _stop(2), _stop(3)]);

    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['origin'], '21.0,71.0');
    expect(uri.queryParameters['waypoints'], '22.0,72.0');
    expect(uri.queryParameters['destination'], '23.0,73.0');
  });
}

PlaceItineraryStop _stop(int index) {
  return PlaceItineraryStop()
    ..title = 'Stop $index'
    ..latitude = 20 + index.toDouble()
    ..longitude = 70 + index.toDouble();
}

LibraryEntity _entity({
  required String key,
  required String provisionalKey,
  required String catalogId,
  required int sourceId,
}) {
  final mention = EnrichedMention(
    title: 'Place',
    type: 'place',
    catalogId: catalogId,
    catalogSource: 'geoapify',
  );
  return LibraryEntity(
    key: key,
    provisionalKey: provisionalKey,
    kind: LibraryEntityKind.place,
    mention: mention,
    sources: [
      LibrarySourceReference(
        urlId: sourceId,
        title: 'Source',
        domain: 'example.com',
        savedAt: DateTime(2026, 8, 1),
        provisionalKey: provisionalKey,
        mention: mention,
      ),
    ],
    discoveredAt: DateTime(2026, 8, 1),
  );
}
