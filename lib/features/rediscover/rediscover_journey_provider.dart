import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/affinity_profile.dart';
import '../../core/services/tag_analyzer.dart';
import '../../core/services/title_resolver.dart';
import '../home/home_provider.dart';
import '../mindmap/cluster_theme.dart';
import '../mindmap/interest_clusters_provider.dart';
import 'rediscover_provider.dart';

enum RediscoverJourneyKind {
  continueLearning,
  forgottenGems,
  neverOpened,
  onThisDay,
  becauseYouSaved,
  memoryGoal,
}

enum RediscoverTodaySlotType {
  continueFromHere,
  stillWaiting,
  forgottenGem,
  connectedSaves,
}

class RediscoverTodaySlot {
  const RediscoverTodaySlot({
    required this.type,
    required this.label,
    required this.subtitle,
    required this.icon,
    this.item,
    this.journey,
  });

  final RediscoverTodaySlotType type;
  final String label;
  final String subtitle;
  final IconData icon;
  final RediscoveryItem? item;
  final RediscoverJourney? journey;
}

class RediscoverJourney {
  const RediscoverJourney({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
    required this.signal,
    this.categoryLabel,
    this.hookLine,
    this.narrative,
    this.recommendedFirstSaveId,
    this.topicAnchor,
  });

  final RediscoverJourneyKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<RediscoveryItem> items;
  final double signal;
  final String? categoryLabel;
  final String? hookLine;
  final String? narrative;
  final int? recommendedFirstSaveId;

  /// The dominant content topic this journey is about. Drives the visual
  /// eyebrow/motif so the title and eyebrow always agree (the title text may be
  /// a varied phrase that doesn't literally contain the topic). Null for
  /// non-topic journeys (e.g. on-this-day).
  final String? topicAnchor;
}

final rediscoverJourneysProvider = FutureProvider<List<RediscoverJourney>>((
  ref,
) async {
  final urls = await _liveRediscoverUrls(ref);
  if (urls.length < 3) return const [];

  final profile = await ref.watch(affinityProfileProvider.future);
  final clusters = await ref.watch(interestClusterThemesProvider.future);
  final relatedItems = (await ref.watch(
    relatedSavesProvider.future,
  )).items.take(8).toList();
  final anniversaries = (await ref.watch(
    onThisDayProvider.future,
  )).take(8).toList();

  return buildRediscoverJourneys(
    liveUrls: urls,
    clusters: clusters,
    profile: profile,
    interestFallbackItems: relatedItems,
    anniversaryItems: anniversaries,
  );
});

