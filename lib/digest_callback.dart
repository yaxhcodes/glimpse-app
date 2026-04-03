import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'core/services/digest_background.dart';
import 'core/services/digest_prefs.dart';
import 'core/services/digest_scheduler.dart';

@pragma('vm:entry-point')
void digestCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (task == DigestScheduler.taskName) {
      try {
        await DigestBackgroundTask.run();
        // Chain the next one-off task for next week.
        await DigestScheduler.scheduleNextWeek();
      } catch (e) {
        await DigestPrefs.saveLastRunStatus('error: $e');
        // Still schedule next week so one failure doesn't kill the chain.
        try {
          await DigestScheduler.scheduleNextWeek();
        } catch (_) {}
      }
    }
    return Future.value(true);
  });
}
