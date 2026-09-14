import 'dart:developer' as developer;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/notification_permission_coordinator.dart';
import '../../core/services/digest_notifications.dart';
import '../../l10n/l10n.dart';

bool _requestingNotifications = false;

Future<bool> enableNotificationsInContext(
  BuildContext context,
  WidgetRef ref,
) async {
  if (_requestingNotifications) return false;
  _requestingNotifications = true;
  try {
    final l = context.l10n;
    final result = await NotificationPermissionCoordinator().enable(
      explain: () async {
        if (!context.mounted) return false;
        return await showDialog<bool>(
              context: context,
              builder: (dialog) => AlertDialog(
                title: Text(l.obNotifyTitle),
                content: Text(l.obNotifyBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: Text(l.obNotNow),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: Text(l.obNotifyEnable),
                  ),
                ],
              ),
            ) ??
            false;
      },
    );
    if (!context.mounted) return false;
    var enabled = result == NotificationPermissionResult.enabled;
    if (result == NotificationPermissionResult.settings) {
      final open = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(l.obNotifyEnable),
          content: Text(l.obAlertsOff),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(l.obNotNow),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(l.obOpenSettings),
            ),
          ],
        ),
      );
      if (open == true) {
        enabled = await _openSettingsAndRefresh();
      }
    }
    if (!context.mounted) return false;
    unawaited(
      _trackOutcome(
        ref
            .read(analyticsServiceProvider)
            .trackEvent(
              enabled
                  ? AnalyticsEvent.notificationPermissionEnabled
                  : AnalyticsEvent.notificationPermissionDeclined,
            ),
      ),
    );
    if (!enabled && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.obAlertsOff),
          action: SnackBarAction(
            label: l.obOpenSettings,
            onPressed: () async {
              try {
                await _openSettingsAndRefresh();
              } catch (error, stackTrace) {
                developer.log(
                  'Could not open notification settings',
                  error: error,
                  stackTrace: stackTrace,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l.obPermissionError)));
                }
              }
            },
          ),
        ),
      );
    }
    return enabled;
  } catch (error, stackTrace) {
    developer.log(
      'Could not enable notifications',
      name: 'NotificationPermission',
      error: error,
      stackTrace: stackTrace,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.obPermissionError)));
    }
    return false;
  } finally {
    _requestingNotifications = false;
  }
}

Future<void> _trackOutcome(Future<void> operation) async {
  try {
    await operation;
  } catch (error, stackTrace) {
    developer.log(
      'Could not track notification preference',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

Future<bool> _openSettingsAndRefresh() async {
  final resumed = Completer<void>();
  final listener = AppLifecycleListener(
    onResume: () {
      if (!resumed.isCompleted) resumed.complete();
    },
  );
  try {
    await NotificationPermissionCoordinator.channel.invokeMethod<void>(
      'openNotificationSettings',
    );
    await resumed.future.timeout(const Duration(minutes: 5), onTimeout: () {});
    return await DigestNotifications.areNotificationsEnabled();
  } finally {
    listener.dispose();
  }
}
