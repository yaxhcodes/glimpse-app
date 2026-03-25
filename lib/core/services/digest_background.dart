import 'package:shared_preferences/shared_preferences.dart';

import '../database/isar_service.dart';
import 'bundled_keys.dart';
import 'digest_notifications.dart';
import 'digest_prefs.dart';
import 'gemini_service.dart';

class DigestBackgroundTask {
  static Future<void> run() async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getBool(DigestPrefs.digestEnabledKey) ?? true) == false) {
      return;
    }
    if (!BundledKeys.hasGemini) return;

    final isar = IsarService();
    await isar.ensureInitialized();

    final links = await isar.getUnreadLinks(
      savedBefore: DateTime.now().subtract(const Duration(days: 3)),
      limit: 3,
    );
    if (links.isEmpty) return;

    final gemini = GeminiService(BundledKeys.geminiKey);
    var summaries = await gemini.summarizeLinksForDigest(links);
    while (summaries.length < links.length) {
      summaries.add('Worth revisiting from your saves.');
    }
    summaries = summaries.take(links.length).toList();

    final ids = links.map((l) => l.id).toList();
    await DigestPrefs.saveLastDigest(ids: ids, summaries: summaries);

    await DigestNotifications.showDigest(
      summaries: summaries,
      linkCount: links.length,
    );
  }
}
