import 'dart:convert';

import '../models/saved_url.dart';
import 'digest_notifications.dart';
import 'summary_rewriter.dart';
import 'summary_trimmer.dart';
import 'title_resolver.dart';

class UrlSaveNotifications {
  UrlSaveNotifications._();

  static const _captureTitle = 'Capturing what caught your eye.';
  static const _captureBody = "We'll notify you when it's ready.";

  static Future<void> showCaptureStarted() {
    final payload = jsonEncode({
      'type': 'url_capture_started',
      'title': _captureTitle,
      'body': _captureBody,
    });

    return DigestNotifications.show(
      type: NotifType.resurface,
      title: _captureTitle,
      body: _captureBody,
      payloadJson: payload,
    );
  }

  static Future<void> showAlreadyCaptured(SavedUrl url) {
    final title = _notificationTitle(url);
    final body = _notificationBody(url) ?? 'Already in your world.';
    final payload = _urlPayload(
      type: 'url_capture_duplicate',
      url: url,
      title: title,
      body: body,
    );

    return DigestNotifications.show(
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
      'firedAt': DateTime.now().toIso8601String(),
    };
  }

  static String _notificationTitle(SavedUrl url) {
    final resolved = TitleResolver.resolveStableDisplayTitle(url);
    return TitleResolver.truncateTitle(resolved, maxLength: 64);
  }

  static String? _notificationBody(SavedUrl url) {
    final summary = SummaryRewriter.clean(url.summary);
    if (summary.isNotEmpty) {
      return SummaryTrimmer.trim(summary, maxLength: 150);
    }

    final description = SummaryRewriter.clean(url.description);
    if (description.isNotEmpty) {
      return SummaryTrimmer.trim(description, maxLength: 150);
    }

    return null;
  }
}