final rediscoverTodayProvider = FutureProvider<List<RediscoverTodaySlot>>((
  ref,
) async {
  final journeys = await ref.watch(rediscoverJourneysProvider.future);
  final todaysPicks = await ref.watch(todaysPicksProvider.future);
  final revisitQueue = await ref.watch(revisitQueueProvider.future);
  final forgottenGems = await ref.watch(forgottenGemsProvider.future);

  final slots = <RediscoverTodaySlot>[];
  final usedSaveIds = <int>{};
  final usedJourneyIds = <String>{};

  RediscoveryItem? firstUnused(Iterable<RediscoveryItem> items) {
    for (final item in items) {
      if (usedSaveIds.add(item.url.id)) return item;
    }
    return null;
  }

  final continueItem = firstUnused(
    revisitQueue.followedBy(
      todaysPicks.where(
        (item) => item.url.isQueued || item.url.openedAt != null,
      ),
    ),
  );
  if (continueItem != null) {
    slots.add(
      RediscoverTodaySlot(
        type: RediscoverTodaySlotType.continueFromHere,
        label: 'Continue from here',
        subtitle: TitleResolver.resolveDetailTitle(continueItem.url),
        icon: Icons.play_circle_outline_rounded,
        item: continueItem,
      ),
    );
  }

  final stillWaiting = firstUnused(
    todaysPicks.where((item) {
      final age = DateTime.now().difference(item.url.savedAt).inDays;
      return item.url.openedAt == null && age >= 3 && age <= 21;
    }),
  );
  if (stillWaiting != null) {
    slots.add(
      RediscoverTodaySlot(
        type: RediscoverTodaySlotType.stillWaiting,
        label: 'Still waiting',
        subtitle: TitleResolver.resolveDetailTitle(stillWaiting.url),
        icon: Icons.hourglass_empty_rounded,
        item: stillWaiting,
      ),
    );
  }

  final gem = firstUnused(forgottenGems);
  if (gem != null) {
    slots.add(
      RediscoverTodaySlot(
        type: RediscoverTodaySlotType.forgottenGem,
        label: 'Forgotten gem',
        subtitle: TitleResolver.resolveDetailTitle(gem.url),
        icon: Icons.diamond_outlined,
        item: gem,
      ),
    );
  }

  for (final journey in journeys) {
    final key = journey.topicAnchor ?? journey.title;
    if (!usedJourneyIds.add(key)) continue;
    if (journey.items.any((item) => usedSaveIds.contains(item.url.id))) {
      continue;
    }
    slots.add(
      RediscoverTodaySlot(
        type: RediscoverTodaySlotType.connectedSaves,
        label: 'Connected saves',
        subtitle: journey.hookLine ?? journey.subtitle,
        icon: Icons.hub_outlined,
        journey: journey,
      ),
    );
    break;
  }

  return slots.take(4).toList();
});

/// Shared Rediscover journey engine used by Home, Rediscover, and notifications.
///
/// Candidate collection can differ by runtime context (Riverpod foreground vs.
/// WorkManager background), but grouping, framing, ranking, and deduplication
/// stay here so notification selection does not grow a separate recommender.
List<RediscoverJourney> buildRediscoverJourneys({
  required List<SavedUrl> liveUrls,
  required List<ClusterTheme> clusters,
  required AffinityProfile profile,
  List<RediscoveryItem> interestFallbackItems = const [],
  List<RediscoveryItem> anniversaryItems = const [],
}) {
  if (liveUrls.length < 3) return const [];

  final liveIds = {for (final url in liveUrls) url.id};

  // One coherent pipeline: every topic journey comes from the embedding
  // clusters that power the Interests map (on-theme cores), framed by member
  // state. Explicitly queued saves are folded in — they boost their cluster's
  // rank and lead its items — instead of getting a competing card. The old
  // keyword memory-goals, forgotten-gems, and never-opened grab-bag generators
  // are retired; coherence now comes from a single grouping source.
  final journeys = _clusterJourneys(
    _consolidateClusterThemes(clusters),
    liveIds,
    profile,
  );

  // Thin-library fallback: if clusters have not formed yet, show one
  // recency/neglect shelf so new users aren't left empty.
  if (journeys.isEmpty) {
    final items = interestFallbackItems.take(8).toList();
    if (items.length >= 2) {
      final topic = _dominantTopic(items.map((item) => item.url).toList());
      journeys.add(
        RediscoverJourney(
          kind: RediscoverJourneyKind.becauseYouSaved,
          title: topic.isEmpty
              ? 'Recent Saves Worth Reopening'
              : _framedTitle(RediscoverJourneyKind.becauseYouSaved, topic),
          subtitle: '${items.length} saves worth reopening',
          icon: Icons.auto_awesome_rounded,
          items: items,
          signal: 74,
          topicAnchor: topic.isEmpty ? null : topic,
        ),
      );
    }
  }

  if (anniversaryItems.length >= 2) {
    journeys.add(
      RediscoverJourney(
        kind: RediscoverJourneyKind.onThisDay,
        title: 'From another season',
        subtitle: '${anniversaryItems.length} saves from earlier cycles',
        icon: Icons.history_rounded,
        items: anniversaryItems.take(8).toList(),
        signal: 50,
      ),
    );
  }

  journeys.sort((a, b) => b.signal.compareTo(a.signal));
  return _generateJourneyNarratives(_dedupeJourneys(journeys)).take(6).toList();
}

