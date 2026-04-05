import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'digest_prefs.dart';

/// Parses notification JSON payloads and navigates to the detail screen or fallback.
class NotificationRouter {
  NotificationRouter._();

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
      context.go('/notifications');
      return;
    }
    try {
      final map = jsonDecode(rawPayload) as Map<String, dynamic>;
      _navigateWithMap(context, map);
    } catch (_) {
      context.go('/notifications');
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
      context.go('/');
      return;
    }
    _navigateWithMap(context, map);
  }

  static void _navigateWithMap(BuildContext context, Map<String, dynamic> map) {
    final ids = _parseLinkIds(map);
    final title = map['title'] as String? ?? 'Notification';
    if (ids.isEmpty) {
      context.go('/');
      return;
    }
    context.push(
      '/notification_detail',
      extra: NotificationDetailExtra(title: title, linkIds: ids),
    );
  }
}

class NotificationDetailExtra {
  const NotificationDetailExtra({
    required this.title,
    required this.linkIds,
  });

  final String title;
  final List<int> linkIds;
}
