import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../database/isar_service.dart';
import '../models/engagement_event.dart';
import 'digest_prefs.dart';
import 'notif_bandit.dart';
import 'tag_analyzer.dart';

/// Parses notification JSON payloads and navigates to the detail screen or fallback.
class NotificationRouter {
  NotificationRouter._();

  /// Resolves [navigatorKey] across frames (cold start) then calls [openFromPayload].
  static void deliverPayload(
    GlobalKey<NavigatorState> navigatorKey,
    String? rawPayload,
  ) {
    var frames = 0;
    void step() {
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        openFromPayload(ctx, rawPayload);
        return;
      }
      if (frames++ >= 48) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => step());
    }

    step();
  }

  /// Resolve the scheduler letter (A–G, R) the bandit keys on, from either a
  /// fresh payload (`type` is the letter) or a hub history entry (`type` is the
  /// snake_case history type).
  static String? _rewardLetter(Map<String, dynamic> map) {
    final t = map['type'] as String?;
    if (t == null || t.isEmpty) return null;
    if (t.length == 1 && _letters.contains(t)) return t;
    return _historyTypeToLetter[t];
  }

  static const _letters = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'R'};
  static const _historyTypeToLetter = {
    'geo': 'A',
    'new_interest': 'B',
    'collector': 'C',
    'streak': 'D',
    'resurface': 'E',
    'digest': 'F',
    'revisit': 'G',
    'rediscover': 'R',
  };

  static List<int> _parseLinkIds(Map<String, dynamic> map) {
    final fromNew = map['linkIds'] as List<dynamic>?;
    if (fromNew != null) {
      return fromNew.map((e) => (e as num).toInt()).toList();
    }
    final legacy = map['ids'] as List<dynamic>?;
    if (legacy != null) {
      return legacy.map((e) => (e as num).toInt()).toList();
    }
    return [];
  }

  /// Open from tray tap, action button, or cold start. [rawPayload] is the plugin payload string.
  static void openFromPayload(BuildContext context, String? rawPayload) {
    if (rawPayload == null || rawPayload.isEmpty) {
      _openNotificationsHub(context);
      return;
    }
    try {
      final map = jsonDecode(rawPayload) as Map<String, dynamic>;
      _navigateWithMap(context, map);
    } catch (_) {
      _openNotificationsHub(context);
    }
  }

  /// Hub row tap: prefer full payload from prefs via [notifId], else inline [map] from history.
  static Future<void> openFromHub(
    BuildContext context, {
    String? notifId,
    Map<String, dynamic>? historyEntry,
  }) async {
    Map<String, dynamic>? map;
    if (notifId != null && notifId.isNotEmpty) {
      map = await DigestPrefs.loadNotifPayload(notifId);
    }
    if (!context.mounted) return;
    if (map == null || _parseLinkIds(map).isEmpty) {
      map = historyEntry;
    }
    if (map == null) {
      _openNotificationsHub(context);
      return;
    }
    _navigateWithMap(context, map);
  }

  static void _navigateWithMap(BuildContext context, Map<String, dynamic> map) {
    final ids = _parseLinkIds(map);
    final title = map['title'] as String? ?? 'Notification';

    // Reward signal for the on-device bandit: this type got opened.
    final letter = _rewardLetter(map);
    if (letter != null) {
      unawaited(NotifBandit.recordOpen(letter));
      // Mirror into the unified event log for the affinity model.
      unawaited(
        IsarService().logEvent(
          type: EngagementEventType.notifOpened,
          triggerType: letter,
        ),
      );
    }
    // Opening a notification is also an "active now" signal — feed the peak-hour
    // histogram so future notifications are timed to when the user engages.
    unawaited(TagAnalyzer.recordAppOpen());
    if (map['route'] == 'home') {
      context.go('/');
      return;
    }
    if (map['route'] == 'subscription') {
      context.push('/settings/subscription');
      return;
    }
    if (map['route'] == 'url_detail' && ids.length == 1) {
      context.push('/url/${ids.first}');
      return;
    }
    if (ids.isEmpty) {
      _openNotificationsHub(context);
      return;
    }
    context.push(
      '/notification_detail',
      extra: NotificationDetailExtra(
        title: title,
        linkIds: ids,
        insightLine: map['body'] as String?,
        historyType: historyTypeFromNotificationMap(map),
      ),
    );
  }

  static void _openNotificationsHub(BuildContext context) {
    context.go('/');
    context.push('/notifications');
  }
}

class NotificationDetailExtra {
  const NotificationDetailExtra({
    required this.title,
    required this.linkIds,
    this.insightLine,
    this.historyType,
  });

  final String title;
  final List<int> linkIds;

  /// Copy from the Gemini / template notification body when available.
  final String? insightLine;

  /// Hub history type (`digest`, `geo`, …) or inferred from scheduler letter.
  final String? historyType;
}

/// Maps scheduler letter (A-G, R) or persisted hub history [type] to a stable key.
String? historyTypeFromNotificationMap(Map<String, dynamic> map) {
  final t = map['type'] as String?;
  final fromLetter = historyTypeFromPayloadLetter(t);
  if (fromLetter != null) return fromLetter;
  const known = {
    'digest',
    'geo',
    'new_interest',
    'collector',
    'streak',
    'resurface',
    'revisit',
    'rediscover',
  };
  if (t != null && known.contains(t)) return t;
  return null;
}

/// Maps scheduler payload `type` (A-G, R) to hub history snake_case.
String? historyTypeFromPayloadLetter(String? letter) {
  switch (letter) {
    case 'A':
      return 'geo';
    case 'B':
      return 'new_interest';
    case 'C':
      return 'collector';
    case 'D':
      return 'streak';
    case 'E':
      return 'resurface';
    case 'F':
      return 'digest';
    case 'G':
      return 'revisit';
    case 'R':
      return 'rediscover';
    default:
      return null;
  }
}
