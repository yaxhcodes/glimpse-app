import 'dart:convert';

import '../models/saved_url.dart';
import 'digest_notifications.dart';
import 'summary_rewriter.dart';
import 'summary_trimmer.dart';
import 'title_resolver.dart';
import 'transcript_enrichment_service.dart';
import '../../l10n/l10n.dart';

class UrlSaveNotifications {
  UrlSaveNotifications._();

  static Future<void> showCaptureStarted() async {
    final strings = await loadBackgroundLocalizations();
    final captureTitle = strings.captureTitle;
    final captureBody = strings.captureBody;
    final payload = jsonEncode({
      'type': 'url_capture_started',
      'route': 'home',
      'title': captureTitle,
      'body': captureBody,
    });

    await DigestNotifications.show(
      type: NotifType.resurface,
      title: captureTitle,
      body: captureBody,
      payloadJson: payload,
    );
  }

  static Future<void> showSavedToCollection(String collectionName) async {
    final strings = await loadBackgroundLocalizations();
    final title = strings.savedToCollection(collectionName);
    final body = strings.makingSense;
    final payload = jsonEncode({
      'type': 'url_saved_to_collection',
      'route': 'home',
      'title': title,
      'body': body,
    });

    await DigestNotifications.show(
      type: NotifType.resurface,
      title: title,
      body: body,
      payloadJson: payload,
    );
  }

  /// Shown after a shared save when the user is out of free AI saves: the
  /// bookmark was kept but not AI-enriched. Tapping routes to the subscription
  /// page (handled by NotificationRouter's `subscription` route).
  static Future<void> showAiLimitReached() async {
    final strings = await loadBackgroundLocalizations();
    final title = strings.savedWithoutAi;
    final body = strings.aiLimitBody;
    final payload = jsonEncode({
      'type': 'url_capture_limit',
      'route': 'subscription',
      'title': title,
      'body': body,
    });

    await DigestNotifications.show(
      type: NotifType.resurface,
      title: title,
      body: body,
      payloadJson: payload,
    );
  }

  static Future<void> showAlreadyCaptured(SavedUrl url) async {
    final strings = await loadBackgroundLocalizations();
    final title = _notificationTitle(url);
    final body = _notificationBody(url) ?? strings.alreadyInYourWorld;
    final payload = _urlPayload(
      type: 'url_capture_duplicate',
      url: url,
      title: title,
      body: body,
    );

    await DigestNotifications.show(
      type: NotifType.resurface,
      title: title,
      body: body,
      payloadJson: jsonEncode(payload),
    );
  }

  static Future<void> showCaptureReady(SavedUrl url) async {
    final body = _notificationBody(url);
    if (body == null) return;

    final title = _notificationTitle(url);
    final payload = _urlPayload(
      type: 'url_capture_ready',
      url: url,
      title: title,
      body: body,
    );

    await DigestNotifications.show(
      type: NotifType.newInterest,
      title: title,
      body: body,
      payloadJson: jsonEncode(payload),
    );
  }

  static Future<void> showCaptureFailed(SavedUrl url) async {
    final strings = await loadBackgroundLocalizations();
    final title = strings.enrichmentFailed;
    final body = strings.tapToRetry;
    final payload = _urlPayload(
      type: 'url_capture_failed',
      url: url,
      title: title,
      body: body,
    );

    await DigestNotifications.show(
      type: NotifType.resurface,
      title: title,
      body: body,
      payloadJson: jsonEncode(payload),
    );
  }

  static Map<String, dynamic> _urlPayload({
    required String type,
    required SavedUrl url,
    required String title,
    required String body,
  }) {
    return {
      'type': type,
      'route': 'url_detail',
      'linkIds': [url.id],
      'title': title,
      'body': body,
      'contentType': _savedEnrichment(url)?.contentType ?? 'generic',
      'firedAt': DateTime.now().toIso8601String(),
    };
  }

  static String _notificationTitle(SavedUrl url) {
    final recipe = _savedEnrichment(url)?.recipe;
    if (recipe != null && recipe.title.trim().isNotEmpty) {
      return TitleResolver.truncateTitle(recipe.title.trim(), maxLength: 52);
    }
    final resolved = TitleResolver.resolveDetailTitle(url);
    return TitleResolver.truncateTitle(resolved, maxLength: 52);
  }

  static String? _notificationBody(SavedUrl url) {
    final recipe = _savedEnrichment(url)?.recipe;
    if (recipe != null) {
      final recipeSummary = SummaryRewriter.clean(
        recipe.summary ?? recipe.description,
      );
      if (recipeSummary.isNotEmpty) {
        return SummaryTrimmer.trim(recipeSummary, maxLength: 150);
      }
    }

    final summary = SummaryRewriter.clean(url.summary);
    if (summary.isNotEmpty) {
      return _microSummary(summary);
    }

    final description = SummaryRewriter.clean(url.description);
    if (description.isNotEmpty) {
      return _microSummary(description);
    }

    return null;
  }

  static String _microSummary(String text) {
    final sentence = SummaryTrimmer.trim(
      text,
      maxLength: 96,
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
    final words = sentence.split(' ').where((word) => word.isNotEmpty).toList();
    if (words.length <= 12) return sentence;
    return '${words.take(12).join(' ')}.';
  }

  static TranscriptEnrichmentResult? _savedEnrichment(SavedUrl url) {
    final raw = url.enrichmentJson;
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return TranscriptEnrichmentResult.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }
}
