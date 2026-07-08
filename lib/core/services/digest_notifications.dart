import 'dart:developer' as developer;
import 'dart:math' show Random;

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'digest_prefs.dart';
import 'notification_action_handler.dart';

/// Background-isolate entry point for action-button taps when the app is
/// terminated. Must be top-level and vm:entry-point so the plugin can find it.
@pragma('vm:entry-point')
void notificationBackgroundResponse(NotificationResponse response) {
  NotificationActionHandler.handleIfAction(response);
}

/// Notification types used for copy generation and routing.
/// All types share a single Android notification channel for proper grouping.
enum NotifType {
  geography,
  newInterest,
  collector,
  streak,
  resurface,
  digest,

  /// A save the user explicitly bookmarked to return to ("Watch Later", "Try
  /// This Weekend", …) whose chosen moment has now arrived. Highest-signal,
  /// least-spammy type — the user asked for it.
  revisitDue,
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

  static final _rnd = Random.secure();

  /// [onOpenNotification] receives the raw JSON payload string from a tap or cold start.
  static Future<void> init({
    required void Function(String? payload) onOpenNotification,
  }) async {
    const android = AndroidInitializationSettings('ic_notification');
    await _plugin.initialize(
      InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (details) async {
        // Action buttons (Done / Later) mutate intent without routing; a plain
        // body tap falls through to open the app.
        if (await NotificationActionHandler.handleIfAction(details)) return;
        onOpenNotification(details.payload);
      },
      onDidReceiveBackgroundNotificationResponse:
          notificationBackgroundResponse,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      onOpenNotification(launch?.notificationResponse?.payload);
    }

    // Ensure the channel exists with the correct importance BEFORE any
    // notification is shown. Without this, the first notification to fire
    // creates the channel — if that happens to be the low-importance summary,
    // all subsequent child notifications inherit the low importance and may
    // not appear reliably.
    await _ensureChannel();
  }

  static Future<void> initForBackground() async {
    const android = AndroidInitializationSettings('ic_notification');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveBackgroundNotificationResponse:
          notificationBackgroundResponse,
    );
    await _ensureChannel();
  }

  static Future<void> _ensureChannel() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      ),
    );
  }

  /// Generates a unique notification ID that fits inside Android's 32-bit
  /// signed int. `DateTime.now().millisecondsSinceEpoch` overflows that range,
  /// which silently suppresses notifications on some Android versions.
  static int _uniqueNotifId() {
    // Mix timestamp + random so collisions are extremely unlikely.
    final ts = DateTime.now().millisecondsSinceEpoch % 0x7FFFFFFF;
    final salt = _rnd.nextInt(0xFFFF);
    return (ts ^ salt).abs();
  }

  /// [payloadJson] must be the full serialized notification payload (type, linkIds, title, …).
  static Future<void> show({
    required NotifType type,
    required String title,
    required String body,
    required String payloadJson,
    bool withActions = false,
  }) async {
    final notifId = _uniqueNotifId();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      groupKey: _groupKey,
      styleInformation: BigTextStyleInformation(body),
      icon: 'ic_notification',
      // Quick triage on single-link notifications: archive or push out the
      // revisit without opening the app. The plain body tap still opens it.
      actions: withActions
          ? const [
              AndroidNotificationAction(
                NotificationActions.markDone,
                'Done',
                showsUserInterface: false,
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                NotificationActions.snooze,
                'Later',
                showsUserInterface: false,
                cancelNotification: true,
              ),
            ]
          : null,
    );

    try {
      await _plugin.show(
        notifId,
        title,
        body,
        NotificationDetails(android: androidDetails),
        payload: payloadJson,
      );
    } on PlatformException catch (e, st) {
      developer.log(
        'Failed to show notification.',
        name: 'DigestNotifications',
        error: e,
        stackTrace: st,
      );
      return;
    }

    try {
      await _updateGroupSummary();
    } on PlatformException catch (e, st) {
      developer.log(
        'Failed to update notification group summary.',
        name: 'DigestNotifications',
        error: e,
        stackTrace: st,
      );
    }
  }

  static Future<void> _updateGroupSummary() async {
    final history = await DigestPrefs.loadHistory();

    // Only consider entries that were actually sent as notifications.
    final notifEntries = history
        .where((e) => e['notifId'] != null)
        .take(5)
        .toList();

    final count = notifEntries.length;

    // No need for a summary when there are no notifications.
    if (count == 0) return;

    // For a single notification, Android shows it directly; a summary
    // is unnecessary and can actually suppress the child on some devices.
    if (count == 1) {
      // Cancel any previously-shown summary so it doesn't linger.
      await _cancelGroupSummary();
      return;
    }

    final titles = notifEntries
        .map((e) => e['topic']?.toString() ?? 'Notification')
        .toList();

    final summaryText = count == 1
        ? '1 new notification'
        : '$count new notifications';

    final summaryDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      // Match child importance so the group is never demoted.
      importance: Importance.high,
      priority: Priority.high,
      groupKey: _groupKey,
      setAsGroupSummary: true,
      styleInformation: InboxStyleInformation(
        titles,
        contentTitle: 'Glimpse',
        summaryText: summaryText,
      ),
      icon: 'ic_notification',
    );

    // Provide a non-empty body — some OEM skins suppress notifications
    // with empty content strings.
    await _plugin.show(
      _summaryNotifId,
      'Glimpse',
      summaryText,
      NotificationDetails(android: summaryDetails),
    );
  }

  static Future<void> _cancelGroupSummary() async {
    try {
      await _plugin.cancel(_summaryNotifId);
    } on PlatformException catch (e, st) {
      developer.log(
        'Failed to cancel notification group summary.',
        name: 'DigestNotifications',
        error: e,
        stackTrace: st,
      );
    }
  }
}
