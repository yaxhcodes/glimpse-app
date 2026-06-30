import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/affinity_profile.dart';
import '../../core/services/tag_analyzer.dart';
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

class RediscoverJourney {
  const RediscoverJourney({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
    required this.signal,
    this.topicAnchor,
  });

  final RediscoverJourneyKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<RediscoveryItem> items;
  final double signal;

  /// The dominant content topic this journey is about. Drives the visual
  /// eyebrow/motif so the title and eyebrow always agree (the title text may be
  /// a varied phrase that doesn't literally contain the topic). Null for
  /// non-topic journeys (e.g. on-this-day).
  final String? topicAnchor;
}

final rediscoverJourneysProvider =
    FutureProvider<List<RediscoverJourney>>((ref) async {
  final urls = await _liveRediscoverUrls(ref);
  if (urls.length < 3) return const [];

  final profile = await ref.watch(affinityProfileProvider.future);
  final clusters = await ref.watch(interestClusterThemesProvider.future);
  final interestItems =
      (await ref.watch(interestShelfProvider.future)).items.take(8).toList();
  final anniversaries =
      (await ref.watch(onThisDayProvider.future)).take(8).toList();

  return buildRediscoverJourneys(
    liveUrls: urls,
    clusters: clusters,
    profile: profile,
    interestFallbackItems: interestItems,
    anniversaryItems: anniversaries,
  );
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
  final journeys = _clusterJourneys(clusters, liveIds, profile);

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
              ? 'Your recent curiosity continues'
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
  return _dedupeJourneys(journeys).take(6).toList();
}

/// Removes redundant journeys, keeping the highest-signal one. Two independent
/// generators (memory goals + interest clusters) can both surface the same
/// topic — e.g. a "cook" goal and a food cluster both titled "Still perfecting
/// your recipes?" — so drop later journeys that repeat a title or mostly repeat
/// the saves of one already kept.
List<RediscoverJourney> _dedupeJourneys(List<RediscoverJourney> journeys) {
  final kept = <RediscoverJourney>[];
  final seenTitles = <String>{};
  for (final j in journeys) {
    final titleKey = j.title.trim().toLowerCase();
    if (seenTitles.contains(titleKey)) continue;
    final ids = j.items.map((i) => i.url.id).toSet();
    final overlapsKept = ids.isNotEmpty &&
        kept.any((k) {
          final kIds = k.items.map((i) => i.url.id).toSet();
          return ids.intersection(kIds).length / ids.length >= 0.5;
        });
    if (overlapsKept) continue;
    seenTitles.add(titleKey);
    kept.add(j);
  }
  return kept;
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
    final picked = ([...core]..sort((a, b) {
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
    final affinity = (profile.clusterMultiplier(cluster.label) +
            profile.categoryMultiplier(topic.isEmpty ? null : topic)) /
        2;
    final score = _framingBase(framing) * neglect * recency * affinity +
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
  final recentBurst =
      core.where((u) => now.difference(u.savedAt).inHours <= 48).length;
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
    RediscoverJourneyKind.continueLearning => "$n saves — you're on a thread",
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
    for (final u in withEmbedding)
      (url: u, similarity: cosineToCentroid(u)),
  ]..sort((a, b) => b.similarity.compareTo(a.similarity));
  final valid = scored.where((entry) => entry.similarity >= 0).toList();
  if (valid.length < 5) return List<SavedUrl>.from(members);

  final mean =
      valid.map((entry) => entry.similarity).reduce((a, b) => a + b) /
          valid.length;
  final variance = valid
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
