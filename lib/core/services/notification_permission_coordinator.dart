import 'package:flutter/services.dart';
import 'digest_notifications.dart';

enum NotificationPermissionResult { enabled, declined, settings }

/// Permission policy shared by explicit notification and revisit actions.
class NotificationPermissionCoordinator {
  NotificationPermissionCoordinator({
    Future<bool> Function()? enabled,
    Future<bool> Function()? requestable,
    Future<bool?> Function()? request,
    Future<void> Function()? markRequested,
  }) : _enabled = enabled ?? DigestNotifications.areNotificationsEnabled,
       _requestable =
           requestable ??
           (() async =>
               await channel.invokeMethod<bool>(
                 'notificationPermissionRequestable',
               ) ??
               false),
       _request = request ?? DigestNotifications.requestPermission,
       _markRequested =
           markRequested ??
           (() =>
               channel.invokeMethod<void>('notificationPermissionRequested'));

  static const channel = MethodChannel('com.shinrinyoku.glimpse/app_task');
  final Future<bool> Function() _enabled;
  final Future<bool> Function() _requestable;
  final Future<bool?> Function() _request;
  final Future<void> Function() _markRequested;

  Future<NotificationPermissionResult> enable({
    required Future<bool> Function() explain,
  }) async {
    if (await _enabled()) return NotificationPermissionResult.enabled;
    if (!await explain()) return NotificationPermissionResult.declined;
    if (!await _requestable()) return NotificationPermissionResult.settings;
    final granted = await _request();
    if (granted != null) await _markRequested();
    return granted == true
        ? NotificationPermissionResult.enabled
        : NotificationPermissionResult.declined;
  }
}
