import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Six notification types with dedicated channels and stable ID ranges.
enum NotifType {
  geography(
    baseId: 100,
    channelId: 'glimpse_travel',
    channelName: 'Travel & Places',
    channelDesc: 'Alerts about places and travel-related saves',
  ),
  newInterest(
    baseId: 200,
    channelId: 'glimpse_discovery',
    channelName: 'New Discoveries',
    channelDesc: 'When a new topic shows up in your library',
  ),
  collector(
    baseId: 300,
    channelId: 'glimpse_reading',
    channelName: 'Reading Reminders',
    channelDesc: 'Gentle nudges about unread collections',
  ),
  streak(
    baseId: 400,
    channelId: 'glimpse_activity',
    channelName: 'Your Activity',
    channelDesc: 'Saving and reading patterns',
  ),
  resurface(
    baseId: 500,
    channelId: 'glimpse_revisit',
    channelName: 'Links Worth Revisiting',
    channelDesc: 'Older saves you might want to open',
  ),
  digest(
    baseId: 600,
    channelId: 'glimpse_digest',
    channelName: 'Weekly Digest',
    channelDesc: 'Your weekly reading roundup',
  );

  const NotifType({
    required this.baseId,
    required this.channelId,
    required this.channelName,
    required this.channelDesc,
  });

  final int baseId;
  final String channelId;
  final String channelName;
  final String channelDesc;

  /// Per-channel counter in prefs so each [NotifType] cycles baseId+0…baseId+9 independently.
  Future<int> nextId() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'notif_counter_$channelId';
    final current = prefs.getInt(key) ?? 0;
    final next = (current + 1) % 10;
    await prefs.setInt(key, next);
    return baseId + next;
  }
}

const _groupKey = 'glimpse_notifications';

class DigestNotifications {
  DigestNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// [onOpenNotification] receives the raw JSON payload string from a tap or cold start.
  static Future<void> init({
    required void Function(String? payload) onOpenNotification,
    void Function(String action, String? payload)? onAction,
  }) async {
    const android = AndroidInitializationSettings('ic_notification');
    await _plugin.initialize(
      InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        final actionId = details.actionId;
        if (actionId != null && actionId.isNotEmpty && onAction != null) {
          onAction(actionId, payload);
        } else {
          onOpenNotification(payload);
        }
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
    final actions = <AndroidNotificationAction>[
      const AndroidNotificationAction(
        'open_link',
        'Open in Glimpse',
        showsUserInterface: true,
      ),
      const AndroidNotificationAction(
        'mark_read',
        'Mark read',
      ),
    ];

    final androidDetails = AndroidNotificationDetails(
      type.channelId,
      type.channelName,
      channelDescription: type.channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      groupKey: _groupKey,
      styleInformation: BigTextStyleInformation(body),
      actions: actions,
      icon: 'ic_notification',
    );

    final notifId = await type.nextId();
    await _plugin.show(
      notifId,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: payloadJson,
    );

    await _showGroupSummary();
  }

  static Future<void> _showGroupSummary() async {
    const summaryDetails = AndroidNotificationDetails(
      'glimpse_summary',
      'Glimpse',
      channelDescription: 'Grouped Glimpse notifications',
      importance: Importance.low,
      priority: Priority.low,
      groupKey: _groupKey,
      setAsGroupSummary: true,
      styleInformation: InboxStyleInformation([]),
      icon: 'ic_notification',
    );

    await _plugin.show(
      0,
      'Glimpse',
      '',
      const NotificationDetails(android: summaryDetails),
    );
  }
}
