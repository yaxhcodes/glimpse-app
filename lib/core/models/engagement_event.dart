import 'package:isar/isar.dart';

part 'engagement_event.g.dart';

/// The kinds of user behavior we record. Positive signals (open, tapThrough,
/// searchHit, cardOpened, notifOpened, intentSet) boost affinity; negative
/// signals (cardDismissed, cardSnoozed, notifDismissed) decay it.
enum EngagementEventType {
  save,
  open,
  tapThrough,
  search,
  searchHit,
  categoryVisit,
  clusterVisit,
  cardShown,
  cardOpened,
  cardDismissed,
  cardSnoozed,
  notifShown,
  notifOpened,
  notifDismissed,
  intentSet,
}

/// A single on-device behavior event — the raw fuel for the affinity model
/// that ranks Rediscover and notifications. Append-only, capped, time-decayed;
/// never leaves the device. See docs/behavioral-signal-engine-spec.md.
@collection
class EngagementEvent {
  Id id = Isar.autoIncrement;

  /// Stored by name so adding/reordering event types never corrupts old rows.
  @Enumerated(EnumType.name)
  late EngagementEventType type;

  @Index()
  late DateTime at;

  /// The save involved, if any.
  int? urlId;

  /// Denormalized content context for fast aggregation. Writers exclude
  /// platform/source names from [category] so affinity reflects topics.
  String? category;
  String? clusterLabel;
  String? source;

  /// Free-text search query (stays on device).
  String? query;

  /// Notification trigger type, for notif* events.
  String? triggerType;

  /// Local hour 0–23 at event time, for the notification timing model.
  late int hourLocal;
}
