import '../../features/glimpses/glimpse.dart';
import '../../features/glimpses/glimpse_copy.dart';
import '../../features/glimpses/glimpse_delivery.dart';
import '../../features/glimpses/glimpse_service.dart';
import '../../features/glimpses/glimpse_store.dart';
import '../../l10n/l10n.dart';
import '../../notifications/gemini_copywriter.dart' show NotifCopy;
import '../database/isar_service.dart';

/// Compatibility entry point for WorkManager and the diagnostics panel.
class NotificationScheduler {
  NotificationScheduler._();

  static const _kinds = {
    'R': GlimpseKind.connection,
    'E': GlimpseKind.idea,
    'F': GlimpseKind.weekly,
    'G': GlimpseKind.intention,
  };

  static String labelFor(String type) => switch (type) {
    'R' => 'Connections',
    'E' => 'Saved ideas',
    'F' => 'Weekly brief',
    'G' => 'Revisit reminders',
    _ => 'Retired notification type',
  };

  static Future<String> runScheduled(IsarService isar) =>
      GlimpseDelivery.run(isar);

  static Future<String> runSingle(IsarService isar, String type) =>
      _kinds.containsKey(type)
      ? GlimpseDelivery.run(isar, kind: _kinds[type])
      : Future.value('skipped: retired notification type');

  static Future<NotifCopy?> preview(IsarService isar, String type) async {
    final entries = await GlimpseService(isar).refresh();
    final candidate = entries
        .where(
          (s) => s.glimpse.kind == _kinds[type] && s.visibleAt(DateTime.now()),
        )
        .firstOrNull;
    if (candidate == null) return null;
    final l = await loadBackgroundLocalizations();
    final urls = {for (final u in await isar.getAllUrls()) u.id: u};
    return NotifCopy(
      title: glimpseTitle(candidate.glimpse, l, urls),
      body: await glimpseNotificationBody(candidate.glimpse, l, urls),
    );
  }

  static Future<List<NotifDiag>> diagnostics(IsarService isar) async {
    final service = GlimpseService(isar);
    final items = await service.refresh();
    final receipts = await service.store.load();
    final now = DateTime.now();
    return [
      for (final entry in _kinds.entries)
        NotifDiag(
          type: entry.key,
          label: labelFor(entry.key),
          eligible: items.any(
            (s) => s.glimpse.kind == entry.value && s.glimpse.canNotify,
          ),
          onCooldown: !items.any(
            (s) =>
                s.glimpse.kind == entry.value &&
                GlimpseDeliveryPolicy.canPost(s, receipts, now),
          ),
          detail:
              'Evidence, source cooldown, quiet hours and delivery budget apply.',
        ),
    ];
  }
}

class NotifDiag {
  const NotifDiag({
    required this.type,
    required this.label,
    required this.eligible,
    required this.onCooldown,
    required this.detail,
  });

  final String type;
  final String label;
  final bool eligible;
  final bool onCooldown;
  final String detail;
}
