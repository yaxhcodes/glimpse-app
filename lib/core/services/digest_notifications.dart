import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'digest_prefs.dart';

/// Notification types used for copy generation and routing.
/// All types share a single Android notification channel for proper grouping.
enum NotifType {
  geography,
  newInterest,
  collector,
  streak,
  resurface,
  digest;
}

const _groupKey = 'glimpse_notifications';
const _channelId = 'glimpse_notifications';
const _channelName = 'Glimpse';
const _channelDesc = 'Smart notifications about your saved links';

/// Fixed notification ID used for the group summary.
const _summaryNotifId = 0;

class DigestNotifications {
  DigestNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// [onOpenNotification] receives the raw JSON payload string from a tap or cold start.
  static Future<void> init({
    required void Function(String? payload) onOpenNotification,
  }) async {
    const android = AndroidInitializationSettings('ic_notification');
    await _plugin.initialize(
      InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (details) {
        onOpenNotification(details.payload);
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      onOpenNotification(launch?.notificationResponse?.payload);
    }
  }

  static Future<void> initForBackground() async {
    const android = AndroidInitializationSettings('ic_notification');
    await _plugin.initialize(const InitializationSettings(android: android));
  }

  /// [payloadJson] must be the full serialized notification payload (type, linkIds, title, …).
  static Future<void> show({
    required NotifType type,
    required String title,
    required String body,
    required String payloadJson,
  }) async {
    final notifId = DateTime.now().millisecondsSinceEpoch;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      groupKey: _groupKey,
      styleInformation: BigTextStyleInformation(body),
      icon: 'ic_notification',
    );

    await _plugin.show(
      notifId,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: payloadJson,
    );

    await _updateGroupSummary();
  }

  static Future<void> _updateGroupSummary() async {
    final history = await DigestPrefs.loadHistory();

    // Only consider entries that were actually sent as notifications.
    final notifEntries = history
        .where((e) => e['notifId'] != null)
        .take(5)
        .toList();

    final count = notifEntries.length;
    final titles = notifEntries
        .map((e) => e['topic']?.toString() ?? 'Notification')
        .toList();

    final summaryDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.low,
      priority: Priority.low,
      groupKey: _groupKey,
      setAsGroupSummary: true,
      styleInformation: InboxStyleInformation(
        titles,
        contentTitle: 'Glimpse',
        summaryText: count == 1
            ? '1 new notification'
            : '$count new notifications',
      ),
      icon: 'ic_notification',
    );

    await _plugin.show(
      _summaryNotifId,
      'Glimpse',
      '',
      NotificationDetails(android: summaryDetails),
    );
  }
}
