import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/tag_analyzer.dart';
import '../goals/memory_goals_provider.dart';
import '../home/home_provider.dart';
import 'rediscover_provider.dart';

enum RediscoverJourneyKind {
  continueLearning,
  forgottenGems,
  neverOpened,
  onThisDay,
  becauseYouSaved,
  memoryGoal,
}

class RediscoverJourney {
  const RediscoverJourney({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
    required this.signal,
  });

  final RediscoverJourneyKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<RediscoveryItem> items;
  final double signal;
}

final rediscoverJourneysProvider =
    FutureProvider<List<RediscoverJourney>>((ref) async {
  final urls = await _liveRediscoverUrls(ref);
  if (urls.length < 3) return const [];

  final journeys = <RediscoverJourney>[];

  final goals = await ref.watch(memoryGoalsProvider.future);
  final liveIds = {for (final url in urls) url.id};
  final rankedGoals =
      goals.where((goal) => goal.urls.any((url) => liveIds.contains(url.id)))
          .toList()
        ..sort((a, b) => b.strength.compareTo(a.strength));
  for (final goal in rankedGoals.take(2)) {
    final items = goal.urls
        .where((url) => liveIds.contains(url.id))
        .take(8)
        .map(
          (url) => RediscoveryItem(
            url: url,
            reason: _goalReason(goal.status),
            timeAgo: _formatTimeAgo(url.savedAt),
          ),
        )
        .toList();
    if (items.length < 2) continue;
    journeys.add(
      RediscoverJourney(
        kind: RediscoverJourneyKind.memoryGoal,
        title: _journeyTitleForGoal(goal.name, goal.status),
        subtitle: '${items.length} saves worth reopening',
        icon: Icons.route_rounded,
        items: items,
        signal: 90 + goal.strength,
      ),
    );
  }

  final due = await ref.watch(revisitQueueProvider.future);
  if (due.isNotEmpty) {
    journeys.add(
      RediscoverJourney(
        kind: RediscoverJourneyKind.continueLearning,
        title: _continueTitle(due),
        subtitle: '${due.length} saved for later',
        icon: Icons.playlist_play_rounded,
        items: due.take(8).toList(),
        signal: 86,
      ),
    );
  }

  final topic = _dominantTopic(urls);
  final interestItems = (await ref.watch(interestShelfProvider.future))
      .items
      .take(8)
      .toList();
  if (interestItems.length >= 2) {
    journeys.add(
      RediscoverJourney(
        kind: RediscoverJourneyKind.becauseYouSaved,
        title: topic.isEmpty
            ? 'Your recent curiosity continues'
            : _topicJourneyTitle(topic),
        subtitle: '${interestItems.length} saves worth reopening',
        icon: Icons.auto_awesome_rounded,
        items: interestItems,
        signal: 74,
      ),
    );
  }

  final gems = await ref.watch(forgottenGemsProvider.future);
  if (gems.length >= 2) {
    journeys.add(
      RediscoverJourney(
        kind: RediscoverJourneyKind.forgottenGems,
        title: _hiddenGemTitle(gems),
        subtitle: '${gems.length} older saves worth reopening',
        icon: Icons.diamond_outlined,
        items: gems.take(8).toList(),
        signal: 68,
      ),
    );
  }

  final neverOpened = urls
      .where((url) => url.openedAt == null)
      .take(10)
      .map(
        (url) => RediscoveryItem(
          url: url,
          reason: 'Never opened',
          timeAgo: _formatTimeAgo(url.savedAt),
        ),
      )
      .toList();
  if (neverOpened.length >= 3) {
    journeys.add(
      RediscoverJourney(
        kind: RediscoverJourneyKind.neverOpened,
        title: _neverOpenedTitle(neverOpened),
        subtitle: '${neverOpened.length} unopened saves',
        icon: Icons.mark_email_unread_outlined,
        items: neverOpened,
        signal: 54,
      ),
    );
  }

  final anniversaries = await ref.watch(onThisDayProvider.future);
  if (anniversaries.length >= 2) {
    journeys.add(
      RediscoverJourney(
        kind: RediscoverJourneyKind.onThisDay,
        title: 'From another season',
        subtitle: '${anniversaries.length} saves from earlier cycles',
        icon: Icons.history_rounded,
        items: anniversaries.take(8).toList(),
        signal: 50,
      ),
    );
  }

  journeys.sort((a, b) => b.signal.compareTo(a.signal));
  return journeys.take(6).toList();
});

Future<List<SavedUrl>> _liveRediscoverUrls(Ref ref) async {
  ref.watch(
    urlStreamProvider.select(
      (async) => async.whenOrNull(data: (urls) => urls.length),
    ),
  );
  final isar = ref.read(isarServiceProvider);
  final all = await isar.getAllUrls();
  return all
      .where((url) => !url.isDone && url.rediscoverDismissedAt == null)
      .toList();
}

String _dominantTopic(List<SavedUrl> urls) {
  final tagCounts = <String, int>{};
  for (final url in urls.take(12)) {
    for (final tag in TagAnalyzer.notificationTopicTags(url.tags)) {
      tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
    }
  }
  if (tagCounts.isEmpty) return '';
  final sorted = tagCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final top = sorted.first;
  return top.value >= 2 ? top.key : '';
}

