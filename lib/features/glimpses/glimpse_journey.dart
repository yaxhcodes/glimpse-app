import '../../core/models/saved_url.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import '../rediscover/rediscover_journey_provider.dart';
import '../rediscover/rediscover_provider.dart';
import 'glimpse.dart';
import 'glimpse_copy.dart';

RediscoverJourney glimpseJourney(
  Glimpse g,
  AppLocalizations l,
  Map<int, SavedUrl> urls,
) {
  final title = glimpseTitle(g, l, urls);
  final label = glimpseLabel(g.kind, l);
  final body = glimpseBody(g, l);
  return RediscoverJourney(
    kind: g.kind == GlimpseKind.connection
        ? RediscoverJourneyKind.returningTopic
        : g.isReminder
        ? RediscoverJourneyKind.continueLearning
        : RediscoverJourneyKind.forgottenGems,
    title: title,
    subtitle: body,
    icon: AppIcons.rediscover,
    items: g.sourceIds
        .where(urls.containsKey)
        .map(
          (id) => RediscoveryItem(url: urls[id]!, reason: label, timeAgo: ''),
        )
        .toList(),
    signal: g.score,
    topicAnchor: g.topicLabel,
    stableTopicKey: g.topicKey,
    triggerSaveId: g.kind == GlimpseKind.connection ? g.sourceIds.first : null,
    topicPulseConfidence: g.strong ? 'strong' : 'supported',
  );
}
