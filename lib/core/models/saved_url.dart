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

  /// Stored list of categories this URL belongs to.
  /// The first item is the primary topic category; others can include platform buckets.
  late List<String> categories;

  late List<String> tags;

  String? userNotes;

  /// AI-generated 2–3 sentence summary of the page content.
  String? summary;

  late DateTime savedAt;

  /// When the user first opened the link from the app (null = never opened).
  DateTime? openedAt;

  /// Last time this link was shown in rediscovery (limits repeat surfacing).
  DateTime? resurfacedAt;

  /// Embedding vector for semantic search (1024-dim from Voyage AI).
  /// Null or empty until embedded (new saves or backfill).
  List<double>? embedding;

  List<String> get effectiveCategories {
    final values = <String>[];
    for (final item in categories) {
      final trimmed = item.trim();
      if (trimmed.isNotEmpty && !values.contains(trimmed)) {
        values.add(trimmed);
      }
    }
    if (category.trim().isNotEmpty && !values.contains(category.trim())) {
      values.add(category.trim());
    }
    if (values.isEmpty) {
      values.add('Other');
    }
    return values;
  }
}
