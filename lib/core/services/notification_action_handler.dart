import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../database/isar_service.dart';

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

  /// Returns true when [response] was an action this handler consumed (so the
  /// caller should NOT also route/open the app). Tapping the body (no actionId,
  /// or an unknown id) returns false.
  static Future<bool> handleIfAction(NotificationResponse response) async {
    final actionId = response.actionId;
    if (actionId != NotificationActions.markDone &&
        actionId != NotificationActions.snooze) {
      return false;
    }

    final ids = _linkIdsFromPayload(response.payload);
    if (ids.isEmpty) return true; // consumed, but nothing to act on

    // Background isolates need the binding before touching isar_flutter_libs.
    WidgetsFlutterBinding.ensureInitialized();
    final isar = IsarService();
    await isar.ensureInitialized();

    for (final id in ids) {
      if (actionId == NotificationActions.markDone) {
        await isar.updateIntent(id, status: 'done', action: 'notif_done');
      } else {
        // Snooze: (re)queue and push the revisit window out. Works whether the
        // save was already queued (type G) or just resurfaced unread (type E).
        await isar.updateIntent(
          id,
          status: 'queued',
          action: 'snoozed',
          revisitAfter: DateTime.now().add(NotificationActions.snoozeWindow),
        );
      }
    }
    return true;
  }

  static List<int> _linkIdsFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return const [];
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final raw = (map['linkIds'] ?? map['ids']) as List<dynamic>?;
      if (raw == null) return const [];
      return raw.map((e) => (e as num).toInt()).toList();
    } catch (_) {
      return const [];
    }
  }
}
