import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../database/isar_service.dart';
import '../models/saved_url.dart';
import '../models/url_processing_status.dart';

/// Seeds — and later clears — the single pre-baked Kyoto entry that the
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

  /// Sentinel URL for the seeded reel. Recognisable so it can never be confused
  /// with a genuine user save. The fragment keeps the illustrative entry local
  /// while leaving the card with a truthful, recognisable source.
  static const String demoRawUrl =
      'https://kyoto.travel/en#glimpse-demo-three-quiet-days';

  /// Asset URI understood by the compact Home thumbnail renderer.
  static const String demoThumbnailAsset =
      'asset://assets/onboarding_kyoto.webp';

  /// Id of the seeded demo entry, or null when none is present.
  static Future<int?> demoId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_demoIdKey);
  }

  /// Inserts the demo entry unless one already exists. Returns its id.
  Future<int> seed() async {
    final existing = await demoId();
    if (existing != null) {
      final savedDemo = await _isar.getUrlById(existing);
      if (savedDemo?.rawUrl == demoRawUrl) return existing;
      if (savedDemo != null) await _isar.deleteUrl(existing);
    }

    final id = await _isar.saveUrl(buildPreview());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_demoIdKey, id);
    return id;
  }

  /// Removes the demo entry (if any) and forgets its id.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_demoIdKey);
    if (id == null) return;
    await _isar.deleteUrl(id);
    await prefs.remove(_demoIdKey);
  }

  /// Builds the same enriched memory used by onboarding and the seeded Home.
  /// Keeping this composition in one place prevents the product demonstration
  /// from drifting away from the first card a new user actually receives.
  static SavedUrl buildPreview({DateTime? savedAt}) {
    const summary =
        'A calm three-day Kyoto plan built around early temple walks, quiet '
        'lanes and unhurried evenings — with enough space to wander.';

    final enrichment = <String, dynamic>{
      'meaningful_title': 'Three quiet days in Kyoto',
      'summary': summary,
      'category': 'Travel',
      'tags': ['kyoto', 'japan', 'slow travel', 'autumn'],
      'content_type': 'travel_guide',
      'primary_intent': 'visit',
      'life_area': 'travel',
      'why_saved_hypothesis':
          'You may want a quieter, more intentional Kyoto trip.',
      'key_points': [
        'Start Kiyomizu-dera before the tour groups arrive',
        'Leave one afternoon open for the Philosopher’s Path',
        'Spend an evening walking the lantern-lit lanes of Gion',
      ],
      'mentions': [
        {
          'title': 'Kiyomizu-dera',
          'type': 'place',
          'why_mentioned': 'A peaceful first stop just after sunrise.',
        },
        {
          'title': 'Philosopher’s Path',
          'type': 'place',
          'why_mentioned': 'A slow walk between small temples and cafés.',
        },
        {
          'title': 'Gion',
          'type': 'place',
          'why_mentioned': 'Best experienced after dusk when the lanes settle.',
        },
      ],
    };

    return SavedUrl()
      ..rawUrl = demoRawUrl
      ..domain = 'kyoto.travel'
      ..title = 'Three quiet days in Kyoto'
      ..description = 'An unhurried Kyoto itinerary for a future autumn trip.'
      ..thumbnailUrl = demoThumbnailAsset
      ..category = 'Travel'
      ..categoryEmoji = '✈️'
      ..categories = ['Travel']
      ..tags = ['kyoto', 'japan', 'slow travel', 'autumn']
      ..summary = summary
      ..enrichmentJson = jsonEncode(enrichment)
      ..processingStatus = UrlProcessingStatus.ready
      ..savedAt = savedAt ?? DateTime.now();
  }
}
