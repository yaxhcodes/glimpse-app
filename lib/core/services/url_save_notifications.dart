import 'dart:convert';

import '../models/saved_url.dart';
import 'digest_notifications.dart';
import 'notification_summary_formatter.dart';
import 'summary_rewriter.dart';
import 'title_resolver.dart';
import 'transcript_enrichment_service.dart';
import '../../l10n/l10n.dart';

class UrlSaveNotifications {
  UrlSaveNotifications._();

  /// Shown after a shared save when the user is out of free AI saves: the
  /// bookmark was kept but not AI-enriched. Tapping routes to the subscription
  /// page (handled by NotificationRouter's `subscription` route).
  static Future<void> showAiLimitReached({
    required bool isPro,
    required int savedUrlId,
  }) async {
    final strings = await loadBackgroundLocalizations();
    final title = strings.savedWithoutAi;
    final body = isPro ? strings.proAiLimitBody : strings.aiLimitBody;
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
      notificationId: notificationIdForSavedUrl(savedUrlId),
    );
  }

  static Future<void> showCaptureReady(SavedUrl url) async {
    final strings = await loadBackgroundLocalizations();
    final body = notificationBody(url) ?? strings.enrichmentComplete;

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
      notificationId: notificationIdForSavedUrl(url.id),
      withActions: true,
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
      notificationId: notificationIdForSavedUrl(url.id),
    );
  }

  static int notificationIdForSavedUrl(int savedUrlId) {
    const namespace = 0x20000000;
    const mask = 0x1FFFFFFF;
    return namespace + (savedUrlId.abs() & mask);
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

  static String? notificationBody(SavedUrl url) {
    final enrichment = _savedEnrichment(url);
    final notificationBlurb = SummaryRewriter.clean(
      enrichment?.notificationBlurb,
    );
    if (notificationBlurb.isNotEmpty) {
      return NotificationSummaryFormatter.format(notificationBlurb);
    }

    final recipe = enrichment?.recipe;
    if (recipe != null) {
      final recipeSummary = SummaryRewriter.clean(
        recipe.summary ?? recipe.description,
      );
      if (recipeSummary.isNotEmpty) {
        return NotificationSummaryFormatter.format(recipeSummary);
      }
    }

    final summary = SummaryRewriter.clean(url.summary);
    if (summary.isNotEmpty) {
      return NotificationSummaryFormatter.format(summary);
    }

    final description = SummaryRewriter.clean(url.description);
    if (description.isNotEmpty) {
      return NotificationSummaryFormatter.format(description);
    }

    return null;
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
