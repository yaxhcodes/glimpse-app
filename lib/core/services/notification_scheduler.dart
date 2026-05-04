import 'dart:convert';

import '../../notifications/gemini_copywriter.dart';

import '../database/isar_service.dart';
import '../models/saved_url.dart';
import 'digest_notifications.dart';
import 'digest_prefs.dart';
import 'notification_templates.dart';
import 'summary_trimmer.dart';
import 'tag_analyzer.dart';
import 'title_resolver.dart';
import 'user_fingerprint.dart';

/// Orchestrates all notification types with priority ordering, timing
/// constraints, and per-type conditions. Runs inside WorkManager.
class NotificationScheduler {
  NotificationScheduler._();

  static const _typeOrder = ['B', 'A', 'C', 'E', 'D', 'F'];

  /// Labels for settings / diagnostics (user-facing).
  static const _typeLabels = {
    'A': 'Travel & Places',
    'B': 'New Discovery',
    'C': 'Reading Reminder',
    'D': 'Activity',
    'E': 'Worth Revisiting',
    'F': 'Weekly Digest',
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

    for (final type in _typeOrder) {
      if (type == 'F' && DateTime.now().weekday != DateTime.sunday) continue;

      final result = await _tryType(isar, type, fp);
      if (result != null) {
        await DigestPrefs.recordFired();
        await DigestPrefs.setLastFiredType(type);
        await DigestPrefs.setLastFired(type);
        return result;
      }
    }

    return 'skipped: no conditions met';
  }

  static Future<String> runSingle(IsarService isar, String type) async {
    final fp = await UserFingerprint.compute(isar);
      final result = await _tryType(isar, type, fp);
    if (result != null) return result;
    return 'skipped: conditions not met for ${labelFor(type)}';
  }

  static Future<NotifCopy?> preview(IsarService isar, String type) async {
    final fp = await UserFingerprint.compute(isar);
    if (!NotificationTemplates.isEligible(type, fp)) return null;
    final links = _relevantSavedUrls(type, fp);
    return GeminiCopywriter.generate(
      type: _notifTypeFor(type),
      fingerprint: fp,
      relevantLinks: links,
    );
  }

  static Future<String?> _tryType(
    IsarService isar,
    String type,
    UserFingerprint fp,
  ) async {
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

    await DigestPrefs.saveNotifPayload(notifId, payload);

    final payloadJson = jsonEncode(payload);

    await DigestNotifications.show(
      type: notifType,
      title: copy.title,
      body: copy.body,
      payloadJson: payloadJson,
    );

    final summaries = [copy.body];
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

    await DigestPrefs.addDigestToHistory(
      ids: linkIds,
      summaries: summaries,
      topic: copy.title,
      type: historyType,
      notifId: notifId,
      body: copy.body,
    );

    return '$historyType: ${copy.title}';
  }

  /// All link IDs that the notification content is based on (fetch by ID only in UI).
  static List<int> collectLinkIds(String type, UserFingerprint fp) {
    switch (type) {
      case 'A':
        return TagAnalyzer.unreadGeoLinks(fp.allUrls)
            .map((u) => u.id)
            .take(80)
            .toList();
      case 'B':
        final tag = _bestNewInterestTag(fp);
        if (tag == null) return [];
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        return fp.allUrls
            .where((u) =>
                u.savedAt.isAfter(weekAgo) &&
                u.tags.any((t) => t.toLowerCase().trim() == tag))
            .map((u) => u.id)
            .toList();
      case 'C':
        final cluster = fp.topClusters.isNotEmpty ? fp.topClusters.first : null;
        if (cluster == null) return [];
        return fp.allUrls
            .where((u) =>
                u.openedAt == null &&
                u.tags.any((t) => cluster.tags.contains(t.toLowerCase().trim())))
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
            .where((u) => u.savedAt.isAfter(weekAgo))
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
    return TitleResolver.resolve(link, tagFrequency: counts);
  }
}
