import 'package:isar/isar.dart';

part 'place_itinerary.g.dart';

@collection
class PlaceItinerary {
  Id id = Isar.autoIncrement;

  late String name;

  String? areaKey;
  String? areaTitle;
  String? country;
  DateTime? date;

  /// The save whose plan this was laid out from, when it came from one.
  int? sourceUrlId;

  @Index()
  late DateTime createdAt;

  @Index()
  late DateTime updatedAt;

  late List<PlaceItineraryStop> stops;
}

@embedded
class PlaceItineraryStop {
  String entityKey = '';
  String provisionalKey = '';
  String? catalogId;
  String? catalogSource;
  List<int> sourceUrlIds = [];
  String title = '';
  String? city;
  String? country;
  double? latitude;
  double? longitude;
  String? imageUrl;

  /// Day of the trip, from 1. Plans made before days existed read as day 1.
  int? day;

  /// As the source stated them: "9:00", "20 min walk from the station".
  String? time;
  String? travel;
  String? note;

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude! >= -90 &&
      latitude! <= 90 &&
      longitude! >= -180 &&
      longitude! <= 180 &&
      !(latitude == 0 && longitude == 0);
}

extension PlaceItineraryStopDay on PlaceItineraryStop {
  int get dayNumber => (day ?? 1) < 1 ? 1 : (day ?? 1);
}