String _continueTitle(List<RediscoveryItem> items) {
  final first = items.firstOrNull?.url;
  if (first == null) return 'Continue where you left off';
  final topic = TagAnalyzer.notificationTopicTags(first.tags).firstOrNull;
  if (topic != null) return _topicJourneyTitle(topic);
  return 'Continue where you left off';
}

String _journeyTitleForGoal(String goal, String status) {
  final clean = goal.trim();
  if (clean.isEmpty) return 'Worth another look';
  final lower = clean.toLowerCase();
  if (_containsAny(lower, const ['trek', 'hike', 'camp', 'trail'])) {
    return 'Planning another trek?';
  }
  if (_containsAny(lower, const ['cook', 'recipe', 'food', 'meal'])) {
    return 'Still perfecting your recipes?';
  }
  if (_containsAny(lower, const ['wildlife', 'nature', 'forest'])) {
    return 'Nature called again';
  }
  if (_containsAny(lower, const ['philosophy', 'stoicism', 'gita'])) {
    return 'Philosophy worth revisiting';
  }
  if (_containsAny(lower, const ['ai', 'agent', 'llm', 'openai', 'claude'])) {
    return 'Continue Building';
  }
  if (_containsAny(lower, const ['startup', 'business', 'founder'])) {
    return 'Back to building?';
  }
  if (_containsAny(lower, const ['photo', 'camera', 'visual'])) {
    return 'Capture something new';
  }
  if (_containsAny(lower, const ['book', 'reading', 'literature'])) {
    return 'Worth another chapter';
  }
  return switch (status) {
    'dormant' => 'Worth another look',
    'cooling' => 'Back to this',
    'active' => 'Keep going',
    _ => 'Worth another look',
  };
}

String _topicJourneyTitle(String topic) {
  final lower = topic.toLowerCase();
  if (_containsAny(lower, const ['trek', 'hike', 'camp', 'trail'])) {
    return 'Planning another trek?';
  }
  if (_containsAny(lower, const ['ai', 'agent', 'llm', 'openai', 'claude'])) {
    return 'Continue Building';
  }
  if (_containsAny(lower, const ['wildlife', 'nature', 'forest'])) {
    return 'Nature called again';
  }
  if (_containsAny(lower, const ['cook', 'recipe', 'food', 'meal'])) {
    return 'Still perfecting your recipes?';
  }
  if (_containsAny(lower, const ['philosophy', 'stoicism', 'gita'])) {
    return 'Time to reflect';
  }
  if (_containsAny(lower, const ['startup', 'business', 'founder'])) {
    return 'Back to building?';
  }
  if (_containsAny(lower, const ['photo', 'camera', 'visual'])) {
    return 'Capture something new';
  }
  if (_containsAny(lower, const ['book', 'reading', 'literature'])) {
    return 'Worth another chapter';
  }
  if (_containsAny(lower, const ['history', 'ancient', 'museum'])) {
    return 'Rediscover forgotten worlds';
  }
  return 'Worth returning to ${_titleCase(topic)}';
}

String _hiddenGemTitle(List<RediscoveryItem> items) {
  final text = _itemsText(items);
  if (_containsAny(text, const ['code', 'software', 'ai', 'agent'])) {
    return 'Build notes you almost forgot';
  }
  if (_containsAny(text, const ['travel', 'trek', 'hike', 'mountain'])) {
    return 'Routes worth reopening';
  }
  if (_containsAny(text, const ['recipe', 'cook', 'food'])) {
    return 'Recipes hiding in your saves';
  }
  if (_containsAny(text, const ['book', 'read', 'philosophy'])) {
    return 'Ideas worth another pass';
  }
  return 'Hidden gems worth another look';
}

String _neverOpenedTitle(List<RediscoveryItem> items) {
  final text = _itemsText(items);
  if (_containsAny(text, const ['book', 'read', 'essay'])) {
    return 'Worth opening tonight';
  }
  if (_containsAny(text, const ['video', 'youtube', 'watch'])) {
    return 'Things you meant to watch';
  }
  if (_containsAny(text, const ['recipe', 'cook', 'food'])) {
    return 'Recipes still waiting';
  }
  return 'Start with what you never opened';
}

String _itemsText(List<RediscoveryItem> items) {
  return [
    for (final item in items.take(8)) ...[
      item.url.title,
      item.url.category,
      ...item.url.tags,
      ...item.url.effectiveCategories,
    ],
  ].join(' ').toLowerCase();
}

bool _containsAny(String text, List<String> needles) {
  for (final needle in needles) {
    if (text.contains(needle)) return true;
  }
  return false;
}

String _goalReason(String status) {
  return switch (status) {
    'dormant' => 'Worth reopening',
    'cooling' => 'Worth revisiting',
    'queued' => 'Saved for later',
    'active' => 'Still relevant',
    _ => 'Related save',
  };
}

String _formatTimeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}

String _titleCase(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return clean;
  return clean
      .split(RegExp(r'\s+'))
      .map((part) {
        if (part.length <= 3) return part.toUpperCase();
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .join(' ');
}
