import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/isar_service.dart';
import '../../core/models/engagement_event.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/rediscover_utility_profile.dart';
import '../../core/services/digest_notifications.dart';
import '../../core/services/digest_prefs.dart';
import '../home/home_provider.dart';
import '../rediscover/rediscover_memory_prefs.dart';
import 'glimpse.dart';
import 'glimpse_engine.dart';
import 'glimpse_store.dart';

class GlimpseService {
  GlimpseService(this.isar) : store = GlimpseStore(isar);
  final IsarService isar;
  final GlimpseStore store;
  Future<List<StoredGlimpse>>? _pending;
  bool _refreshAgain = false;

  Future<List<StoredGlimpse>> refresh() {
    if (_pending != null) {
      _refreshAgain = true;
      return _pending!;
    }
    return _pending = _refreshUntilCurrent().whenComplete(
      () => _pending = null,
    );
  }

  Future<List<StoredGlimpse>> _refreshUntilCurrent() async {
    late List<StoredGlimpse> result;
    do {
      _refreshAgain = false;
      result = await _refresh();
    } while (_refreshAgain);
    return result;
  }

  Future<List<StoredGlimpse>> _refresh() async {
    final now = DateTime.now();
    final urls = await isar.getAllUrls();
    final byId = {for (final url in urls) url.id: url};
    final events = await isar.recentEvents();
    final candidates = await compute(
      buildGlimpses,
      GlimpseBuildRequest(urls, events, now),
    );
    await store.reconcile(candidates, now);
    await store.removeSources(urls.map((u) => u.id).toSet());
    final currentKeys = candidates.map((g) => g.key).toSet();
    final records = await store.load();
    final utility = await RediscoverUtilityProfileStore.load();
    final visible = <StoredGlimpse>[];
    for (final item in records) {
      final g = item.glimpse;
      if (!currentKeys.contains(g.key) &&
          !g.isRecap &&
          item.record.retiredAt == null &&
          item.record.postedAt == null &&
          item.record.openedAt == null &&
          item.record.snoozedUntil == null) {
        continue;
      }
      if ((!currentKeys.contains(g.key) && g.isReminder) ||
          (!g.isRecap &&
              g.sourceIds.any((id) {
                final u = byId[id];
                return u == null ||
                    u.isDone ||
                    (u.isQueued && !g.isReminder) ||
                    u.rediscoverDismissedAt != null;
              }))) {
        await store.mutate(g.key, (r) => r.retiredAt ??= now);
        item.record.retiredAt ??= now;
      }
      if (!g.isRecap &&
          await RediscoverMemoryPrefs.isTopicSuppressed(g.topicKey, now: now)) {
        continue;
      }
      if (!g.isRecap &&
          await RediscoverMemoryPrefs.isMemorySnoozed(g.key, now: now)) {
        continue;
      }
      visible.add(item);
    }
    double rank(StoredGlimpse s) =>
        s.glimpse.score *
        (utility.topics[s.glimpse.topicKey]?.utilityMultiplier(now: now) ?? 1);
    visible.sort((a, b) {
      if (a.glimpse.isReminder != b.glimpse.isReminder) {
        return a.glimpse.isReminder ? -1 : 1;
      }
      final score = rank(b).compareTo(rank(a));
      return score != 0
          ? score
          : b.glimpse.createdAt.compareTo(a.glimpse.createdAt);
    });
    return visible;
  }

