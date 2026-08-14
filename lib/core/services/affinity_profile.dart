import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/engagement_event.dart';
import '../providers/service_providers.dart';
import '../../features/home/home_provider.dart';

/// On-device behavioral profile folded from the engagement event log. Ranks
/// Rediscover and (later) notifications by what the user actually acts on.
///
/// All maps are 0..1 with 0.5 ≈ neutral. Multipliers return 1.0 while the
/// profile is cold or a key is unknown, so the behavioral layer never makes a
/// thin profile worse. See docs/behavioral-signal-engine-spec.md.
class AffinityProfile {
  const AffinityProfile({
    required this.category,
    required this.cluster,
    required this.source,
    required this.openByHour,
    required this.triggerResponsiveness,
    required this.engagementLevel,
    required this.weightedEventCount,
  });

  final Map<String, double> category;
  final Map<String, double> cluster;
  final Map<String, double> source;
  final List<double> openByHour; // 24 buckets, normalized 0..1
  final Map<String, double> triggerResponsiveness; // 0..1 open-rate per trigger
  final double engagementLevel; // 0..1
  final int weightedEventCount;

  static const int _coldStartThreshold = 30;
  static const double _halfLifeDays = 21.0;

  static const AffinityProfile empty = AffinityProfile(
    category: {},
    cluster: {},
    source: {},
    openByHour: [],
    triggerResponsiveness: {},
    engagementLevel: 0,
    weightedEventCount: 0,
  );

  /// Below the threshold the profile is too thin to trust — multipliers stay
  /// neutral and the engine runs on content signals alone.
  bool get isWarm => weightedEventCount >= _coldStartThreshold;

  double categoryMultiplier(String? key) => _multiplier(category, key);
  double clusterMultiplier(String? key) => _multiplier(cluster, key);
  double sourceMultiplier(String? key) => _multiplier(source, key);

  double _multiplier(Map<String, double> map, String? key) {
    if (!isWarm || key == null) return 1.0;
    final affinity = map[key];
    if (affinity == null) return 1.0;
    return 0.5 + affinity; // affinity 0..1 -> multiplier 0.5..1.5 (neutral 1.0)
  }

  /// Hour 0–23 the user most often engages, or null when cold.
  int? get peakHour {
    if (!isWarm) return null;
    var bestHour = -1;
    var bestValue = 0.0;
    for (var h = 0; h < openByHour.length; h++) {
      if (openByHour[h] > bestValue) {
        bestValue = openByHour[h];
        bestHour = h;
      }
    }
    return bestHour >= 0 ? bestHour : null;
  }

  static double _weight(EngagementEventType type) => switch (type) {
    EngagementEventType.tapThrough => 5,
    EngagementEventType.searchHit => 5,
    EngagementEventType.cardOpened => 4,
    EngagementEventType.notifOpened => 4,
    EngagementEventType.open => 3,
    EngagementEventType.intentSet => 3,
    EngagementEventType.save => 2,
    EngagementEventType.clusterVisit => 2,
    EngagementEventType.categoryVisit => 2,
    EngagementEventType.search => 1,
    EngagementEventType.cardShown => 0,
    EngagementEventType.notifShown => 0,
    EngagementEventType.rediscoverQueued => 0,
    EngagementEventType.rediscoverCompleted => 0,
    EngagementEventType.noteAdded => 0,
    EngagementEventType.collectionAdded => 0,
    EngagementEventType.cardSnoozed => -2,
    EngagementEventType.cardDismissed => -4,
    EngagementEventType.notifDismissed => -4,
  };

