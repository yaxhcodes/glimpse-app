import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../notifications/gemini_copywriter.dart';
import '../../features/mindmap/interest_cluster_service.dart';
import '../../features/rediscover/rediscover_journey_provider.dart';
import '../../features/rediscover/rediscover_memory.dart';
import '../../features/rediscover/rediscover_notification_candidate.dart';
import '../../features/rediscover/rediscover_provider.dart';

import '../database/isar_service.dart';
import '../models/engagement_event.dart';
import '../models/saved_url.dart';
import 'affinity_profile.dart';
import 'digest_notifications.dart';
import 'digest_prefs.dart';
import 'notif_bandit.dart';
import 'notification_templates.dart';
import 'rediscovery_service.dart';
import 'revisit_scorer.dart';
import 'summary_trimmer.dart';
import 'tag_analyzer.dart';
import 'title_resolver.dart';
import 'user_fingerprint.dart';

/// Orchestrates all notification types with priority ordering, timing
/// constraints, and per-type conditions. Runs inside WorkManager.
class NotificationScheduler {
  NotificationScheduler._();

  // Ordered most-personal first: G (you asked to revisit), E (a specific
  // forgotten save), A (one place's saves), then the broader pattern nudges.
  // D (saving-streak, the guilt-y "you don't read" one) comes last.
  static const _typeOrder = ['G', 'E', 'A', 'B', 'C', 'D', 'F'];

  /// Minimum days between two notifications of the same type, on top of the
  /// per-topic signature cooldown. This is what gives the week texture: a
  /// Rediscover memory one day, a specific old save another, a place nudge
  /// later — never the same voice on repeat. G is exempt (explicit intent:
  /// due is due), D is rarest (it's the guilt-adjacent one).
  static const _minTypeGap = <String, Duration>{
    'G': Duration.zero,
    'R': Duration(days: 3),
    'E': Duration(days: 2),
    'A': Duration(days: 5),
    'B': Duration(days: 3),
    'C': Duration(days: 4),
    'D': Duration(days: 7),
    'F': Duration(days: 6),
  };

  /// Labels for settings / diagnostics (user-facing).
  static const _typeLabels = {
    'R': 'Rediscover Memory',
    'A': 'Travel & Places',
    'B': 'New Discovery',
    'C': 'Reading Reminder',
    'D': 'Activity',
    'E': 'Worth Revisiting',
    'F': 'Weekly Digest',
    'G': 'Revisit Reminder',
  };

  static String labelFor(String type) => _typeLabels[type] ?? type;

  static Future<String> runScheduled(IsarService isar) async {
    final hour = DateTime.now().hour;
    if (hour >= 23 || hour < 8) {
      return 'skipped: quiet hours ($hour:00)';
    }

    if (!await DigestPrefs.canFireToday()) {
      return 'skipped: already fired today';
    }

    if (!await DigestPrefs.hasMinGap()) {
      return 'skipped: <20h since last notification';
    }

    final fp = await UserFingerprint.compute(isar);

    // Anti-repetition: don't re-send the same topic (e.g. the same place, the
    // same link) within this window, so notifications stop feeling like reruns.
    final recentSigs = await DigestPrefs.recentSignatures(
      within: const Duration(days: 3),
    );

    // The Rediscover memory is ONE candidate among the notification types —
    // quality-gated by its own score threshold, but it competes in the bandit
    // ranking like everything else instead of preempting the whole system.
    final memoryCandidate = await _bestRediscoverMemoryCandidate(
      isar,
      fp,
      recentSigs: recentSigs,
    );

    // Eligible, non-cooldown candidates for today.
    final candidates = <String>[];
    for (final type in ['R', ..._typeOrder]) {
      if (type == 'F' && DateTime.now().weekday != DateTime.sunday) continue;
      final gap = _minTypeGap[type] ?? Duration.zero;
      if (!await DigestPrefs.canFireType(type, minInterval: gap)) continue;
      if (type == 'R') {
        if (memoryCandidate == null || !memoryCandidate.shouldNotify) continue;
        if (recentSigs.contains(_memorySignature(memoryCandidate.memory))) {
          continue;
        }
        candidates.add(type);
        continue;
      }
      if (!NotificationTemplates.isEligible(type, fp)) continue;
      final sig = _signature(type, fp);
      if (sig != null && recentSigs.contains(sig)) continue; // fired recently
      candidates.add(type);
    }

    final ordered = await _rankCandidates(candidates);

    for (final type in ordered) {
      final result = type == 'R'
          ? await _fireMemory(memoryCandidate!)
          : await _tryType(isar, type, fp, sig: _signature(type, fp));
      if (result != null) {
        await _recordFire(isar, type);
        return result;
      }
    }

    // Everything eligible was on cooldown (or nothing eligible) — stay silent
    // today rather than repeat. Better a quiet day than the same nudge again.
    return 'skipped: no fresh topic';
  }

