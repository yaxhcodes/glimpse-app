import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'core/services/digest_background.dart';

@pragma('vm:entry-point')
void digestCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'digestTask') {
      try {
        await DigestBackgroundTask.run();
      } catch (e, st) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('Digest task failed: $e\n$st');
        }
      }
    }
    return Future.value(true);
  });
}