/// Removes redundant journeys, keeping the highest-signal one. The consolidation
/// pass handles true embedding duplicates first; this later pass drops title
/// collisions and overlapping save sets that can still appear from fallback
/// shelves.
List<RediscoverJourney> _dedupeJourneys(List<RediscoverJourney> journeys) {
  final kept = <RediscoverJourney>[];
  final seenTitleFamilies = <String>{};
  for (final j in journeys) {
    final titleKey = _titleFamilyKey(j.title);
    if (seenTitleFamilies.contains(titleKey)) continue;
    final ids = j.items.map((i) => i.url.id).toSet();
    final overlapsKept =
        ids.isNotEmpty &&
        kept.any((k) {
          final kIds = k.items.map((i) => i.url.id).toSet();
          return ids.intersection(kIds).length / ids.length >= 0.5;
        });
    if (overlapsKept) continue;
    seenTitleFamilies.add(titleKey);
    kept.add(j);
  }
  return kept;
}

List<ClusterTheme> _consolidateClusterThemes(List<ClusterTheme> clusters) {
  const mergeSimilarityThreshold = 0.85;
  final merged = <ClusterTheme>[];
  final consumed = <int>{};

  for (var i = 0; i < clusters.length; i += 1) {
    if (consumed.contains(i)) continue;
    var current = clusters[i];
    var currentCentroid = _clusterCentroid(current.urls);

    for (var j = i + 1; j < clusters.length; j += 1) {
      if (consumed.contains(j)) continue;
      final next = clusters[j];
      final similarity = _cosineSimilarity(
        currentCentroid,
        _clusterCentroid(next.urls),
      );
      if (similarity < mergeSimilarityThreshold) continue;
      final urlsById = <int, SavedUrl>{
        for (final url in current.urls) url.id: url,
        for (final url in next.urls) url.id: url,
      };
      current = ClusterTheme(
        index: current.index,
        label: current.label,
        summary: current.summary,
        urls: urlsById.values.toList(),
        subClusters: [...current.subClusters, ...next.subClusters],
      );
      currentCentroid = _clusterCentroid(current.urls);
      consumed.add(j);
    }
    merged.add(current);
  }

  return merged;
}

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

