import 'dart:convert';

import '../../core/database/isar_service.dart';
import '../../core/models/engagement_event.dart';
import '../../core/services/digest_notifications.dart';
import '../../core/services/digest_prefs.dart';
import '../../l10n/l10n.dart';
import 'glimpse.dart';
import 'glimpse_copy.dart';
import 'glimpse_service.dart';
import 'glimpse_store.dart';
import 'glimpse_synthesis.dart';

class GlimpseDelivery {
  static Future<String> run(IsarService isar, {GlimpseKind? kind}) async {
    final service = GlimpseService(isar);
    final items = await service.refresh();
    if (!await DigestNotifications.areNotificationsEnabled()) {
      return 'skipped: permission disabled';
    }
    final now = DateTime.now();
    final receipts = await service.store.load();
    final strings = await loadBackgroundLocalizations();
    final urls = {for (final u in await isar.getAllUrls()) u.id: u};
    final weeklyDue =
        now.weekday == DateTime.sunday &&
        items.any(
          (s) =>
              s.glimpse.kind == GlimpseKind.weekly &&
              s.glimpse.hasValue &&
              s.glimpse.expiresAt.isAfter(now) &&
              s.visibleAt(now) &&
              s.record.openedAt == null &&
              s.record.postedAt == null,
        );
    for (final item in items) {
      if (kind != null && item.glimpse.kind != kind) continue;
      if (!GlimpseDeliveryPolicy.canPost(item, receipts, now)) continue;
      final g = item.glimpse;
      final requested = GlimpseDeliveryPolicy.isRequestedReturn(item, now);
      if (weeklyDue &&
          !g.isReminder &&
          !requested &&
          g.kind != GlimpseKind.weekly) {
        continue;
      }
      if (!await service.store.claim(g.key, now)) continue;
      var posted = false;
      try {
        final title = glimpseTitle(g, strings, urls);
        final body =
            GlimpseSynthesis.cached(
              item,
              appLocaleTag(await loadEffectiveAppLocale()),
            ).firstOrNull?.text ??
            await glimpseNotificationBody(g, strings, urls);
        posted = await DigestNotifications.show(
          type: g.isReminder ? NotifType.revisitDue : NotifType.resurface,
          title: title,
          body: body,
          isGlimpse: true,
          withActions: g.isReminder,
          informationActions: !g.isReminder && !g.isRecap,
          notificationId: notificationId(item.record.id),
          persistInHistory: true,
          historyType: 'glimpse',
          historySignature: g.key,
          payloadJson: jsonEncode({
            'type': 'glimpse',
            'route': 'glimpse',
            'glimpseKey': g.key,
            'linkIds': g.sourceIds,
            'title': title,
            'body': body,
            'notifId': g.key,
            'firedAt': now.toIso8601String(),
          }),
        );
        if (posted) {
          await service.store.mutate(g.key, (r) {
            if (requested) {
              r.reminderPostedAt = now;
            } else {
              r.postedAt ??= now;
            }
          });
          await isar.logEvent(
            type: EngagementEventType.notifShown,
            memoryId: g.key,
            topicKey: g.topicKey,
            triggerType: g.kind.name,
            surface: 'notification',
            algorithmVersion: 'glimpses-v1',
          );
          final letter = switch (g.kind) {
            GlimpseKind.connection => 'R',
            GlimpseKind.weekly => 'F',
            GlimpseKind.intention => 'G',
            _ => 'E',
          };
          await DigestPrefs.recordFired();
          await DigestPrefs.setLastFiredType(letter);
          await DigestPrefs.setLastFired(letter);
        }
      } finally {
        await service.store.mutate(g.key, (r) => r.deliveryLeaseUntil = null);
      }
      return posted ? 'glimpse: ${g.key}' : 'skipped: publication failed';
    }
    return 'skipped: no useful glimpse due';
  }

  static int notificationId(int recordId) => glimpseNotificationId(recordId);
}
