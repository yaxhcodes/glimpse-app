import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';

/// Bridges the native `com.shinrinyoku.glimpse/backup_intent` MethodChannel
/// (see `MainActivity.kt`) into a single Stream of incoming backup file
/// paths.
///
/// Emits:
/// - The path queued by the launching `ACTION_VIEW` intent (if any) once
///   [start] is called for the first time after app launch.
/// - Subsequent paths sent from native via `onBackupFile` whenever the user
///   opens another backup file while the app is already running.
///
/// All paths are absolute filesystem paths to a copy in the app's cache
/// directory — so callers can read them straight with `dart:io.File`.
class BackupIntentService {
  static const _tag = 'BackupIntentService';
  static const _channelName = 'com.shinrinyoku.glimpse/backup_intent';

  final MethodChannel _channel = const MethodChannel(_channelName);
  final StreamController<String> _controller = StreamController.broadcast();
  bool _started = false;

  /// Emits absolute paths to incoming backup files, in arrival order.
  Stream<String> get incoming => _controller.stream;

  /// Begin listening to native pushes and pull the initial intent (if any).
  /// Safe to call multiple times — only the first call has effect.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    if (!Platform.isAndroid) {
      // No iOS implementation yet. The method channel simply won't be
      // wired, so we silently no-op rather than throw.
      return;
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onBackupFile') {
        final path = call.arguments as String?;
        if (path != null && path.isNotEmpty) {
          developer.log('Received backup file (warm): $path', name: _tag);
          _controller.add(path);
        }
      }
    });

    try {
      final initial = await _channel.invokeMethod<String?>(
        'getInitialBackupFile',
      );
      if (initial != null && initial.isNotEmpty) {
        developer.log('Received backup file (cold): $initial', name: _tag);
        _controller.add(initial);
      }
    } on PlatformException catch (e) {
      developer.log('getInitialBackupFile failed: $e', name: _tag);
    } on MissingPluginException {
      // Channel not wired (e.g. running on a platform we haven't built for).
    }
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