/// Builds coherent journeys from the strongest interest clusters, so every save
/// in a journey is genuinely about the same thing. Prefers clusters with the
/// most unopened members (most worth resurfacing); within a journey, unopened
/// and oldest saves come first.
/// The single Rediscover pipeline: one journey per coherent interest cluster,
/// framed by member state (Continue / Forgotten gem / Still waiting), with
/// explicitly-queued saves boosting rank and leading the items. Title and
/// eyebrow both derive from the cluster's on-theme core, so they always agree.
List<RediscoverJourney> _clusterJourneys(
  List<ClusterTheme> clusters,
  Set<int> liveIds,
  AffinityProfile profile, {
  int maxJourneys = 5,
}) {
  final now = DateTime.now();
  final scored = <(double, RediscoverJourney)>[];

  for (final cluster in clusters) {
    final members = cluster.urls
        .where((u) => liveIds.contains(u.id) && u.isProcessingReady)
        .toList();
    if (members.length < 3) continue;

    // Restrict to the cluster's on-theme core so outliers the clusterer lumped
    // into the tail (e.g. a film save inside a food cluster) don't show up.
    final core = _onThemeCore(members);
    if (core.length < 3) continue;

    final unopened = core.where((u) => u.openedAt == null).length;
    if (unopened == 0) continue; // nothing worth resurfacing

    // Order: explicitly-queued first, then unopened, then oldest.
    final picked =
        ([...core]..sort((a, b) {
              final aq = a.isQueued ? 0 : 1;
              final bq = b.isQueued ? 0 : 1;
              if (aq != bq) return aq - bq;
              final ao = a.openedAt == null ? 0 : 1;
              final bo = b.openedAt == null ? 0 : 1;
              if (ao != bo) return ao - bo;
              return a.savedAt.compareTo(b.savedAt);
            }))
            .take(8)
            .toList();
    if (picked.length < 2) continue;

    final framing = _framingFor(core, now);
    final hasQueued = core.any((u) => u.isQueued);
    final topic = _journeyTopic(picked, cluster.label);
    final title = _framedTitle(framing, topic);

    // Score: framing base × neglect × recency, plus an explicit-intent boost.
    final neglect = 0.5 + unopened / core.length; // 0.5–1.5
    final freshestDays = now
        .difference(
          core.map((u) => u.savedAt).reduce((a, b) => a.isAfter(b) ? a : b),
        )
        .inDays;
    final recency = freshestDays <= 7 ? 1.2 : (freshestDays <= 30 ? 1.0 : 0.85);
    // Behavioral affinity (1.0 = neutral while cold) nudges clusters the user
    // actually engages with up, and ones they ignore/dismiss down.
    final affinity =
        (profile.clusterMultiplier(cluster.label) +
            profile.categoryMultiplier(topic.isEmpty ? null : topic)) /
        2;
    final score =
        _framingBase(framing) * neglect * recency * affinity +
        (hasQueued ? 15.0 : 0.0);

    scored.add((
      score,
      RediscoverJourney(
        kind: framing,
        title: title,
        subtitle: _framingSubtitle(framing, picked.length, hasQueued),
        icon: _framingIcon(framing),
        items: picked
            .map(
              (u) => RediscoveryItem(
                url: u,
                reason: _itemReason(u),
                timeAgo: _formatTimeAgo(u.savedAt),
              ),
            )
            .toList(),
        signal: score,
        topicAnchor: topic,
      ),
    ));
  }

  scored.sort((a, b) => b.$1.compareTo(a.$1));
  return scored.take(maxJourneys).map((e) => e.$2).toList();
}

/// Picks a framing for a cluster from its members' state.
RediscoverJourneyKind _framingFor(List<SavedUrl> core, DateTime now) {
  final recentBurst = core
      .where((u) => now.difference(u.savedAt).inHours <= 48)
      .length;
  if (recentBurst >= 2) return RediscoverJourneyKind.continueLearning;
  final hasOldGem = core.any(
    (u) => u.openedAt == null && now.difference(u.savedAt).inDays >= 21,
  );
  if (hasOldGem) return RediscoverJourneyKind.forgottenGems;
  return RediscoverJourneyKind.becauseYouSaved;
}

double _framingBase(RediscoverJourneyKind framing) => switch (framing) {
  RediscoverJourneyKind.continueLearning => 84.0,
  RediscoverJourneyKind.forgottenGems => 64.0,
  _ => 74.0,
};

IconData _framingIcon(RediscoverJourneyKind framing) => switch (framing) {
  RediscoverJourneyKind.continueLearning => Icons.playlist_play_rounded,
  RediscoverJourneyKind.forgottenGems => Icons.diamond_outlined,
  _ => Icons.auto_awesome_rounded,
};

String _framingSubtitle(RediscoverJourneyKind framing, int n, bool hasQueued) {
  if (hasQueued) return '$n saves, including ones you queued';
  return switch (framing) {
    RediscoverJourneyKind.continueLearning => '$n saves you recently added to',
    RediscoverJourneyKind.forgottenGems => '$n saves you set aside a while ago',
    _ => '$n saves worth reopening',
  };
}

String _itemReason(SavedUrl u) {
  if (u.isQueued) return 'You saved this to revisit';
  if (u.openedAt == null) return 'Unopened';
  return 'Worth revisiting';
}

