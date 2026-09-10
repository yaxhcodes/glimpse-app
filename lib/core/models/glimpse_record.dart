import 'package:isar/isar.dart';

part 'glimpse_record.g.dart';

/// Shared by foreground discovery and background delivery. Content is versioned
/// separately from interaction state so a rebuild cannot undo a user's action.
@collection
class GlimpseRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String key;

  late String contentJson;
  late DateTime updatedAt;
  DateTime? openedAt;
  DateTime? retiredAt;
  DateTime? snoozedUntil;
  DateTime? postedAt;
  DateTime? reminderPostedAt;
  DateTime? deliveryLeaseUntil;
  String? synthesisJson;
  String? synthesisKey;
}
