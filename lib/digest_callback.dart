import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'core/services/backup_background_task.dart';
import 'core/services/backup_scheduler.dart';
import 'core/services/digest_background.dart';
import 'core/services/digest_prefs.dart';
import 'core/services/digest_scheduler.dart';
import 'core/services/url_enrichment_job.dart';
import 'core/services/url_enrichment_worker.dart';

@pragma('vm:entry-point')
void digestCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (task == DigestScheduler.taskName) {
      try {
        await DigestBackgroundTask.run(fromWorkManager: true);
        await DigestScheduler.scheduleNext();
      } catch (e) {
        await DigestPrefs.saveLastRunStatus('error: $e');
        try {
          await DigestScheduler.scheduleNext();
        } catch (_) {}
      }
      return true;
    }
    if (task == BackupScheduler.taskName) {
      return BackupBackgroundTask.run();
    }
    if (task == UrlEnrichmentScheduler.taskName) {
      final job = UrlEnrichmentJob.fromInputData(inputData);
      if (job == null) return true;
      return UrlEnrichmentWorker.run(job);
    }
    return true;
  });
}
