import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../rediscover/rediscover_daily_set.dart';
import '../rediscover/rediscover_memory.dart';
import 'glimpse_copy.dart';
import 'glimpse_journey.dart';
import 'glimpse_service.dart';

/// Keeps Home's established artwork cards while using the shared selection.
final glimpseHomeSetProvider = FutureProvider<RediscoverDailySet>((ref) async {
  ref.watch(effectiveAppLocaleProvider);
  final entries = await ref.watch(glimpsesProvider.future);
  final urls = await ref.watch(glimpseSourcesProvider.future);
  final l = await loadBackgroundLocalizations();
  final now = DateTime.now();
  final memories = GlimpseService.current(entries, now).map((entry) {
    final g = entry.glimpse;
    final title = glimpseTitle(g, l, urls);
    final label = glimpseLabel(g.kind, l);
    final body = glimpseBody(g, l);
    final journey = glimpseJourney(g, l, urls);
    final base = RediscoverMemory.fromJourney(journey);
    final copy = RediscoverMemoryCopy(
      title: title,
      subtitle: base.homeCopy.subtitle,
      body: body,
      actionLabel: label,
    );
    return RediscoverMemory(
      journey: journey,
      id: g.key,
      topicKey: g.topicKey,
      topicLabel: g.topicLabel,
      what: body,
      whyItMatters: body,
      whyNow: label,
      emotion: base.emotion,
      personality: base.personality,
      semanticIntent: base.semanticIntent,
      copyIdentity: base.copyIdentity,
      encouragedAction: label,
      homeCopy: copy,
      rediscoverCopy: copy,
      notificationCopy: RediscoverNotificationCopy(title: title, body: body),
      metadata: base.metadata,
      primaryUrl: base.primaryUrl,
      primaryTitle: base.primaryTitle,
      supportingUrls: base.supportingUrls,
      saveCount: base.saveCount,
      unopenedCount: base.unopenedCount,
    );
  }).toList();
  return RediscoverDailySet(
    localDate: DateTime(now.year, now.month, now.day),
    memories: memories,
    generatedAt: now,
  );
});