/// Keeps the cluster members closest to the cluster centroid and drops the
/// outlier tail, so a heterogeneous cluster surfaces only its coherent core.
/// Falls back to all members when too few have embeddings to be reliable.
List<SavedUrl> _onThemeCore(List<SavedUrl> members) {
  final withEmbedding = members
      .where((u) => u.embedding != null && u.embedding!.isNotEmpty)
      .toList();
  if (withEmbedding.length < 5) return List<SavedUrl>.from(members);

  final dim = withEmbedding.first.embedding!.length;
  final centroid = List<double>.filled(dim, 0.0);
  var counted = 0;
  for (final u in withEmbedding) {
    final e = u.embedding!;
    if (e.length != dim) continue;
    for (var i = 0; i < dim; i++) {
      centroid[i] += e[i];
    }
    counted++;
  }
  if (counted == 0) return List<SavedUrl>.from(members);
  for (var i = 0; i < dim; i++) {
    centroid[i] /= counted;
  }

  double cosineToCentroid(SavedUrl u) {
    final e = u.embedding;
    if (e == null || e.length != dim) return -1;
    var dot = 0.0, na = 0.0, nb = 0.0;
    for (var i = 0; i < dim; i++) {
      dot += e[i] * centroid[i];
      na += e[i] * e[i];
      nb += centroid[i] * centroid[i];
    }
    if (na == 0 || nb == 0) return -1;
    return dot / (math.sqrt(na) * math.sqrt(nb));
  }

  final scored = [
    for (final u in withEmbedding) (url: u, similarity: cosineToCentroid(u)),
  ]..sort((a, b) => b.similarity.compareTo(a.similarity));
  final valid = scored.where((entry) => entry.similarity >= 0).toList();
  if (valid.length < 5) return List<SavedUrl>.from(members);

  final mean =
      valid.map((entry) => entry.similarity).reduce((a, b) => a + b) /
      valid.length;
  final variance =
      valid
          .map((entry) {
            final delta = entry.similarity - mean;
            return delta * delta;
          })
          .reduce((a, b) => a + b) /
      valid.length;
  final stdDev = math.sqrt(variance);

  if (stdDev < 0.035) {
    return valid.map((entry) => entry.url).toList();
  }

  final threshold = mean - stdDev * 0.45;
  var core = valid.where((entry) => entry.similarity >= threshold).toList();
  final minKeep = math.min(4, valid.length);
  if (core.length < minKeep) {
    core = valid.take(minKeep).toList();
  }
  final maxKeep = math.max(minKeep, (valid.length * 0.85).ceil());
  if (core.length > maxKeep) {
    core = core.take(maxKeep).toList();
  }
  return core.map((entry) => entry.url).toList();
}

/// The dominant content topic for a journey's title/eyebrow, falling back to
/// the cluster label when the saves have no clear shared tag.
String _journeyTopic(List<SavedUrl> picked, String fallbackLabel) {
  final topic = _dominantTopic(picked);
  return topic.isEmpty ? fallbackLabel : topic;
}

List<RediscoverJourney> _generateJourneyNarratives(
  List<RediscoverJourney> journeys,
) {
  final usedTitles = <String>{};
  final out = <RediscoverJourney>[];

  for (final journey in journeys) {
    final narrative = _narrativeFor(journey);
    var title = narrative.title;
    final titleKey = _titleFamilyKey(title);
    if (usedTitles.contains(titleKey)) {
      title = _disambiguatedTitle(title, journey, usedTitles);
    }
    usedTitles.add(_titleFamilyKey(title));
    out.add(
      RediscoverJourney(
        kind: journey.kind,
        title: title,
        subtitle: journey.subtitle,
        icon: journey.icon,
        items: journey.items,
        signal: journey.signal,
        categoryLabel: narrative.categoryLabel,
        hookLine: narrative.hookLine,
        narrative: narrative.narrative,
        recommendedFirstSaveId: narrative.recommendedFirstSaveId,
        topicAnchor: journey.topicAnchor,
      ),
    );
  }

  return out;
}