  static AffinityProfile fromEvents(
    List<EngagementEvent> events, {
    DateTime? now,
  }) {
    if (events.isEmpty) {
      debugPrint('[Affinity] events=0 (cold start)');
      return empty;
    }
    final clock = now ?? DateTime.now();
    final cat = <String, double>{};
    final clus = <String, double>{};
    final src = <String, double>{};
    final hours = List<double>.filled(24, 0.0);
    final trigShown = <String, double>{};
    final trigOpened = <String, double>{};
    var weighted = 0.0;
    var positiveRecent = 0.0;

    for (final e in events) {
      final ageDays = clock.difference(e.at).inMilliseconds / 86400000.0;
      final decay = math.pow(0.5, ageDays / _halfLifeDays).toDouble();
      final w = _weight(e.type) * decay;
      if (w != 0) {
        weighted += w.abs();
        final c = e.category;
        if (c != null && c.isNotEmpty) cat[c] = (cat[c] ?? 0) + w;
        final cl = e.clusterLabel;
        if (cl != null && cl.isNotEmpty) clus[cl] = (clus[cl] ?? 0) + w;
        final s = e.source;
        if (s != null && s.isNotEmpty) src[s] = (src[s] ?? 0) + w;
      }
      if (e.type == EngagementEventType.open ||
          e.type == EngagementEventType.notifOpened ||
          e.type == EngagementEventType.cardOpened) {
        hours[e.hourLocal % 24] += decay;
        positiveRecent += decay;
      }
      final tt = e.triggerType;
      if (tt != null && tt.isNotEmpty) {
        if (e.type == EngagementEventType.notifShown) {
          trigShown[tt] = (trigShown[tt] ?? 0) + 1;
        } else if (e.type == EngagementEventType.notifOpened) {
          trigOpened[tt] = (trigOpened[tt] ?? 0) + 1;
        }
      }
    }

    final responsiveness = <String, double>{};
    trigShown.forEach((tt, shown) {
      if (shown > 0) responsiveness[tt] = (trigOpened[tt] ?? 0) / shown;
    });

    final profile = AffinityProfile(
      category: _normalizeSigned(cat),
      cluster: _normalizeSigned(clus),
      source: _normalizeSigned(src),
      openByHour: _normalizeMax(hours),
      triggerResponsiveness: responsiveness,
      engagementLevel: (positiveRecent / 10).clamp(0.0, 1.0),
      weightedEventCount: weighted.round(),
    );

    debugPrint(
      '[Affinity] events=${events.length} weighted=${weighted.round()} '
      'warm=${profile.isWarm} topCategory=${_top(profile.category)} '
      'topSource=${_top(profile.source)} peakHour=${profile.peakHour}',
    );
    return profile;
  }

  /// Maps signed raw scores to 0..1 with 0.5 = neutral: divide by the largest
  /// magnitude, then shift (x+1)/2 so the most-disliked → 0 and most-liked → 1.
  static Map<String, double> _normalizeSigned(Map<String, double> raw) {
    if (raw.isEmpty) return const {};
    var maxAbs = 0.0;
    for (final v in raw.values) {
      final a = v.abs();
      if (a > maxAbs) maxAbs = a;
    }
    if (maxAbs == 0) return {for (final k in raw.keys) k: 0.5};
    return {for (final e in raw.entries) e.key: ((e.value / maxAbs) + 1) / 2};
  }

  static List<double> _normalizeMax(List<double> raw) {
    var maxV = 0.0;
    for (final v in raw) {
      if (v > maxV) maxV = v;
    }
    if (maxV == 0) return raw;
    return [for (final v in raw) v / maxV];
  }

  static String _top(Map<String, double> map) {
    if (map.isEmpty) return '-';
    var bestKey = '-';
    var bestValue = -1.0;
    map.forEach((k, v) {
      if (v > bestValue) {
        bestValue = v;
        bestKey = k;
      }
    });
    return '$bestKey(${bestValue.toStringAsFixed(2)})';
  }
}

/// The cached behavioral profile, rebuilt when the library changes.
final affinityProfileProvider = FutureProvider<AffinityProfile>((ref) async {
  ref.watch(
    urlStreamProvider.select(
      (async) => async.whenOrNull(data: (urls) => urls.length),
    ),
  );
  final isar = ref.read(isarServiceProvider);
  final events = await isar.recentEvents();
  return AffinityProfile.fromEvents(events);
});
