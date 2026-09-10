import '../../core/models/engagement_event.dart';
import '../../core/models/saved_url.dart';
import '../../core/services/saved_highlights_service.dart';
import '../../core/services/saved_url_subject_resolver.dart';
import '../../core/services/summary_rewriter.dart';
import '../rediscover/rediscover_topic_pulse.dart';
import 'glimpse.dart';

class GlimpseBuildRequest {
  const GlimpseBuildRequest(this.urls, this.events, this.now);
  final List<SavedUrl> urls;
  final List<EngagementEvent> events;
  final DateTime now;
}

/// Pure, bounded candidate construction; invoked in an isolate by the service.
List<Glimpse> buildGlimpses(GlimpseBuildRequest request) {
  final now = request.now;
  final urls = request.urls
      .where((u) => !u.isInBin && !u.savedAt.isAfter(now))
      .toList();
  final liveById = {for (final u in urls) u.id: u};
  final active = urls
      .where(
        (u) =>
            !u.isDone &&
            u.rediscoverDismissedAt == null &&
            !u.isProcessingActive,
      )
      .toList();
  final byId = {for (final u in active) u.id: u};
  final evidence = {for (final u in urls) u.id: evidenceForSave(u)};
  final subjects = SavedUrlSubjectIndex();
  final result = <Glimpse>[];

  for (final u in active) {
    final subject = subjects.resolve(u);
    final itemEvidence = evidence[u.id];
    if (u.isQueued) {
      final due = u.revisitAfter ?? u.intentSetAt ?? u.savedAt;
      result.add(
        Glimpse(
          key: 'intention:${u.id}:${due.toIso8601String()}',
          kind: GlimpseKind.intention,
          topicKey: subject?.key ?? 'save:${u.id}',
          topicLabel: subject?.label ?? '',
          sourceIds: [u.id],
          evidence: [?itemEvidence],
          createdAt: u.intentSetAt ?? u.savedAt,
          availableAt: due,
          expiresAt: due.add(const Duration(days: 3650)),
          score: 120,
        ),
      );
      continue;
    }
    if (now.difference(u.savedAt).inDays < 14 || itemEvidence == null) continue;
    // A personal selection is stronger than another algorithm-selected summary.
    final score = switch (itemEvidence.kind) {
      GlimpseEvidenceKind.highlight => 88.0,
      GlimpseEvidenceKind.note => 86.0,
      GlimpseEvidenceKind.summary => 70.0,
    };
    result.add(
      Glimpse(
        key: 'idea:${u.id}',
        kind: GlimpseKind.idea,
        topicKey: subject?.key ?? 'save:${u.id}',
        topicLabel: subject?.label ?? '',
        sourceIds: [u.id],
        evidence: [itemEvidence],
        createdAt: u.savedAt,
        availableAt: u.savedAt.add(const Duration(days: 14)),
        expiresAt: u.savedAt.add(const Duration(days: 36500)),
        score: score,
      ),
    );
  }

  final pulses = const RediscoverTopicPulseService().detectRecent(
    library: active,
    now: now,
    triggerLimit: 12,
  );
  for (final pulse in pulses) {
    final trigger = byId[pulse.triggerSaveId];
    if (trigger == null) continue;
    final oldIds = pulse.archiveSaveIds
        .where((id) => evidence[id] != null)
        .take(2)
        .toList();
    if (oldIds.isEmpty || evidence[trigger.id] == null) continue;
    final readyAt = trigger.processingUpdatedAt ?? trigger.savedAt;
    result.add(
      Glimpse(
        key: pulse.id,
        kind: GlimpseKind.connection,
        topicKey: pulse.topicKey,
        topicLabel: pulse.topicLabel,
        sourceIds: [trigger.id, ...oldIds],
        // Lead with the older idea: the new save has already been acknowledged.
        evidence: [
          for (final id in oldIds) evidence[id]!,
          evidence[trigger.id]!,
        ],
        createdAt: trigger.savedAt,
        availableAt: readyAt.add(const Duration(hours: 1)),
        expiresAt: trigger.savedAt.add(const Duration(days: 7)),
        score: pulse.rankScore,
        strong: pulse.confidence == RediscoverTopicPulseConfidence.strong,
      ),
    );
  }

  final today = DateTime(now.year, now.month, now.day);
  final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
  final month = DateTime(now.year, now.month);
  for (final kind in [
    GlimpseKind.daily,
    GlimpseKind.weekly,
    GlimpseKind.monthly,
  ]) {
    final count = kind == GlimpseKind.daily
        ? 14
        : kind == GlimpseKind.weekly
        ? 8
        : 12;
    for (var offset = 0; offset < count; offset++) {
      final start = switch (kind) {
        GlimpseKind.daily => DateTime(
          today.year,
          today.month,
          today.day - offset,
        ),
        GlimpseKind.weekly => DateTime(
          monday.year,
          monday.month,
          monday.day - offset * 7,
        ),
        _ => DateTime(month.year, month.month - offset),
      };
      final end = switch (kind) {
        GlimpseKind.daily => DateTime(start.year, start.month, start.day + 1),
        GlimpseKind.weekly => DateTime(start.year, start.month, start.day + 7),
        _ => DateTime(start.year, start.month + 1),
      };
      final periodUrls =
          urls
              .where(
                (u) => !u.savedAt.isBefore(start) && u.savedAt.isBefore(end),
              )
              .toList()
            ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
      if (periodUrls.isEmpty && kind != GlimpseKind.monthly) continue;
      final maxIdeas = kind == GlimpseKind.daily ? 3 : 6;
      final selected = <GlimpseEvidence>[];
      final seenTexts = <String>{};
      final seenTopics = <String>{};
      for (final u in periodUrls) {
        final item = evidence[u.id];
        final topic = subjects.resolve(u)?.key ?? 'save:${u.id}';
        if (item == null ||
            seenTopics.contains(topic) ||
            !seenTexts.add(item.text.toLowerCase())) {
          continue;
        }
        seenTopics.add(topic);
        selected.add(item);
        if (selected.length >= maxIdeas) break;
      }
      // Keep breadth, then include distinct ideas within recurring subjects.
      // A week focused on one subject should still support a useful synthesis.
      for (final u in periodUrls) {
        if (selected.length >= maxIdeas) break;
        final item = evidence[u.id];
        if (item != null && seenTexts.add(item.text.toLowerCase())) {
          selected.add(item);
        }
      }
      final ids = periodUrls.map((u) => u.id).toSet();
      final periodEvents = request.events.where(
        (e) => !e.at.isBefore(start) && e.at.isBefore(end),
      );
      Set<int> observed(Set<EngagementEventType> types) => periodEvents
          .where(
            (e) =>
                types.contains(e.type) &&
                e.urlId != null &&
                liveById.containsKey(e.urlId),
          )
          .map((e) => e.urlId!)
          .toSet();
      final returned = observed({
        EngagementEventType.cardOpened,
        EngagementEventType.open,
      });
      // Count only observed returns to items saved before the period.
      returned.removeWhere(
        (id) => !(liveById[id]?.savedAt.isBefore(start) ?? false),
      );
      final noted = observed({EngagementEventType.noteAdded});
      final completed = observed({EngagementEventType.rediscoverCompleted});
      if (kind == GlimpseKind.monthly) {
        ids.addAll({...returned, ...noted, ...completed});
      }
      if (ids.isEmpty) continue;
      final available = kind == GlimpseKind.weekly
          ? DateTime(start.year, start.month, start.day + 6, 19)
          : end;
      result.add(
        Glimpse(
          key: '${kind.name}:${glimpseDateKey(start)}',
          kind: kind,
          topicKey: 'recap:${kind.name}',
          topicLabel: '',
          sourceIds: ids.toList(),
          evidence: selected,
          createdAt: start,
          availableAt: available,
          expiresAt: end,
          periodStart: start,
          periodEnd: end,
          score: 100,
          returnedCount: returned.length,
          notedCount: noted.length,
          completedCount: completed.length,
        ),
      );
    }
  }
  return result;
}

GlimpseEvidence? evidenceForSave(SavedUrl url) {
  final highlights = SavedHighlightsCodec.decode(url.highlightsJson);
  for (final highlight in highlights.reversed) {
    if (highlight.quote.trim().length >= 40) {
      return GlimpseEvidence(
        sourceId: url.id,
        text: highlight.quote.trim(),
        kind: GlimpseEvidenceKind.highlight,
        sectionKey: highlight.sectionKey,
      );
    }
  }
  final note = url.userNotes?.trim() ?? '';
  if (note.length >= 40) {
    return GlimpseEvidence(
      sourceId: url.id,
      text: note,
      kind: GlimpseEvidenceKind.note,
    );
  }
  final summary = SummaryRewriter.clean(url.summary);
  if (summary.length < 40) return null;
  return GlimpseEvidence(
    sourceId: url.id,
    text: summary,
    kind: GlimpseEvidenceKind.summary,
  );
}
