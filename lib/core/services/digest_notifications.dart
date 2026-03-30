import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notifications for the weekly digest.
class DigestNotifications {
  DigestNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Full init for the main UI isolate.
  /// Wires up tap callbacks, requests POST_NOTIFICATIONS permission (Android
  /// 13+), and handles the case where the notification cold-launched the app.
  static Future<void> init({
    required void Function() onOpenDigest,
  }) async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (details) {
        if (details.payload == 'digest') onOpenDigest();
      },
    );

    // Android 13+ requires an explicit runtime permission grant.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true &&
        launch?.notificationResponse?.payload == 'digest') {
      onOpenDigest();
    }
  }

  /// Minimal init for the WorkManager background isolate.
  /// No navigation callbacks — the background isolate has no UI context.
  /// Must be called before [showDigest] in any background task.
  static Future<void> initForBackground() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
  }

  static Future<void> showDigest({
    required List<String> summaries,
    required int linkCount,
  }) async {
    final body = summaries
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');

    final androidDetails = AndroidNotificationDetails(
      'glimpse_digest',
      'Weekly Digest',
      channelDescription: 'Your weekly reading roundup from Glimpse',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      styleInformation: BigTextStyleInformation(
        body,
        summaryText: '$linkCount links worth reading',
      ),
    );

    await _plugin.show(
      0,
      '📬 Your Glimpse Digest',
      body,
      NotificationDetails(android: androidDetails),
      payload: 'digest',
    );
  }
}
