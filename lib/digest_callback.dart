import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'core/database/isar_service.dart';
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
        await DigestScheduler.scheduleNext();
      } catch (e) {
        await DigestPrefs.saveLastRunStatus('error: $e');
        try {
          await DigestScheduler.scheduleNext();
        } catch (_) {}
      }
    }
    return Future.value(true);
  });
}

/// Handle notification action buttons pressed in foreground or background.
Future<void> notificationActionCallback(String? action, String? payload) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (action == null || payload == null) return;

  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;

    final isar = IsarService();
    await isar.ensureInitialized();

    if (action == 'mark_read') {
      final linkIds = (data['linkIds'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList();
      final legacyIds = (data['ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList();
      final ids = (linkIds != null && linkIds.isNotEmpty) ? linkIds : legacyIds;
      if (ids != null && ids.isNotEmpty) {
        for (final id in ids) {
          await isar.updateOpenedAt(id, DateTime.now());
        }
        return;
      }

      final category = data['category'] as String?;
      if (category != null) {
        await isar.markCategoryRead(category);
      }
    }
  } catch (_) {}
}