  /// Order today's candidates. The revisit-due type (G) always leads — the user
  /// explicitly asked to come back to those saves, so it isn't a guess to learn
  /// about. The rest — the Rediscover memory (R) included — are ranked by the
  /// on-device [NotifBandit], which adapts to which types this user actually
  /// opens.
  static Future<List<String>> _rankCandidates(List<String> candidates) async {
    if (candidates.length <= 1) return candidates;
    final rest = candidates.where((t) => t != 'G').toList();
    final ranked = await NotifBandit.rank(rest);
    return [
      if (candidates.contains('G')) 'G',
      ...ranked,
    ];
  }

  /// Stable per-topic key used to suppress repeats. Two notifications with the
  /// same signature are "the same notification" for cooldown purposes.
  static String? _signature(String type, UserFingerprint fp) {
    switch (type) {
      case 'A':
        return fp.featuredGeo == null ? null : 'A:${fp.featuredGeo}';
      case 'B':
        final tag = _bestNewInterestTag(fp);
        return tag == null ? null : 'B:$tag';
      case 'C':
        return fp.deepDiveName == null ? null : 'C:${fp.deepDiveName}';
      case 'D':
        return 'D:streak';
      case 'E':
        return fp.topUnreadLink == null ? null : 'E:${fp.topUnreadLink!.id}';
      case 'F':
        return 'F:weekly';
      case 'G':
        return fp.queuedDueLinks.isEmpty
            ? null
            : 'G:${fp.queuedDueLinks.first.id}';
      default:
        return null;
    }
  }

  /// Per-type readiness snapshot for the diagnostics panel: is each type
  /// eligible right now, is it on topic-cooldown, and a one-line reason. Makes
  /// it obvious why only some of the 7 types ever fire.
  static Future<List<NotifDiag>> diagnostics(IsarService isar) async {
    final fp = await UserFingerprint.compute(isar);
    final recent = await DigestPrefs.recentSignatures();
    final memoryCandidate = await _bestRediscoverMemoryCandidate(
      isar,
      fp,
      recentSigs: recent,
    );

    Future<bool> gapActive(String type) async {
      final gap = _minTypeGap[type] ?? Duration.zero;
      return !await DigestPrefs.canFireType(type, minInterval: gap);
    }

    final memorySigCooldown = memoryCandidate != null &&
        recent.contains(_memorySignature(memoryCandidate.memory));
    final out = <NotifDiag>[
      NotifDiag(
        type: 'R',
        label: labelFor('R'),
        eligible: memoryCandidate?.shouldNotify ?? false,
        onCooldown: memorySigCooldown || await gapActive('R'),
        detail: memoryCandidate == null
            ? 'no Rediscover memory candidate'
            : _memoryDiagDetail(memoryCandidate),
      ),
    ];
    for (final t in _typeOrder) {
      final sig = _signature(t, fp);
      final sigCooldown = sig != null && recent.contains(sig);
      out.add(NotifDiag(
        type: t,
        label: labelFor(t),
        eligible: NotificationTemplates.isEligible(t, fp),
        onCooldown: sigCooldown || await gapActive(t),
        detail: _eligibilityDetail(t, fp),
      ));
    }
    return out;
  }

  /// Short human reason describing the gating metric for [type].
  static String _eligibilityDetail(String type, UserFingerprint fp) {
    switch (type) {
      case 'A':
        final geo = fp.featuredGeo;
        return geo == null
            ? 'no place tags yet'
            : '$geo · ${fp.featuredGeoUnreadCount} unread (need 3)';
      case 'B':
        return 'new tags this week: ${fp.newTagsThisWeek.length} (need 1 with 2+ saves)';
      case 'C':
        return fp.deepDiveName == null
            ? 'no deep pile yet'
            : '${fp.deepDiveName} · ${fp.deepDiveUnread} unread (need 6)';
      case 'D':
        return 'saving streak ${fp.savingStreakDays}d, unread streak ${fp.unreadStreak}d (need 3+3)';
      case 'E':
        return 'oldest unread ${fp.oldestUnreadDays}d (need 10)';
      case 'F':
        return '${fp.totalSavedThisWeek} saves this week (need 5, Sundays)';
      case 'G':
        return 'queued & due: ${fp.queuedDueLinks.length}';
      default:
        return '';
    }
  }

