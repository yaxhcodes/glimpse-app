import 'package:shared_preferences/shared_preferences.dart';

enum UrlEnrichmentNotificationOutcome { ready, failed, aiLimitReached }

/// Persists notification intent and prevents terminal save-status replays.
class UrlEnrichmentNotificationGuard {
  UrlEnrichmentNotificationGuard._();

  static const _deliveredKeyPrefix =
      'url_enrichment_notification_delivered_';
  static const _expectedKeyPrefix = 'url_enrichment_notification_expected_';

  static Future<void> markDeliveryExpected(String processingId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('$_expectedKeyPrefix$processingId', true);
  }

  static Future<bool> isDeliveryExpected(String processingId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    return preferences.getBool('$_expectedKeyPrefix$processingId') ?? false;
  }

  static Future<bool> shouldDeliverFor(
    String processingId, {
    required bool notifyOnCompletion,
  }) async {
    return notifyOnCompletion && await isDeliveryExpected(processingId);
  }

  static Future<bool> deliverOnce(
    String processingId,
    UrlEnrichmentNotificationOutcome outcome,
    Future<void> Function() deliver,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final key = '$_deliveredKeyPrefix$processingId';
    final previousName = preferences.getString(key);
    if (previousName == outcome.name) {
      await preferences.remove('$_expectedKeyPrefix$processingId');
      return false;
    }
    if (previousName == UrlEnrichmentNotificationOutcome.ready.name ||
        previousName == UrlEnrichmentNotificationOutcome.aiLimitReached.name) {
      await preferences.remove('$_expectedKeyPrefix$processingId');
      return false;
    }

    await deliver();
    await preferences.setString(key, outcome.name);
    await preferences.remove('$_expectedKeyPrefix$processingId');
    return true;
  }
}