({
  String title,
  String categoryLabel,
  String hookLine,
  String narrative,
  int? recommendedFirstSaveId,
})
_narrativeFor(RediscoverJourney journey) {
  final urls = journey.items.map((item) => item.url).toList();
  final recommended = _recommendedFirstSave(urls);
  final categoryLabel = _categoryLabelFor(journey);
  final topic = _bestTopicForNarrative(journey, urls);
  final title = _narrativeTitleFor(topic, urls);
  final contentNoun = _contentNounFor(urls);
  final hookLine = _withoutRepeatedTitle(
    _hookLineFor(title, topic, contentNoun, journey),
    recommended?.title,
  );
  final narrative = _withoutRepeatedTitle(
    _detailNarrativeFor(title, topic, contentNoun, urls),
    recommended?.title,
  );

  return (
    title: title,
    categoryLabel: categoryLabel,
    hookLine: hookLine,
    narrative: narrative,
    recommendedFirstSaveId: recommended?.id,
  );
}

SavedUrl? _recommendedFirstSave(List<SavedUrl> urls) {
  if (urls.isEmpty) return null;
  final sorted = [...urls]
    ..sort((a, b) {
      final aq = a.isQueued ? 0 : 1;
      final bq = b.isQueued ? 0 : 1;
      if (aq != bq) return aq - bq;
      final ao = a.openedAt == null ? 0 : 1;
      final bo = b.openedAt == null ? 0 : 1;
      if (ao != bo) return ao - bo;
      return a.savedAt.compareTo(b.savedAt);
    });
  return sorted.first;
}

String _categoryLabelFor(RediscoverJourney journey) {
  final anchor = journey.topicAnchor?.trim();
  if (anchor != null && anchor.isNotEmpty) return _titleCase(anchor);
  final categories = <String, int>{};
  for (final item in journey.items) {
    final category = item.url.category.trim();
    if (category.isEmpty || category == 'Other' || category == 'Web') continue;
    categories[category] = (categories[category] ?? 0) + 1;
  }
  if (categories.isEmpty) return 'Worth a Look';
  final ranked = categories.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return _titleCase(ranked.first.key);
}

String _bestTopicForNarrative(RediscoverJourney journey, List<SavedUrl> urls) {
  final tagCounts = <String, int>{};
  for (final url in urls) {
    for (final tag in TagAnalyzer.notificationTopicTags(url.tags)) {
      tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
    }
  }
  final ranked = tagCounts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return b.key.length.compareTo(a.key.length);
    });
  if (ranked.isNotEmpty && ranked.first.value >= 2) {
    return _titleCase(ranked.first.key);
  }
  final anchor = journey.topicAnchor?.trim();
  if (anchor != null && anchor.isNotEmpty) return _titleCase(anchor);
  return _titleCase(journey.title);
}

String _narrativeTitleFor(String topic, List<SavedUrl> urls) {
  final text = _combinedJourneyText(urls).toLowerCase();
  if (_containsAny(text, const ['free will', 'determinism', 'agency'])) {
    return 'Free Will';
  }
  if (_containsAny(text, const ['non-dual', 'non dual', 'advaita'])) {
    return 'Non-Dual Philosophy';
  }
  if (_containsAny(text, const ['ai consciousness', 'machine consciousness'])) {
    return 'AI & Consciousness';
  }
  if (_containsAny(text, const ['consciousness'])) {
    final hasAi = _containsAny(text, const ['ai', 'llm', 'machine']);
    return hasAi ? 'AI & Consciousness' : 'Consciousness Questions';
  }
  if (_containsAny(text, const ['argument', 'rhetoric', 'debate', 'fallacy'])) {
    return 'Rhetoric & Debate';
  }
  if (_containsAny(text, const ['book', 'reading list', 'novel'])) {
    return topic.toLowerCase().contains('book') ? topic : '$topic Reading';
  }
  return _trimTitle(topic);
}

