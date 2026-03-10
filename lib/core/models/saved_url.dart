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

  /// AI-generated 2–3 sentence summary of the page content.
  String? summary;

  late DateTime savedAt;

  /// Embedding vector for semantic search (1024-dim from Voyage AI).
  late List<double> embedding;
}
