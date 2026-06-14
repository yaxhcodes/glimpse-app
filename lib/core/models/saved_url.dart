import 'package:isar/isar.dart';

import 'url_processing_status.dart';

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

  /// Durable structured enrichment payload for content recommendations.
  ///
  /// This stores actor/Gemini-derived entities such as books, movies, recipes,
  /// creator, stats, and captions so Details can remain stable after app restarts.
  String? enrichmentJson;

  /// Durable lifecycle state for the URL ingestion/enrichment pipeline.
  ///
  /// Older rows may have this null; new saves move through
  /// PENDING -> QUEUED -> EXTRACTING -> ENRICHING -> GENERATING_EMBEDDINGS
  /// -> READY, or RETRYING/FAILED when recovery is still in progress/exhausted.
  String? processingStatus;

  /// Correlates local save state with backend structured logs.
  String? processingId;

  /// Number of extraction/enrichment attempts made for this save.
  int? processingAttempt;

  /// Last lifecycle state transition time.
  DateTime? processingUpdatedAt;

  /// Last non-sensitive processing error code/reason.
  String? processingError;

  late DateTime savedAt;

  /// When the user first opened the link from the app (null = never opened).
  DateTime? openedAt;

  /// Last time this link was shown in rediscovery (limits repeat surfacing).
  DateTime? resurfacedAt;

  /// Embedding vector for semantic search (1024-dim from Voyage AI).
  /// Null or empty until embedded (new saves or backfill).
  List<double>? embedding;

  /// Capture session ID for batch / multi-URL saves.
  /// Not persisted in Isar (migration-safe); stored via [SessionTrackingService].
  @ignore
  String? saveSessionId;

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

  @ignore
  bool get isProcessingActive => UrlProcessingStatus.isActive(processingStatus);

  @ignore
  bool get isProcessingReady =>
      processingStatus == UrlProcessingStatus.ready ||
      ((processingStatus == null || processingStatus!.trim().isEmpty) &&
          ((enrichmentJson ?? '').trim().isNotEmpty ||
              (summary ?? '').trim().isNotEmpty));
}
