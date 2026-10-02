import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether the app is running on one of Google's test robots.
///
/// Every upload to a Play testing track is crawled by the pre-launch report
/// on about ten Firebase Test Lab phones, each signed into a Google
/// account, and the crawler taps "Sign in with Google". That made ~96 of
/// 108 accounts robots (`firstnamelastname.12345@gmail.com`). On those
/// devices the app still runs normally so the report stays useful, but it
/// marks the account as a test device, sends no analytics and makes no
/// paid AI calls.
abstract final class TestLab {
  static const _channel = MethodChannel('com.shinrinyoku.glimpse/app_task');
  static Future<bool>? _running;

  static Future<bool> isRunning() => _running ??= _detect();

  static Future<bool> _detect() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isTestLab') ?? false;
    } on MissingPluginException {
      // Background isolates have no activity channel; they never sign in.
      return false;
    } on PlatformException {
      return false;
    }
  }

  @visibleForTesting
  static void debugSetRunning(bool? running) {
    _running = running == null ? null : Future.value(running);
  }
}
