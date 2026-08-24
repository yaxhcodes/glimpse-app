import 'dart:async';

import 'package:workmanager/workmanager.dart';

/// Owns the single WorkManager initialization shared by every scheduler.
class BackgroundWorkManager {
  BackgroundWorkManager._();

  static Future<void>? _initialization;

  static Future<void> initialize(void Function() callbackDispatcher) {
    return _initialization ??= Workmanager().initialize(callbackDispatcher);
  }

  static Future<void> get ready {
    final initialization = _initialization;
    if (initialization == null) {
      return Future<void>.error(
        StateError('WorkManager has not been initialized.'),
      );
    }
    return initialization;
  }
}