  Future<void> act(
    Glimpse glimpse,
    GlimpseAction action, {
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final current = (await store.load())
        .where((s) => s.glimpse.key == glimpse.key)
        .firstOrNull;
    if (current == null) return;
    if (action == GlimpseAction.opened && current.record.openedAt != null) {
      return;
    }
    if ((action == GlimpseAction.gotIt || action == GlimpseAction.done) &&
        current.record.retiredAt != null) {
      return;
    }
    final until = now.add(const Duration(days: 3));
    if (action == GlimpseAction.later && current.record.snoozedUntil == until) {
      return;
    }
    if (action == GlimpseAction.done &&
        glimpse.isReminder &&
        glimpse.sourceIds.length == 1) {
      await isar.updateIntent(
        glimpse.sourceIds.single,
        status: 'done',
        action: 'glimpse_done',
        awaitEngagement: true,
      );
    }
    if (action == GlimpseAction.later &&
        glimpse.isReminder &&
        glimpse.sourceIds.length == 1) {
      await isar.updateIntent(
        glimpse.sourceIds.single,
        status: 'queued',
        action: 'snoozed',
        revisitAfter: until,
        awaitEngagement: true,
      );
    }
    await store.mutate(glimpse.key, (record) {
      switch (action) {
        case GlimpseAction.opened:
          record.openedAt ??= now;
        case GlimpseAction.later:
          record.snoozedUntil = until;
        case GlimpseAction.gotIt ||
            GlimpseAction.done ||
            GlimpseAction.lessLikeThis:
          record.retiredAt ??= now;
      }
    });
    if (current.record.postedAt != null ||
        current.record.reminderPostedAt != null) {
      try {
        await DigestNotifications.cancel(
          glimpseNotificationId(current.record.id),
        );
      } on PlatformException catch (error, stack) {
        developer.log(
          'Unable to remove Glimpse from the tray',
          name: 'GlimpseService',
          error: error,
          stackTrace: stack,
        );
      }
      for (final entry in await DigestPrefs.loadHistory()) {
        if (entry['notifId'] == glimpse.key) {
          await DigestPrefs.markDigestRead(entry['id'] as String);
        }
      }
    }
    if (action == GlimpseAction.later) {
      await RediscoverMemoryPrefs.snoozeMemory(glimpse.key, until: until);
    } else if (action == GlimpseAction.lessLikeThis) {
      await RediscoverMemoryPrefs.suppressTopic(glimpse.topicKey);
    }
    final url = await isar.getUrlById(glimpse.sourceIds.first);
    await isar.logEvent(
      type: switch (action) {
        GlimpseAction.opened => EngagementEventType.clusterVisit,
        GlimpseAction.done => EngagementEventType.rediscoverCompleted,
        GlimpseAction.later => EngagementEventType.cardSnoozed,
        GlimpseAction.lessLikeThis => EngagementEventType.cardDismissed,
        GlimpseAction.gotIt => EngagementEventType.intentSet,
      },
      url: url,
      memoryId: glimpse.key,
      topicKey: glimpse.topicKey,
      surface: 'glimpses',
      algorithmVersion: 'glimpses-v1',
    );
  }

  Future<void> openKey(String key) async {
    final item = (await store.load())
        .where((s) => s.glimpse.key == key)
        .firstOrNull;
    if (item == null) return;
    await act(item.glimpse, GlimpseAction.opened);
    final url = await isar.getUrlById(item.glimpse.sourceIds.first);
    if (url != null) {
      await isar.logEvent(
        type: EngagementEventType.cardOpened,
        url: url,
        memoryId: key,
        topicKey: item.glimpse.topicKey,
        surface: 'glimpses',
        algorithmVersion: 'glimpses-v1',
      );
    }
  }

  static List<StoredGlimpse> current(List<StoredGlimpse> all, DateTime now) {
    final topics = <String>{};
    final sources = <int>{};
    return all
        .where((s) {
          final g = s.glimpse;
          if (g.isRecap ||
              (g.kind == GlimpseKind.connection && !g.strong) ||
              !s.visibleAt(now) ||
              (!g.expiresAt.isAfter(now) &&
                  !GlimpseDeliveryPolicy.isRequestedReturn(s, now)) ||
              (g.isReminder && g.availableAt.isAfter(now)) ||
              topics.contains(g.topicKey) ||
              g.sourceIds.any(sources.contains)) {
            return false;
          }
          topics.add(g.topicKey);
          sources.addAll(g.sourceIds);
          return true;
        })
        .take(3)
        .toList();
  }
}

final glimpseServiceProvider = Provider(
  (ref) => GlimpseService(ref.read(isarServiceProvider)),
);
final glimpsesProvider = FutureProvider<List<StoredGlimpse>>((ref) async {
  // Content changes at a stable save count matter (enrichment, notes, intent).
  ref.watch(urlStreamProvider);
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day + 1);
  final timer = Timer(midnight.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.read(glimpseServiceProvider).refresh();
});

final glimpseSourcesProvider = FutureProvider<Map<int, SavedUrl>>((ref) async {
  ref.watch(urlStreamProvider);
  return {
    for (final u in await ref.read(isarServiceProvider).getAllUrls()) u.id: u,
  };
});