  static Future<String> runSingle(IsarService isar, String type) async {
    final fp = await UserFingerprint.compute(isar);
    if (type == 'R') {
      final candidate = await _bestRediscoverMemoryCandidate(
        isar,
        fp,
        recentSigs: await DigestPrefs.recentSignatures(),
      );
      if (candidate != null && candidate.shouldNotify) {
        final result = await _fireMemory(candidate);
        if (result != null) return result;
      }
      return 'skipped: conditions not met for ${labelFor(type)}';
    }
    final result = await _tryType(isar, type, fp);
    if (result != null) return result;
    return 'skipped: conditions not met for ${labelFor(type)}';
  }

  static Future<NotifCopy?> preview(IsarService isar, String type) async {
    final fp = await UserFingerprint.compute(isar);
    if (type == 'R') {
      final candidate = await _bestRediscoverMemoryCandidate(
        isar,
        fp,
        recentSigs: await DigestPrefs.recentSignatures(),
      );
      if (candidate == null || !candidate.shouldNotify) return null;
      return NotifCopy(
        title: candidate.memory.notificationCopy.title,
        body: candidate.memory.notificationCopy.body,
      );
    }
    if (!NotificationTemplates.isEligible(type, fp)) return null;
    final links = _relevantSavedUrls(type, fp);
    return GeminiCopywriter.generate(
      type: _notifTypeFor(type),
      fingerprint: fp,
      relevantLinks: links,
    );
  }

  /// Send bookkeeping shared by every fired type: bandit arm, unified event
  /// log (so the affinity model sees notification engagement at the topic
  /// level), daily cap, and per-type gap timestamps.
  static Future<void> _recordFire(IsarService isar, String type) async {
    await NotifBandit.recordSend(type);
    unawaited(
      isar.logEvent(
        type: EngagementEventType.notifShown,
        triggerType: type,
      ),
    );
    await DigestPrefs.recordFired();
    await DigestPrefs.setLastFiredType(type);
    await DigestPrefs.setLastFired(type);
  }

  /// Show the Rediscover-memory notification for an already-selected
  /// [candidate]. Selection and send bookkeeping live with the caller.
  static Future<String?> _fireMemory(
    RediscoverNotificationCandidate candidate,
  ) async {
    final memory = candidate.memory;
    final linkIds = [
      ...memory.metadata.primaryUrlIds,
      ...memory.metadata.supportingUrlIds,
    ];
    if (linkIds.isEmpty) return null;

    final copy = memory.notificationCopy;
    final notifId = 'notif_${DateTime.now().millisecondsSinceEpoch}';
    final firedAt = DateTime.now().toIso8601String();
    final sig = _memorySignature(memory);
    final payload = <String, dynamic>{
      'type': 'R',
      'linkIds': linkIds,
      'title': copy.title,
      'body': copy.body,
      'notifId': notifId,
      'firedAt': firedAt,
      'memoryId': memory.id,
      'notificationScore': candidate.score,
      'explanation': candidate.explanation,
    };

    await DigestNotifications.show(
      type: NotifType.resurface,
      title: copy.title,
      body: copy.body,
      payloadJson: jsonEncode(payload),
      withActions: linkIds.length == 1,
      persistInHistory: true,
      historyType: 'rediscover',
      historySignature: sig,
    );

    return 'rediscover: ${copy.title}';
  }

