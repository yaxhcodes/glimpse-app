/// Classifies the suggested-action chips shown in Details into a typed,
/// on-device intent signal that powers Rediscovery ranking and the
/// revisit-due notification.
///
/// The chip labels themselves are defined by `_buildNoteSuggestions` in
/// `url_detail_screen.dart`. This is the single source of truth for what each
/// label *means* — keep the two in sync when adding new chips.
///
/// Pure, no IO, no network. The user's intent never leaves the device.
library;

/// What tapping a suggested-action chip should do.
enum IntentKind {
  /// "Watch/Read/Revisit Later", "Try This Weekend", … — the user intends to
  /// come back. Sets `intentStatus = 'queued'` + a [ClassifiedIntent.revisitAfter].
  queue,

  /// "Already Watched/Read/Tried/Checked" — the user is finished. Sets
  /// `intentStatus = 'done'` (archived: hidden from library, never resurfaced).
  done,

  /// Everything else ("Share With Someone", "Make Checklist", …) — pure note
  /// text, the original behaviour (append the label to the user's notes).
  note,
}

/// The result of classifying a chip label.
class ClassifiedIntent {
  const ClassifiedIntent({
    required this.kind,
    required this.action,
    this.revisitAfter,
  });

  final IntentKind kind;

  /// Normalized snake_case key for the chip (e.g. 'watch_later'). Persisted as
  /// `SavedUrl.intentAction` so the chip can render its "set" state and so the
  /// revisit notification can say *why* ("you saved this to watch later").
  final String action;

  /// For [IntentKind.queue]: when the item should start actively resurfacing.
  /// Null for non-queue kinds.
  final DateTime? revisitAfter;
}

class IntentClassifier {
  IntentClassifier._();

  /// Labels (lowercased) that mean "I'll come back to this".
  static const _queueLabels = <String>{
    'watch later',
    'read later',
    'revisit later',
    'add to watchlist',
    'add to reading list',
    'try this weekend',
    'practice later',
  };

  /// Labels (lowercased) that mean "I'm finished with this".
  static const _doneLabels = <String>{
    'already watched',
    'already read',
    'already tried',
    'already checked',
  };

  /// Classify a chip [label] as of [now] (injectable for tests).
  static ClassifiedIntent classify(String label, {DateTime? now}) {
    final key = label.trim().toLowerCase();
    final action = _normalize(label);

    if (_doneLabels.contains(key)) {
      return ClassifiedIntent(kind: IntentKind.done, action: action);
    }
    if (_queueLabels.contains(key)) {
      return ClassifiedIntent(
        kind: IntentKind.queue,
        action: action,
        revisitAfter: _revisitAfterFor(key, now ?? DateTime.now()),
      );
    }
    return ClassifiedIntent(kind: IntentKind.note, action: action);
  }

  /// Normalize a label to a stable snake_case key.
  static String _normalize(String label) =>
      label.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  /// Smart default for when a queued item becomes due to resurface.
  static DateTime _revisitAfterFor(String key, DateTime now) {
    switch (key) {
      case 'try this weekend':
        return _nextSaturdayMorning(now);
      case 'watch later':
        return now.add(const Duration(days: 2));
      default:
        return now.add(const Duration(days: 3));
    }
  }

  /// Upcoming Saturday at 9am. If today is Saturday, use today (still morning)
  /// or next Saturday otherwise — keep it simple: the coming Saturday 9am, and
  /// if that's already past, the one after.
  static DateTime _nextSaturdayMorning(DateTime now) {
    // DateTime.saturday == 6.
    var daysUntil = (DateTime.saturday - now.weekday) % 7;
    var target = DateTime(now.year, now.month, now.day, 9)
        .add(Duration(days: daysUntil));
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 7));
    }
    return target;
  }
}
