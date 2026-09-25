import 'package:isar/isar.dart';

part 'ask_conversation.g.dart';

@collection
class AskConversation {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String key;
  late String title;
  late DateTime createdAt;
  @Index()
  late DateTime updatedAt;
  int version = 1;
  String? focusedUrl;

  /// Versioned messages use canonical URL references, which survive restore.
  late String messagesJson;
}
