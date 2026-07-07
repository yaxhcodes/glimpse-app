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
  /// PENDING -> QUEUED -> PROCESSING -> EXTRACTING -> ENRICHING
  /// -> GENERATING_EMBEDDINGS -> COMPLETED, or PARTIAL when one or more
  /// enrichment tasks failed after the bookmark was already saved.
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

  /// When the user dismissed this link from Rediscovery ("not now"). Dismissed
  /// links are excluded from all rediscovery surfaces. Null = not dismissed.
  DateTime? rediscoverDismissedAt;

  /// User intent captured from the suggested-action chips in Details.
  /// Null = none | 'queued' (will revisit) | 'done' (finished/archived).
  ///
  /// This is the on-device intent signal that powers Rediscovery ranking and
  /// the revisit-due notification. Nothing leaves the device.
  @Index()
  String? intentStatus;

  /// The specific chip that set [intentStatus], normalized
  /// (e.g. 'watch_later', 'already_read'). Drives "why now" copy + chip state.
  String? intentAction;

  /// When [intentStatus] was last set.
  DateTime? intentSetAt;

  /// For 'queued' items: the earliest time to actively resurface / notify.
  /// Null = no specific time (treated as "soon").
  DateTime? revisitAfter;

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

  /// User has finished with this save ("Already Watched/Read/Tried/Checked").
  /// Done items are archived: hidden from the main library and excluded from
  /// all Rediscovery + notification surfaces.
  @ignore
  bool get isDone => intentStatus == 'done';

  /// User explicitly intends to come back ("Watch/Read/Revisit Later", etc.).
  @ignore
  bool get isQueued => intentStatus == 'queued';

  /// A queued item whose [revisitAfter] window has arrived (or has none) — the
  /// strongest signal to resurface it now.
  @ignore
  bool get isRevisitDue =>
      isQueued &&
      (revisitAfter == null || !revisitAfter!.isAfter(DateTime.now()));

  @ignore
  bool get hasPresentableEnrichment =>
      (enrichmentJson ?? '').trim().isNotEmpty ||
      (summary ?? '').trim().isNotEmpty;

  @ignore
  bool get hasTimedOutProcessing {
    final updatedAt = processingUpdatedAt;
    if (updatedAt == null) return false;
    return DateTime.now().difference(updatedAt) > const Duration(minutes: 15);
  }

  @ignore
  bool get isProcessingActive =>
      UrlProcessingStatus.isActive(processingStatus) &&
      !hasPresentableEnrichment &&
      !hasTimedOutProcessing;

  @ignore
  bool get isProcessingFailed =>
      !hasPresentableEnrichment &&
      (processingStatus == UrlProcessingStatus.partial ||
          processingStatus == UrlProcessingStatus.failed);

  @ignore
  bool get isProcessingReady =>
      UrlProcessingStatus.isSuccessfulTerminal(processingStatus) ||
      hasPresentableEnrichment;
}
