import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../database/isar_service.dart';
import '../models/saved_url.dart';
import '../models/url_processing_status.dart';
import '../../l10n/l10n.dart';
import '../../l10n/generated/app_localizations_en.dart';

/// Seeds — and later clears — the single bundled travel example that the
/// onboarding flow reveals, so a brand-new library is never empty on first open.
///
/// The seed is a normal [SavedUrl] inserted straight into Isar with enrichment
/// already attached (status READY). It therefore never touches the AI proxy,
/// never counts against the free-tier save quota (which is metered on the save
/// path, not by row count), and renders exactly like a real enriched save. Its
/// id is tracked in SharedPreferences so it can be recognised and auto-removed
/// once the user makes their first real save.
class DemoSeedService {
  DemoSeedService(this._isar);

  final IsarService _isar;

  static const String _demoIdKey = 'onboarding_demo_url_id';

  static const sourceUrl = 'https://www.instagram.com/reel/Db_Y5A2KZcY/';
  static const sourceCreator = '@monsieur.jim';

  /// The fragment separates the bundled example from a user's own source save.
  static const String demoRawUrl = '$sourceUrl#glimpse-demo-authentic-france';

  static const legacyDemoRawUrl =
      'https://kyoto.travel/en#glimpse-demo-three-quiet-days';

  static bool isDemoUrl(String? url) =>
      url == demoRawUrl || url == legacyDemoRawUrl;

  /// Legacy artwork marker retained for older sample-library entries.
  static const String demoThumbnailAsset =
      'asset://assets/onboarding_kyoto.webp';

  /// Id of the seeded demo entry, or null when none is present.
  static Future<int?> demoId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_demoIdKey);
  }

  /// Inserts the demo entry unless one already exists. Returns its id.
  Future<int> seed() async {
    final urls = await _isar.getAllUrls();
    if (urls.any((url) => !isDemoUrl(url.rawUrl))) return 0;
    final existing = await demoId();
    if (existing != null) {
      final savedDemo = await _isar.getAnyUrlById(existing);
      if (isDemoUrl(savedDemo?.rawUrl)) return existing;
    }

    final strings = await loadBackgroundLocalizations();
    final id = await _isar.saveUrl(buildPreview(strings: strings));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_demoIdKey, id);
    if ((await _isar.getAllUrls()).any((url) => !isDemoUrl(url.rawUrl))) {
      await clear();
    }
    return id;
  }

  /// Removes the demo entry (if any) and forgets its id.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_demoIdKey);
    if (id == null) return;
    if (isDemoUrl((await _isar.getAnyUrlById(id))?.rawUrl)) {
      await _isar.deleteUrlPermanently(id);
    }
    await prefs.remove(_demoIdKey);
  }

  /// Builds the same enriched memory used by onboarding and the seeded Home.
  /// Keeping this composition in one place prevents the product demonstration
  /// from drifting away from the first card a new user actually receives.
  static SavedUrl buildPreview({DateTime? savedAt, AppLocalizations? strings}) {
    final l = strings ?? AppLocalizationsEn();
    final summary = l.obSummary;

    final enrichment = <String, dynamic>{
      'meaningful_title': l.obSaveTitle,
      'summary': summary,
      'creator': sourceCreator,
      'category': 'Travel',
      'tags': ['france', 'destinations', 'backcountry'],
      'content_type': 'travel_guide',
      'primary_intent': 'visit',
      'life_area': 'travel',
      'why_saved_hypothesis': l.obExample,
      'key_points': [l.obPoint, l.obTakeaway2, l.obTakeaway3],
      'mentions': [
        {
          'title': 'Gorges du Tarn',
          'type': 'place',
          'why_mentioned': l.obPlaceNote,
        },
        {
          'title': 'Cascade de l’Éventail',
          'type': 'place',
          'why_mentioned': l.obPlaceNote,
        },
        {
          'title': 'Abbaye de Moissac',
          'type': 'place',
          'why_mentioned': l.obPlaceNote,
        },
      ],
    };

    return SavedUrl()
      ..rawUrl = demoRawUrl
      ..domain = 'instagram.com'
      ..title = l.obSaveTitle
      ..description = l.obExample
      ..thumbnailUrl = null
      ..category = 'Travel'
      ..categoryEmoji = '✈️'
      ..categories = ['Travel']
      ..tags = ['france', 'destinations', 'backcountry']
      ..summary = summary
      ..enrichmentJson = jsonEncode(enrichment)
      ..processingStatus = UrlProcessingStatus.ready
      ..savedAt = savedAt ?? DateTime.now();
  }
}
