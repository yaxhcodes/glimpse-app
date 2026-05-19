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

  /// Timestamp aligned by index with [urlIds], recording when a link was
  /// added to this collection.
  ///
  /// Kept ignored for now to avoid a live Isar schema migration while this
  /// feature is iterating. Fresh collection-add times can be persisted once
  /// we add an explicit migration.
  @ignore
  List<DateTime>? urlAddedAts;
}
