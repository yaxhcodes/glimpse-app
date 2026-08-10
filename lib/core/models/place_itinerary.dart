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

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude! >= -90 &&
      latitude! <= 90 &&
      longitude! >= -180 &&
      longitude! <= 180;
}
