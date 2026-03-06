import 'package:isar/isar.dart';

part 'saved_url.g.dart';

@collection
class SavedUrl {
  Id id = Isar.autoIncrement;

  @Index()
  late String rawUrl;

  late String domain;

  @Index(type: IndexType.value)
  late String title;

  late String description;

  String? thumbnailUrl;

  @Index()
  late String category;

  late String categoryEmoji;

  late List<String> tags;

  String? userNotes;

  late DateTime savedAt;

  /// Embedding vector for semantic search (e.g., 1024-dim).
  /// Stored as a flat list of doubles.
  late List<double> embedding;
}
