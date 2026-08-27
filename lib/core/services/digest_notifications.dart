import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' show Random;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../l10n/l10n.dart';
import 'digest_prefs.dart';
import 'notification_action_handler.dart';

/// Background-isolate entry point for action-button taps when the app is
/// terminated. Must be top-level and vm:entry-point so the plugin can find it.
@pragma('vm:entry-point')
void notificationBackgroundResponse(NotificationResponse response) {
  unawaited(() async {
    await NotificationActionHandler.handleIfAction(response);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await DigestNotifications.reconcileGroupSummary();
  }());
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

/// Fixed notification ID used for the group summary.
const _summaryNotifId = 0;

@immutable
class NotificationGroupSnapshot {
  const NotificationGroupSnapshot({required this.count, required this.titles});

  final int count;
  final List<String> titles;
}

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
        final handled = await NotificationActionHandler.handleIfAction(details);
        if (!handled) onOpenNotification(details.payload);
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await reconcileGroupSummary();
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

    final l10n = await loadBackgroundLocalizations();

    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: l10n.smartNotificationsDescription,
        importance: Importance.high,
      ),
    );
  }

  static Future<bool> areNotificationsEnabled() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return false;
    try {
      return await androidPlugin.areNotificationsEnabled() ?? false;
    } on PlatformException catch (error, stackTrace) {
      developer.log(
        'Could not read notification permission state.',
        name: 'DigestNotifications',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Generates a unique notification ID that fits inside Android's 32-bit
  /// signed int. `DateTime.now().millisecondsSinceEpoch` overflows that range,
  /// which silently suppresses notifications on some Android versions.
  static int _uniqueNotifId() {
    // Keep random curated ids below the reserved save-status namespace.
    final ts = DateTime.now().millisecondsSinceEpoch % 0x1FFFFFFF;
    final salt = _rnd.nextInt(0xFFFF);
    return ((ts ^ salt) & 0x1FFFFFFF) + 1;
  }

  /// [payloadJson] must be the full serialized notification payload (type, linkIds, title, …).
  /// [persistInHistory] is reserved for curated/scheduled notifications; save
  /// and capture status notifications belong in the system tray only.
  static Future<void> show({
    required NotifType type,
    required String title,
    required String body,
    required String payloadJson,
    bool withActions = false,
    bool persistInHistory = false,
    String? historyType,
    String? historySignature,
    int? notificationId,
  }) async {
    final notifId = notificationId ?? _uniqueNotifId();
    final l10n = await loadBackgroundLocalizations();
    final payload = _decodePayload(payloadJson);
    final logicalNotifId = payload['notifId']?.toString() ?? 'notif_$notifId';
    payload['notifId'] = logicalNotifId;
    final effectivePayloadJson = jsonEncode(payload);
    final linkIds = _linkIdsFromPayload(payload);

    String? historyId;
    if (persistInHistory) {
      await DigestPrefs.saveNotifPayload(logicalNotifId, payload);
      historyId = await DigestPrefs.addDigestToHistory(
        ids: linkIds,
        summaries: [body],
        topic: title,
        type: historyType ?? _historyTypeFor(type),
        notifId: logicalNotifId,
        body: body,
        sig: historySignature,
      );
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: l10n.smartNotificationsDescription,
      importance: Importance.high,
      priority: Priority.high,
      groupKey: _groupKey,
      styleInformation: BigTextStyleInformation(body),
      icon: 'ic_notification',
      // Quick triage on single-link notifications: archive or push out the
      // revisit without opening the app. The plain body tap still opens it.
      actions: withActions
          ? [
              AndroidNotificationAction(
                NotificationActions.markDone,
                l10n.done,
                showsUserInterface: false,
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                NotificationActions.snooze,
                l10n.later,
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
        payload: effectivePayloadJson,
      );
    } on PlatformException catch (e, st) {
      if (historyId != null) {
        await DigestPrefs.deleteDigest(historyId);
        await DigestPrefs.deleteNotifPayload(logicalNotifId);
      }
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

  static Map<String, dynamic> _decodePayload(String payloadJson) {
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Routing falls back to the notifications hub for malformed payloads.
    }
    return <String, dynamic>{};
  }

  static List<int> _linkIdsFromPayload(Map<String, dynamic> payload) {
    final raw = payload['linkIds'] ?? payload['ids'];
    if (raw is! List) return const [];
    return raw.whereType<num>().map((id) => id.toInt()).toList();
  }

  static String _historyTypeFor(NotifType type) {
    return switch (type) {
      NotifType.geography => 'geo',
      NotifType.newInterest => 'new_interest',
      NotifType.collector => 'collector',
      NotifType.streak => 'streak',
      NotifType.resurface => 'resurface',
      NotifType.digest => 'digest',
      NotifType.revisitDue => 'revisit',
    };
  }

  @visibleForTesting
  static NotificationGroupSnapshot snapshotForActiveNotifications(
    Iterable<ActiveNotification> notifications,
  ) {
    final children = notifications.where(
      (notification) =>
          notification.id != _summaryNotifId &&
          notification.groupKey == _groupKey,
    );
    return NotificationGroupSnapshot(
      count: children.length,
      titles: children
          .map((notification) => notification.title?.trim() ?? '')
          .where((title) => title.isNotEmpty)
          .toList(),
    );
  }

  static Future<void> _updateGroupSummary() async {
    final l10n = await loadBackgroundLocalizations();
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    NotificationGroupSnapshot? snapshot;
    if (androidPlugin != null) {
      try {
        snapshot = snapshotForActiveNotifications(
          await androidPlugin.getActiveNotifications(),
        );
      } on PlatformException catch (e, st) {
        developer.log(
          'Failed to read active notifications for group summary.',
          name: 'DigestNotifications',
          error: e,
          stackTrace: st,
        );
      }
    }

    if (snapshot == null) {
      final history = await DigestPrefs.loadHistory();
      final entries = history
          .where((entry) => entry['notifId'] != null && entry['read'] != true)
          .toList();
      snapshot = NotificationGroupSnapshot(
        count: entries.length,
        titles: entries
            .map(
              (entry) =>
                  entry['topic']?.toString() ?? l10n.notificationFallbackTitle,
            )
            .toList(),
      );
    }

    final count = snapshot.count;

    if (count == 0) {
      await _cancelGroupSummary();
      return;
    }

    // For a single notification, Android shows it directly; a summary
    // is unnecessary and can actually suppress the child on some devices.
    if (count == 1) {
      // Cancel any previously-shown summary so it doesn't linger.
      await _cancelGroupSummary();
      return;
    }

    final titles = snapshot.titles.take(5).toList();

    final summaryText = l10n.newNotificationCount(count);

    final summaryDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: l10n.smartNotificationsDescription,
      // Match child importance so the group is never demoted.
      importance: Importance.high,
      priority: Priority.high,
      groupKey: _groupKey,
      setAsGroupSummary: true,
      // Foreground reconciliation republishes this fixed notification ID.
      // Keep its content current without making Android alert again.
      onlyAlertOnce: true,
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

  static Future<void> reconcileGroupSummary() => _updateGroupSummary();
}
