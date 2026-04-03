import 'package:shared_preferences/shared_preferences.dart';

import '../database/isar_service.dart';
import '../models/saved_url.dart';
import 'bundled_keys.dart';
import 'digest_notifications.dart';
import 'digest_prefs.dart';
import 'gemini_service.dart';

class DigestBackgroundTask {
  static Future<void> run() async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getBool(DigestPrefs.digestEnabledKey) ?? true) == false) {
      await DigestPrefs.saveLastRunStatus('skipped: digest disabled');
      return;
    }

    final isar = IsarService();
    await isar.ensureInitialized();

    // Prefer older unread links, but fall back to any unread links so the
    // digest still fires for users who save infrequently.
    var links = await isar.getUnreadLinks(
      savedBefore: DateTime.now().subtract(const Duration(days: 3)),
      limit: 3,
    );
    if (links.isEmpty) {
      links = await isar.getUnreadLinks(limit: 3);
    }
    if (links.isEmpty) {
      await DigestPrefs.saveLastRunStatus('skipped: no unread links');
      return;
    }

    final summaries = await _buildSummaries(links);
    final topic = _deriveTopic(links);
    final ids = links.map((l) => l.id).toList();

    await DigestPrefs.saveLastDigest(ids: ids, summaries: summaries);
    await DigestPrefs.addDigestToHistory(
      ids: ids,
      summaries: summaries,
      topic: topic,
    );

    await DigestNotifications.initForBackground();
    await DigestNotifications.showDigest(
      title: topic,
      summaries: summaries,
      linkCount: links.length,
    );
    await DigestPrefs.saveLastRunStatus(
      'ok: notified ${links.length} link(s)',
    );
  }

  /// Try Gemini for punchy one-liners; fall back to local title/description
  /// when the key isn't bundled or the API call fails.
  static Future<List<String>> _buildSummaries(List<SavedUrl> links) async {
    if (BundledKeys.hasGemini) {
      try {
        final gemini = GeminiService(BundledKeys.geminiKey);
        var ai = await gemini.summarizeLinksForDigest(links);
        while (ai.length < links.length) {
          ai.add(_localSummary(links[ai.length]));
        }
        return ai.take(links.length).toList();
      } catch (_) {
        // Gemini failed — fall through to local summaries.
      }
    }
    return links.map(_localSummary).toList();
  }

  static String _localSummary(SavedUrl link) {
    if (link.title.isNotEmpty) return link.title;
    if (link.description.isNotEmpty) return link.description;
    return link.domain;
  }

  /// Derives a short topic label from the primary categories of the links.
  static String _deriveTopic(List<SavedUrl> links) {
    final cats = <String>{};
    for (final l in links) {
      final primary = l.effectiveCategories.firstOrNull;
      if (primary != null && primary != 'Other') cats.add(primary);
    }
    if (cats.isEmpty) return 'Your weekly digest';
    if (cats.length == 1) return cats.first;
    return cats.take(2).join(' & ');
  }
}
