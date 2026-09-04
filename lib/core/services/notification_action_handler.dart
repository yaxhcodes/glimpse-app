import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/isar_service.dart';
import 'notif_bandit.dart';

/// Action-button ids used on actionable notifications (resurface / revisit).
/// "Open" is the default body tap — it has no button id.
class NotificationActions {
  NotificationActions._();

  static const markDone = 'mark_done';
  static const snooze = 'snooze';

  /// How far out a snoozed save is pushed before it's due again.
  static const snoozeWindow = Duration(days: 3);
}

/// Applies the on-device intent change behind a notification action button,
/// in either the main isolate (app alive) or the plugin's background isolate
/// (app terminated). Opens its own [IsarService] so it never depends on the
/// app's provider graph.
class NotificationActionHandler {
  NotificationActionHandler._();

  static const _pendingKey = 'pending_notification_action_receipts_v1';
  static const _completedKey = 'completed_notification_action_receipts_v1';
  static const _completedLimit = 64;

  /// Returns true when [response] was an action this handler consumed (so the
  /// caller should NOT also route/open the app). Tapping the body (no actionId,
  /// or an unknown id) returns false.
  static Future<bool> handleIfAction(NotificationResponse response) async {
    final actionId = response.actionId;
    if (actionId != NotificationActions.markDone &&
        actionId != NotificationActions.snooze) {
      return false;
    }

    WidgetsFlutterBinding.ensureInitialized();
    final receipt = _ActionReceipt.fromResponse(response, actionId!);
    await _persistPending(receipt);
    await _applyReceipt(receipt);
    return true;
  }

  /// Replays receipts persisted before a background isolate was interrupted.
  /// Intent mutations are idempotent and completed receipt ids are retained in
  /// a small bounded set so duplicate Android deliveries are harmless.
  static Future<void> replayPendingActions() async {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final pending = _decodeReceipts(prefs.getStringList(_pendingKey));
    for (final receipt in pending) {
      try {
        await _applyReceipt(receipt);
      } catch (error, stackTrace) {
        developer.log(
          'Could not replay a pending notification action.',
          name: 'NotificationActionHandler',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  static Future<void> _persistPending(_ActionReceipt receipt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final completed = prefs.getStringList(_completedKey) ?? const [];
    if (completed.contains(receipt.id)) return;
    final pending = _decodeReceipts(prefs.getStringList(_pendingKey));
    if (pending.any((item) => item.id == receipt.id)) return;
    pending.add(receipt);
    await prefs.setStringList(
      _pendingKey,
      pending.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  static Future<void> _applyReceipt(_ActionReceipt receipt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final completed = prefs.getStringList(_completedKey) ?? <String>[];
    if (completed.contains(receipt.id)) {
      await _removePending(prefs, receipt.id);
      return;
    }

    if (receipt.linkIds.isNotEmpty) {
      final isar = IsarService();
      await isar.ensureInitialized();
      final revisitAfter = DateTime.now().add(NotificationActions.snoozeWindow);
      for (final id in receipt.linkIds) {
        if (receipt.actionId == NotificationActions.markDone) {
          await isar.updateIntent(
            id,
            status: 'done',
            action: 'notif_done',
            awaitEngagement: true,
          );
        } else {
          await isar.updateIntent(
            id,
            status: 'queued',
            action: 'snoozed',
            revisitAfter: revisitAfter,
            awaitEngagement: true,
          );
        }
      }
    }

    if (receipt.notificationType?.length == 1) {
      await NotifBandit.recordOpenOnce(
        receipt.notificationType!,
        receipt.logicalNotificationId,
      );
    }
    if (receipt.notificationId != null) {
      await FlutterLocalNotificationsPlugin().cancel(receipt.notificationId!);
    }

    final nextCompleted = <String>[...completed, receipt.id];
    if (nextCompleted.length > _completedLimit) {
      nextCompleted.removeRange(0, nextCompleted.length - _completedLimit);
    }
    await prefs.setStringList(_completedKey, nextCompleted);
    await _removePending(prefs, receipt.id);
  }

  static Future<void> _removePending(
    SharedPreferences prefs,
    String receiptId,
  ) async {
    final pending = _decodeReceipts(prefs.getStringList(_pendingKey))
      ..removeWhere((item) => item.id == receiptId);
    await prefs.setStringList(
      _pendingKey,
      pending.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  static List<_ActionReceipt> _decodeReceipts(List<String>? raw) {
    if (raw == null) return <_ActionReceipt>[];
    return raw
        .map(_ActionReceipt.tryParse)
        .whereType<_ActionReceipt>()
        .toList();
  }

  static Map<String, dynamic>? _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static List<int> _linkIdsFromMap(Map<String, dynamic>? map) {
    if (map == null) return const [];
    final raw = map['linkIds'] ?? map['ids'];
    if (raw is! List) return const [];
    return raw
        .map((value) => value is num ? value.toInt() : int.tryParse('$value'))
        .whereType<int>()
        .toSet()
        .toList();
  }
}

class _ActionReceipt {
  const _ActionReceipt({
    required this.id,
    required this.actionId,
    required this.linkIds,
    this.notificationId,
    this.notificationType,
    this.logicalNotificationId,
  });

  factory _ActionReceipt.fromResponse(
    NotificationResponse response,
    String actionId,
  ) {
    final payload = NotificationActionHandler._decodePayload(response.payload);
    final logicalId = payload?['notifId']?.toString();
    final linkIds = NotificationActionHandler._linkIdsFromMap(payload);
    final legacyIdentity = [
      if (linkIds.isNotEmpty) linkIds.join('_') else 'none',
      if (payload?['firedAt'] != null) payload!['firedAt'],
    ].join(':');
    final stableNotificationId =
        response.id?.toString() ?? logicalId ?? legacyIdentity;
    return _ActionReceipt(
      id: '$actionId:$stableNotificationId',
      actionId: actionId,
      linkIds: linkIds,
      notificationId: response.id,
      notificationType: payload?['type']?.toString(),
      logicalNotificationId: logicalId,
    );
  }

  final String id;
  final String actionId;
  final List<int> linkIds;
  final int? notificationId;
  final String? notificationType;
  final String? logicalNotificationId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'actionId': actionId,
    'linkIds': linkIds,
    'notificationId': notificationId,
    'notificationType': notificationType,
    'logicalNotificationId': logicalNotificationId,
  };

  static _ActionReceipt? tryParse(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final map = Map<String, dynamic>.from(json);
      final id = map['id']?.toString();
      final actionId = map['actionId']?.toString();
      if (id == null || actionId == null) return null;
      return _ActionReceipt(
        id: id,
        actionId: actionId,
        linkIds: NotificationActionHandler._linkIdsFromMap(map),
        notificationId: map['notificationId'] is num
            ? (map['notificationId'] as num).toInt()
            : int.tryParse('${map['notificationId']}'),
        notificationType: map['notificationType']?.toString(),
        logicalNotificationId: map['logicalNotificationId']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}