  static Future<RediscoverNotificationCandidate?> _bestRediscoverMemoryCandidate(
    IsarService isar,
    UserFingerprint fp, {
    required Set<String> recentSigs,
  }) async {
    final memories = await _loadRediscoverMemories(isar, fp);
    if (memories.isEmpty) return null;

    final lastNotificationAt = await DigestPrefs.lastFiredTimestamp();
    final now = DateTime.now();
    final candidates = [
      for (final memory in memories)
        RediscoverNotificationCandidate.scoreMemory(
          memory,
          now: now,
          recentlyNotified: recentSigs.contains(_memorySignature(memory)),
          lastNotificationAt: lastNotificationAt,
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return candidates.first;
  }

  static Future<List<RediscoverMemory>> _loadRediscoverMemories(
    IsarService isar,
    UserFingerprint fp,
  ) async {
    final liveUrls = fp.allUrls
        .where((url) => !url.isDone && url.rediscoverDismissedAt == null)
        .toList();
    if (liveUrls.length < 3) return const [];

    final prefs = await SharedPreferences.getInstance();
    final embeddedUrls = await isar.getUrlsWithEmbeddings();
    final clusters = await tryHydrateClustersFromPrefs(
          prefs: prefs,
          embeddedUrls: embeddedUrls,
          currentEmbeddedCount: embeddedUrls.length,
        ) ??
        const [];
    final profile = AffinityProfile.fromEvents(await isar.recentEvents());
    final interest = await RediscoveryService(isar).getRediscoveryLinks(
      limit: 8,
    );
    final journeys = buildRediscoverJourneys(
      liveUrls: liveUrls,
      clusters: clusters,
      profile: profile,
      interestFallbackItems: interest.map(_rediscoveryItemFor).toList(),
      anniversaryItems: _anniversaryItems(liveUrls),
    );
    return journeys.map(RediscoverMemory.fromJourney).toList();
  }

  static RediscoveryItem _rediscoveryItemFor(SavedUrl url) {
    return RediscoveryItem(
      url: url,
      reason: RevisitScorer.onThisDayLabel(url) ??
          (url.openedAt == null ? 'Unopened' : 'Worth revisiting'),
      timeAgo: _formatTimeAgo(url.savedAt),
    );
  }

  static List<RediscoveryItem> _anniversaryItems(List<SavedUrl> urls) {
    return urls
        .where((url) => RevisitScorer.onThisDayLabel(url) != null)
        .map(_rediscoveryItemFor)
        .take(8)
        .toList();
  }

  static String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  static String _memorySignature(RediscoverMemory memory) => 'R:${memory.id}';

  static String _memoryDiagDetail(RediscoverNotificationCandidate candidate) {
    final reasons = candidate.reasons
        .where((reason) => reason.points > 0)
        .map((reason) => reason.label)
        .take(3)
        .join(', ');
    return '${candidate.score.toStringAsFixed(1)} pts'
        '${reasons.isEmpty ? '' : ' · $reasons'}';
  }

  static Future<String?> _tryType(
    IsarService isar,
    String type,
    UserFingerprint fp, {
    String? sig,
  }) async {
    final copy = await _generateCopy(type, fp);
    if (copy == null) return null;

    final linkIds = collectLinkIds(type, fp);
    if (linkIds.isEmpty) return null;

    final notifType = _notifTypeFor(type);
    final historyType = _historyTypeFor(type);
    final notifId = 'notif_${DateTime.now().millisecondsSinceEpoch}';
    final firedAt = DateTime.now().toIso8601String();

    final payload = <String, dynamic>{
      'type': type,
      'linkIds': linkIds,
      'title': copy.title,
      'body': copy.body,
      'notifId': notifId,
      'firedAt': firedAt,
    };

    assert(
      linkIds.isNotEmpty,
      'Scheduled notifications must include linkIds for tap routing.',
    );
    assert(notifId.isNotEmpty);

    final payloadJson = jsonEncode(payload);

    await DigestNotifications.show(
      type: notifType,
      title: copy.title,
      body: copy.body,
      payloadJson: payloadJson,
      // Single-link notifications (revisit-due, resurface) get quick Done/Later
      // action buttons; multi-link ones have no single target to act on.
      withActions: linkIds.length == 1,
      persistInHistory: true,
      historyType: historyType,
      historySignature: sig,
    );

    if (type == 'F') {
      final digestLinks = <SavedUrl>[];
      for (final id in linkIds.take(5)) {
        final u = await isar.getUrlById(id);
        if (u != null) digestLinks.add(u);
      }
      if (digestLinks.isNotEmpty) {
        await DigestPrefs.saveLastDigest(
          ids: digestLinks.map((l) => l.id).toList(),
          summaries: digestLinks.map((l) => _localSummary(l, fp)).toList(),
        );
      }
    }

    return '$historyType: ${copy.title}';
  }

  /// All link IDs that the notification content is based on (fetch by ID only in UI).
  static List<int> collectLinkIds(String type, UserFingerprint fp) {
    switch (type) {
      case 'G':
        return fp.queuedDueLinks.map((u) => u.id).take(20).toList();
      case 'A':
        // Only the featured place's saves — never a mixed bag of countries.
        final geo = fp.featuredGeo;
        if (geo == null) return [];
        return TagAnalyzer.unreadLinksForGeo(fp.allUrls, geo)
            .map((u) => u.id)
            .take(80)
            .toList();
      case 'B':
        final tag = _bestNewInterestTag(fp);
        if (tag == null) return [];
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        return fp.allUrls
            .where((u) =>
                !u.isDone &&
                u.savedAt.isAfter(weekAgo) &&
                u.tags.any((t) => t.toLowerCase().trim() == tag))
            .map((u) => u.id)
            .toList();
      case 'C':
        // The deep-dive pile: category-based or tag-cluster-based.
        if (fp.deepDiveName == null) return [];
        return fp.allUrls
            .where((u) {
              if (u.openedAt != null || u.isDone) return false;
              if (fp.deepDiveCategory != null) {
                return u.effectiveCategories.first == fp.deepDiveCategory;
              }
              return u.tags
                  .any((t) => fp.deepDiveTags.contains(t.toLowerCase().trim()));
            })
            .map((u) => u.id)
            .take(40)
            .toList();
      case 'D':
        final streakDays = fp.savingStreakDays.clamp(3, 14);
        final start = DateTime.now().subtract(Duration(days: streakDays));
        return fp.allUrls
            .where((u) => u.openedAt == null && u.savedAt.isAfter(start))
            .map((u) => u.id)
            .take(50)
            .toList();
      case 'E':
        final link = fp.topUnreadLink;
        if (link == null) return [];
        return [link.id];
      case 'F':
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        final weekSaves = fp.allUrls
            .where((u) => u.savedAt.isAfter(weekAgo) && !u.isDone)
            .toList()
          ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
        return weekSaves.take(15).map((u) => u.id).toList();
      default:
        return [];
    }
  }

  static String? _bestNewInterestTag(UserFingerprint fp) {
    if (fp.newTagsThisWeek.isEmpty) return null;
    String? bestTag;
    int bestCount = 0;
    for (final tag in fp.newTagsThisWeek) {
      final c = fp.savesWithNewTag(tag);
      if (c >= 2 && c > bestCount) {
        bestCount = c;
        bestTag = tag;
      }
    }
    return bestTag?.toLowerCase().trim();
  }

  static Future<NotifCopy?> _generateCopy(String type, UserFingerprint fp) async {
    if (!NotificationTemplates.isEligible(type, fp)) return null;
    final links = _relevantSavedUrls(type, fp);
    return GeminiCopywriter.generate(
      type: _notifTypeFor(type),
      fingerprint: fp,
      relevantLinks: links,
    );
  }

  static List<SavedUrl> _relevantSavedUrls(String type, UserFingerprint fp) {
    final ids = collectLinkIds(type, fp);
    final byId = {for (final u in fp.allUrls) u.id: u};
    return ids.map((id) => byId[id]).whereType<SavedUrl>().toList();
  }

  static NotifType _notifTypeFor(String type) {
    switch (type) {
      case 'A':
        return NotifType.geography;
      case 'B':
        return NotifType.newInterest;
      case 'C':
        return NotifType.collector;
      case 'D':
        return NotifType.streak;
      case 'E':
        return NotifType.resurface;
      case 'F':
        return NotifType.digest;
      case 'G':
        return NotifType.revisitDue;
      default:
        return NotifType.digest;
    }
  }

  static String _historyTypeFor(String type) {
    switch (type) {
      case 'A':
        return 'geo';
      case 'B':
        return 'new_interest';
      case 'C':
        return 'collector';
      case 'D':
        return 'streak';
      case 'E':
        return 'resurface';
      case 'F':
        return 'digest';
      case 'G':
        return 'revisit';
      default:
        return 'digest';
    }
  }

  static String _localSummary(SavedUrl link, UserFingerprint fp) {
    final counts = <String, int>{};
    for (final u in fp.allUrls) {
      for (final t in u.tags) {
        final k = t.toLowerCase().trim();
        if (k.isEmpty) continue;
        counts[k] = (counts[k] ?? 0) + 1;
      }
    }
    final summ = link.summary?.trim() ?? '';
    if (summ.isNotEmpty) {
      return SummaryTrimmer.trim(summ, maxLength: 120);
    }
    final desc = link.description.trim();
    if (desc.isNotEmpty) {
      return SummaryTrimmer.trim(desc, maxLength: 120);
    }
    return TitleResolver.resolveDetailTitle(link, tagFrequency: counts);
  }
}

/// Per-type readiness for the notification diagnostics panel.
class NotifDiag {
  const NotifDiag({
    required this.type,
    required this.label,
    required this.eligible,
    required this.onCooldown,
    required this.detail,
  });

  final String type;
  final String label;
  final bool eligible;
  final bool onCooldown;
  final String detail;
}
