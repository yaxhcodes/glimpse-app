import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../database/isar_service.dart';
import '../models/saved_url.dart';
import '../models/url_processing_status.dart';

/// Seeds — and later clears — the single pre-baked "book reel" entry that the
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
  /// with a real Instagram save.
  static const String demoRawUrl =
      'https://www.instagram.com/reel/glimpse-onboarding-books';

  /// Id of the seeded demo entry, or null when none is present.
  static Future<int?> demoId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_demoIdKey);
  }

  /// Inserts the demo entry unless one already exists. Returns its id.
  Future<int> seed() async {
    final existing = await demoId();
    if (existing != null && await _isar.getUrlById(existing) != null) {
      return existing;
    }

    final id = await _isar.saveUrl(_buildDemoUrl());
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

  SavedUrl _buildDemoUrl() {
    const summary =
        'Five books on attention, habit and how the mind works — each with a '
        "one-line reason it made the creator's shortlist.";

    final enrichment = <String, dynamic>{
      'meaningful_title': '5 books that rewired how I think',
      'summary': summary,
      'category': 'Books',
      'tags': ['mindset', 'focus', 'reading', 'psychology'],
      'content_type': 'recommendation',
      'creator': 'quietpages',
      'like_count': 24100,
      'comment_count': 402,
      'key_points': [
        'One chapter a night beats setting a reading goal',
        'Note the idea, not the highlight',
        'Re-reading a great book beats rushing to the next one',
      ],
      'mentions': [
        {
          'title': 'Thinking, Fast and Slow',
          'type': 'book',
          'why_mentioned': 'The two-systems model the reel opens with.',
          'poster_url':
              'https://covers.openlibrary.org/b/isbn/9780374533557-L.jpg',
        },
        {
          'title': 'Atomic Habits',
          'type': 'book',
          'why_mentioned': 'The habit-stacking idea at 0:14.',
          'poster_url':
              'https://covers.openlibrary.org/b/isbn/9780735211292-L.jpg',
        },
        {
          'title': 'Deep Work',
          'type': 'book',
          'why_mentioned': 'Why she deleted the apps for a month.',
          'poster_url':
              'https://covers.openlibrary.org/b/isbn/9781455586691-L.jpg',
        },
        {
          'title': 'Sapiens',
          'type': 'book',
          'why_mentioned': 'On the stories we tell ourselves.',
          'poster_url':
              'https://covers.openlibrary.org/b/isbn/9780062316110-L.jpg',
        },
      ],
    };

    return SavedUrl()
      ..rawUrl = demoRawUrl
      ..domain = 'instagram.com'
      ..title = '5 books that rewired how I think'
      ..description =
          "A creator's shortlist of five books on attention, habit and the mind."
      ..category = 'Books'
      ..categoryEmoji = '📚'
      ..categories = ['Books']
      ..tags = ['mindset', 'focus', 'reading', 'psychology']
      ..summary = summary
      ..enrichmentJson = jsonEncode(enrichment)
      ..processingStatus = UrlProcessingStatus.ready
      ..savedAt = DateTime.now();
  }
}
