import 'package:isar/isar.dart';

part 'user_collection.g.dart';

@collection
class UserCollection {
  Id id = Isar.autoIncrement;

  late String name;

  late String emoji;

  String? description;

  @Index()
  late DateTime createdAt;

  /// [SavedUrl.id] values in this collection.
  late List<int> urlIds;
}
