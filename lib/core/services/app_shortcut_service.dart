import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';

enum AppShortcutAction {
  capture('capture'),
  search('search'),
  ask('ask'),
  rediscover('rediscover'),

  /// Not a launcher shortcut: the share sheet's way into the Vault.
  vault('vault'),

  /// Not a launcher shortcut: a save tapped on the Rediscover home screen
  /// widget. Always arrives with its id (see [AppShortcutRequest]).
  openSave('save');

  const AppShortcutAction(this.platformValue);

  final String platformValue;

  static AppShortcutAction? fromPlatformValue(Object? value) {
    if (value is! String) return null;
    for (final action in values) {
      if (action == openSave) continue;
      if (action.platformValue == value) return action;
    }
    return null;
  }
}

/// A shortcut as it reaches the app, with the save it names when it came
/// from the Rediscover widget (`save:<id>` on the wire).
class AppShortcutRequest {
  const AppShortcutRequest(this.action, {this.saveId});

  final AppShortcutAction action;
  final int? saveId;

  static const _savePrefix = 'save:';

  static AppShortcutRequest? fromPlatformValue(Object? value) {
    if (value is String && value.startsWith(_savePrefix)) {
      final id = int.tryParse(value.substring(_savePrefix.length));
      if (id == null || id <= 0) return null;
      return AppShortcutRequest(AppShortcutAction.openSave, saveId: id);
    }
    final action = AppShortcutAction.fromPlatformValue(value);
    return action == null ? null : AppShortcutRequest(action);
  }
}

/// Delivers Android launcher shortcut and widget taps for cold and warm
/// app starts.
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
  final StreamController<AppShortcutRequest> _controller =
      StreamController.broadcast();
  bool _started = false;

  Stream<AppShortcutRequest> get incoming => _controller.stream;

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
    final request = AppShortcutRequest.fromPlatformValue(value);
    if (request == null || _controller.isClosed) return;
    developer.log(
      'Received ${request.action.platformValue} shortcut ($launchType).',
      name: _tag,
    );
    _controller.add(request);
  }

  Future<void> dispose() async {
    if (_isAndroid && _started) {
      _channel.setMethodCallHandler(null);
    }
    await _controller.close();
  }
}