String _contentNounFor(List<SavedUrl> urls) {
  final text = _combinedJourneyText(urls).toLowerCase();
  final hasRecipeEvidence = _containsAny(text, const [
    'ingredient',
    'ingredients',
    'cook ',
    'cooking',
    'bake',
    'recipe',
    'dish',
    'meal',
  ]);
  if (hasRecipeEvidence) return urls.length == 1 ? 'recipe' : 'recipes';
  if (_containsAny(text, const ['book', 'reading list', 'novel'])) {
    return urls.length == 1 ? 'reading pick' : 'reading picks';
  }
  if (_containsAny(text, const ['movie', 'film', 'series', 'anime'])) {
    return urls.length == 1 ? 'watch pick' : 'watch picks';
  }
  if (_containsAny(text, const ['repo', 'github', 'api', 'flutter', 'code'])) {
    return urls.length == 1 ? 'technical save' : 'technical saves';
  }
  if (_containsAny(text, const ['instagram', 'reel', 'video'])) {
    return urls.length == 1 ? 'reel' : 'reels';
  }
  return urls.length == 1 ? 'save' : 'saves';
}

String _hookLineFor(
  String title,
  String topic,
  String contentNoun,
  RediscoverJourney journey,
) {
  final count = journey.items.length;
  final waiting = journey.items
      .where((item) => item.url.openedAt == null)
      .length;
  final prefix = switch (journey.kind) {
    RediscoverJourneyKind.continueLearning => 'Keep going with',
    RediscoverJourneyKind.forgottenGems => 'Reopen',
    RediscoverJourneyKind.neverOpened => 'Start with',
    RediscoverJourneyKind.onThisDay => 'Return to',
    RediscoverJourneyKind.memoryGoal => 'Use',
    RediscoverJourneyKind.becauseYouSaved => 'Pick up',
  };
  if (waiting == count) return '$count unopened $contentNoun on $topic.';
  return '$prefix $title through $count connected $contentNoun.';
}

String _detailNarrativeFor(
  String title,
  String topic,
  String contentNoun,
  List<SavedUrl> urls,
) {
  final examples = urls
      .take(3)
      .map(
        (url) => url.summary?.trim().isNotEmpty == true
            ? url.summary!.trim()
            : url.title.trim(),
      )
      .where((item) => item.isNotEmpty)
      .toList();
  final sample = examples.isEmpty ? '' : ' ${examples.join(' ')}';
  return 'These $contentNoun circle around $topic without collapsing into a generic pile.$sample'
      .trim();
}

String _withoutRepeatedTitle(String text, String? title) {
  final cleanTitle = title?.trim();
  if (cleanTitle == null || cleanTitle.isEmpty) return text;
  final repeated = RegExp(
    r'\b(Try|Start with|Open|Recheck)\s+([^:]{3,80}):\s+\2\b',
    caseSensitive: false,
  );
  final escaped = RegExp.escape(cleanTitle);
  var seen = false;
  return text
      .replaceAllMapped(
        repeated,
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .replaceAllMapped(RegExp(escaped, caseSensitive: false), (match) {
        if (seen) return 'this save';
        seen = true;
        return match.group(0)!;
      });
}

String _disambiguatedTitle(
  String title,
  RediscoverJourney journey,
  Set<String> usedTitles,
) {
  final candidates = <String>[
    if ((journey.topicAnchor ?? '').trim().isNotEmpty)
      '${_titleCase(journey.topicAnchor!)} ${_trimTitle(title)}',
    '${_categoryLabelFor(journey)} ${_trimTitle(title)}',
    '${_trimTitle(title)} ${journey.items.length}',
  ];
  for (final candidate in candidates) {
    final trimmed = _trimTitle(candidate);
    if (!usedTitles.contains(_titleFamilyKey(trimmed))) return trimmed;
  }
  return '${_trimTitle(title)} Again';
}

String _combinedJourneyText(List<SavedUrl> urls) {
  return [
    for (final url in urls.take(8)) ...[
      url.title,
      url.description,
      url.summary ?? '',
      url.category,
      url.categories.join(' '),
      url.tags.join(' '),
    ],
  ].join(' ');
}

String _trimTitle(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.length <= 5) return words.join(' ');
  return words.take(5).join(' ');
}

