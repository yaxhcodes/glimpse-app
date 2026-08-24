import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';

enum AppShortcutAction {
  capture('capture'),
  search('search'),
  ask('ask'),
  rediscover('rediscover');

  const AppShortcutAction(this.platformValue);

  final String platformValue;

  static AppShortcutAction? fromPlatformValue(Object? value) {
    if (value is! String) return null;
    for (final action in values) {
      if (action.platformValue == value) return action;
    }
    return null;
  }
}

/// Delivers Android launcher shortcut actions for cold and warm app starts.
class AppShortcutService {
  AppShortcutService({
    MethodChannel channel = const MethodChannel(_channelName),
    bool? isAndroid,
  }) : _channel = channel,
       _isAndroid = isAndroid ?? Platform.isAndroid;

  static const _tag = 'AppShortcutService';
  static const _channelName = 'com.shinrinyoku.glimpse/app_shortcut';

  final MethodChannel _channel;
  final bool _isAndroid;
  final StreamController<AppShortcutAction> _controller =
      StreamController.broadcast();
  bool _started = false;

  Stream<AppShortcutAction> get incoming => _controller.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    if (!_isAndroid) return;

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onAppShortcut') return;
      _emit(call.arguments, launchType: 'warm');
    });

    try {
      final initial = await _channel.invokeMethod<Object?>(
        'getInitialAppShortcut',
      );
      _emit(initial, launchType: 'cold');
    } on PlatformException catch (error, stackTrace) {
      developer.log(
        'Could not read the initial app shortcut.',
        name: _tag,
        error: error,
        stackTrace: stackTrace,
      );
    } on MissingPluginException {
      // The native bridge is intentionally Android-only.
    }
  }

  void _emit(Object? value, {required String launchType}) {
    final action = AppShortcutAction.fromPlatformValue(value);
    if (action == null || _controller.isClosed) return;
    developer.log(
      'Received ${action.platformValue} shortcut ($launchType).',
      name: _tag,
    );
    _controller.add(action);
  }

  Future<void> dispose() async {
    if (_isAndroid && _started) {
      _channel.setMethodCallHandler(null);
    }
    await _controller.close();
  }
}