String _titleFamilyKey(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where(
        (word) =>
            word.isNotEmpty &&
            !(const {
              'understanding',
              'your',
              'saved',
              'saves',
              'notes',
            }).contains(word),
      )
      .join(' ');
}

List<double> _clusterCentroid(List<SavedUrl> urls) {
  final withEmbedding = urls
      .where((url) => url.embedding != null && url.embedding!.isNotEmpty)
      .toList();
  if (withEmbedding.isEmpty) return const [];
  final dim = withEmbedding.first.embedding!.length;
  final centroid = List<double>.filled(dim, 0);
  var count = 0;
  for (final url in withEmbedding) {
    final embedding = url.embedding!;
    if (embedding.length != dim) continue;
    count += 1;
    for (var i = 0; i < dim; i += 1) {
      centroid[i] += embedding[i];
    }
  }
  if (count == 0) return const [];
  for (var i = 0; i < dim; i += 1) {
    centroid[i] /= count;
  }
  return centroid;
}

double _cosineSimilarity(List<double> a, List<double> b) {
  if (a.isEmpty || b.isEmpty || a.length != b.length) return 0;
  var dot = 0.0;
  var normA = 0.0;
  var normB = 0.0;
  for (var i = 0; i < a.length; i += 1) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA == 0 || normB == 0) return 0;
  return dot / (math.sqrt(normA) * math.sqrt(normB));
}

/// A hand-tuned phrase for a well-known topic, or null to use a framed default.
/// These phrases needn't contain the topic word — the eyebrow follows
/// [RediscoverJourney.topicAnchor], not the title text.
String? _specialTopicTitle(String topic) {
  final lower = topic.toLowerCase();
  if (_containsAny(lower, const ['trek', 'hike', 'camp', 'trail'])) {
    return 'Planning another trek?';
  }
  if (_containsAny(lower, const ['ai', 'agent', 'llm', 'openai', 'claude'])) {
    return 'Continue building';
  }
  if (_containsAny(lower, const ['wildlife', 'forest'])) {
    return 'Nature called again';
  }
  if (_containsAny(lower, const ['cook', 'recipe', 'food', 'meal'])) {
    return 'Still perfecting your recipes?';
  }
  if (_containsAny(lower, const ['philosophy', 'stoicism', 'gita'])) {
    return 'Time to reflect';
  }
  if (_containsAny(lower, const ['startup', 'founder'])) {
    return 'Back to building?';
  }
  if (_containsAny(lower, const ['photo', 'camera'])) {
    return 'Capture something new';
  }
  if (_containsAny(lower, const ['history', 'ancient', 'museum'])) {
    return 'Rediscover forgotten worlds';
  }
  return null;
}

/// A title for a cluster journey: a hand-tuned phrase when one fits, else a
/// framing-aware, non-repetitive default (so every card isn't "Worth returning
/// to X").
String _framedTitle(RediscoverJourneyKind framing, String topic) {
  final special = _specialTopicTitle(topic);
  if (special != null) return special;
  final t = _titleCase(topic);
  switch (framing) {
    case RediscoverJourneyKind.continueLearning:
      return 'Keep going on $t';
    case RediscoverJourneyKind.forgottenGems:
      return 'You set $t aside';
    default:
      const openers = [
        'Worth returning to ',
        'Back into ',
        'More on ',
        'Revisit ',
      ];
      return '${openers[topic.hashCode.abs() % openers.length]}$t';
  }
}

bool _containsAny(String text, List<String> needles) {
  for (final needle in needles) {
    if (text.contains(needle)) return true;
  }
  return false;
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
