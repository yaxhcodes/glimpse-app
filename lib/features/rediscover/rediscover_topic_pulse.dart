import 'dart:convert';
import 'dart:math' as math;

import '../../core/models/saved_url.dart';
import '../../core/services/saved_url_subject_resolver.dart';
import '../../core/services/tag_noise_filter.dart';

enum RediscoverTopicPulseConfidence { supported, strong }

class RediscoverTopicPulse {
  const RediscoverTopicPulse({
    required this.id,
    required this.topicKey,
    required this.topicLabel,
    required this.triggerSaveId,
    required this.archiveSaveIds,
    required this.confidence,
    required this.detectedAt,
    required this.evidence,
    required this.rankScore,
  });

  final String id;
  final String topicKey;
  final String topicLabel;
  final int triggerSaveId;
  final List<int> archiveSaveIds;
  final RediscoverTopicPulseConfidence confidence;
  final DateTime detectedAt;
  final List<String> evidence;
  final double rankScore;

  RediscoverTopicPulse copyWith({DateTime? detectedAt}) {
    return RediscoverTopicPulse(
      id: id,
      topicKey: topicKey,
      topicLabel: topicLabel,
      triggerSaveId: triggerSaveId,
      archiveSaveIds: archiveSaveIds,
      confidence: confidence,
      detectedAt: detectedAt ?? this.detectedAt,
      evidence: evidence,
      rankScore: rankScore,
    );
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'id': id,
    'topicKey': topicKey,
    'topicLabel': topicLabel,
    'triggerSaveId': triggerSaveId,
    'archiveSaveIds': archiveSaveIds,
    'confidence': confidence.name,
    'detectedAt': detectedAt.toIso8601String(),
    'evidence': evidence,
    'rankScore': rankScore,
  };

  static RediscoverTopicPulse? fromJson(Map<String, Object?> json) {
    final trigger = json['triggerSaveId'];
    final archive = json['archiveSaveIds'];
    final detectedAt = DateTime.tryParse(json['detectedAt']?.toString() ?? '');
    final confidenceName = json['confidence']?.toString();
    final confidence = RediscoverTopicPulseConfidence.values
        .where((value) => value.name == confidenceName)
        .firstOrNull;
    if (trigger is! num || archive is! List || detectedAt == null) return null;
    if (confidence == null) return null;
    final ids = archive.whereType<num>().map((id) => id.toInt()).toList();
    if (ids.isEmpty) return null;
    final topicKey = json['topicKey']?.toString().trim() ?? '';
    final topicLabel = json['topicLabel']?.toString().trim() ?? '';
    if (topicKey.isEmpty || topicLabel.isEmpty) return null;
    return RediscoverTopicPulse(
      id: json['id']?.toString() ?? 'pulse:$topicKey:${trigger.toInt()}',
      topicKey: topicKey,
      topicLabel: topicLabel,
      triggerSaveId: trigger.toInt(),
      archiveSaveIds: ids,
      confidence: confidence,
      detectedAt: detectedAt,
      evidence: (json['evidence'] as List? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(),
      rankScore: (json['rankScore'] as num?)?.toDouble() ?? 0,
    );
  }
}

class RediscoverTopicPulseService {
  const RediscoverTopicPulseService();

  static const recentWindow = Duration(days: 14);
  static const archiveGap = Duration(days: 14);
  static const strongSimilarity = 0.55;
  static const supportedSimilarity = 0.45;

  RediscoverTopicPulse? detectForSave({
    required SavedUrl source,
    required List<SavedUrl> library,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    if (!_isEligible(source) ||
        clock.difference(source.savedAt) > recentWindow) {
      return null;
    }

    final sourceEvidence = _TopicEvidence.fromUrl(source);
    final sourceSubject = SavedUrlSubjectResolver.resolve(source);
    final matches = <_ArchiveMatch>[];
    for (final candidate in library) {
      if (candidate.id == source.id || !_isEligible(candidate)) continue;
      if (candidate.isQueued && !candidate.isRevisitDue) continue;
      if (source.savedAt.difference(candidate.savedAt) < archiveGap) continue;

      final candidateSubject = SavedUrlSubjectResolver.resolve(candidate);
      if (sourceSubject != null &&
          candidateSubject != null &&
          sourceSubject.key != candidateSubject.key) {
        continue;
      }

      final candidateEvidence = _TopicEvidence.fromUrl(candidate);
      final sharedTags = sourceEvidence.tags.intersection(
        candidateEvidence.tags,
      );
      final sharedTopics = sourceEvidence.topics.intersection(
        candidateEvidence.topics,
      );
      final sharedEntities = sourceEvidence.entities.intersection(
        candidateEvidence.entities,
      );
      final sharedSpecific = {
        ...sharedEntities,
        ...sharedTopics,
        ...sharedTags,
      };
      final subjectAgrees =
          sourceSubject != null &&
          candidateSubject != null &&
          sourceSubject.key == candidateSubject.key;
      final similarity = _cosine(source.embedding, candidate.embedding);

      RediscoverTopicPulseConfidence? confidence;
      if (similarity != null) {
        if (similarity >= strongSimilarity &&
            (subjectAgrees || sharedSpecific.isNotEmpty)) {
          confidence = RediscoverTopicPulseConfidence.strong;
        } else if (similarity >= supportedSimilarity &&
            subjectAgrees &&
            sharedSpecific.isNotEmpty) {
          confidence = RediscoverTopicPulseConfidence.supported;
        }
      } else {
        final independentEvidence = [
          sharedTags.isNotEmpty,
          sharedTopics.isNotEmpty,
          sharedEntities.isNotEmpty,
        ].where((value) => value).length;
        if (subjectAgrees && independentEvidence >= 2) {
          confidence = RediscoverTopicPulseConfidence.supported;
        }
      }
      if (confidence == null) continue;
      matches.add(
        _ArchiveMatch(
          url: candidate,
          confidence: confidence,
          similarity: similarity ?? 0,
          sharedSpecific: sharedSpecific,
        ),
      );
    }

    if (matches.isEmpty) return null;
    matches.sort(_compareMatches);
    final strongest = matches.first.confidence;
    if (strongest == RediscoverTopicPulseConfidence.supported &&
        matches.length < 2) {
      return null;
    }

    final selected = matches.take(4).toList();
    final anchorCounts = <String, int>{};
    for (final match in selected) {
      for (final anchor in match.sharedSpecific) {
        anchorCounts[anchor] = (anchorCounts[anchor] ?? 0) + 1;
      }
    }
    final anchor = _bestAnchor(anchorCounts);
    final subjectKey = sourceSubject?.key ?? 'topic';
    final subjectLabel = sourceSubject?.label ?? 'Earlier saves';
    final topicKey = '$subjectKey:${anchor ?? _slug(subjectLabel)}';
    final topicLabel = anchor == null ? subjectLabel : _titleCase(anchor);
    final recentMomentum = _recentMomentum(
      source: source,
      library: library,
      sourceSubject: sourceSubject,
      sourceEvidence: sourceEvidence,
      now: clock,
    );
    final evidence = <String>[
      if (anchor != null) 'shared:$anchor',
      if (sourceSubject != null) 'subject:${sourceSubject.key}',
      'archive:${selected.length}',
      'momentum:$recentMomentum',
      'similarity:${selected.first.similarity.toStringAsFixed(3)}',
    ];
    final rankScore =
        (strongest == RediscoverTopicPulseConfidence.strong ? 92.0 : 82.0) +
        math.min(6, selected.length * 1.5) +
        math.min(4, recentMomentum.toDouble()) +
        math.min(
          3,
          selected.first.url.savedAt.difference(source.savedAt).inDays.abs() /
              30,
        );

    return RediscoverTopicPulse(
      id: 'pulse:$topicKey:${source.id}',
      topicKey: topicKey,
      topicLabel: topicLabel,
      triggerSaveId: source.id,
      archiveSaveIds: selected.map((match) => match.url.id).toList(),
      confidence: strongest,
      detectedAt: clock,
      evidence: evidence,
      rankScore: rankScore,
    );
  }

  List<RediscoverTopicPulse> detectRecent({
    required List<SavedUrl> library,
    DateTime? now,
    int triggerLimit = 20,
  }) {
    final clock = now ?? DateTime.now();
    final recent =
        library
            .where(
              (url) =>
                  _isEligible(url) &&
                  clock.difference(url.savedAt) <= recentWindow &&
                  !url.savedAt.isAfter(clock),
            )
            .toList()
          ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final pulses = <RediscoverTopicPulse>[];
    final usedTopics = <String>{};
    for (final source in recent.take(triggerLimit)) {
      final pulse = detectForSave(source: source, library: library, now: clock);
      if (pulse == null || !usedTopics.add(pulse.topicKey)) continue;
      pulses.add(pulse);
    }
    pulses.sort(_comparePulses);
    return pulses;
  }

  static bool _isEligible(SavedUrl url) {
    return !url.isInBin &&
        !url.isDone &&
        url.rediscoverDismissedAt == null &&
        url.isProcessingReady;
  }

  static int _compareMatches(_ArchiveMatch a, _ArchiveMatch b) {
    final byConfidence = b.confidence.index.compareTo(a.confidence.index);
    if (byConfidence != 0) return byConfidence;
    final bySimilarity = b.similarity.compareTo(a.similarity);
    if (bySimilarity != 0) return bySimilarity;
    final byUnopened = (a.url.openedAt == null ? 0 : 1).compareTo(
      b.url.openedAt == null ? 0 : 1,
    );
    if (byUnopened != 0) return byUnopened;
    return a.url.savedAt.compareTo(b.url.savedAt);
  }

  static int _comparePulses(RediscoverTopicPulse a, RediscoverTopicPulse b) {
    final byConfidence = b.confidence.index.compareTo(a.confidence.index);
    if (byConfidence != 0) return byConfidence;
    final byScore = b.rankScore.compareTo(a.rankScore);
    if (byScore != 0) return byScore;
    return a.topicKey.compareTo(b.topicKey);
  }

  static int _recentMomentum({
    required SavedUrl source,
    required List<SavedUrl> library,
    required SavedUrlSubject? sourceSubject,
    required _TopicEvidence sourceEvidence,
    required DateTime now,
  }) {
    var count = 0;
    for (final candidate in library) {
      if (candidate.id == source.id || !_isEligible(candidate)) continue;
      final age = now.difference(candidate.savedAt);
      if (age.isNegative || age > const Duration(days: 7)) continue;
      final subject = SavedUrlSubjectResolver.resolve(candidate);
      if (sourceSubject != null && subject?.key == sourceSubject.key) {
        count++;
        continue;
      }
      final evidence = _TopicEvidence.fromUrl(candidate);
      if (sourceEvidence.all.intersection(evidence.all).isNotEmpty) count++;
    }
    return count;
  }
}

class _ArchiveMatch {
  const _ArchiveMatch({
    required this.url,
    required this.confidence,
    required this.similarity,
    required this.sharedSpecific,
  });

  final SavedUrl url;
  final RediscoverTopicPulseConfidence confidence;
  final double similarity;
  final Set<String> sharedSpecific;
}

class _TopicEvidence {
  const _TopicEvidence({
    required this.tags,
    required this.topics,
    required this.entities,
  });

  final Set<String> tags;
  final Set<String> topics;
  final Set<String> entities;

  Set<String> get all => {...tags, ...topics, ...entities};

  factory _TopicEvidence.fromUrl(SavedUrl url) {
    final tags = TagNoiseFilter.filterTags(
      url.tags,
    ).map(_normalize).where(_isSpecific).toSet();
    final topics = <String>{};
    final entities = <String>{};
    final raw = url.enrichmentJson;
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final rawTopics = decoded['topics'];
          if (rawTopics is List) {
            topics.addAll(
              rawTopics
                  .map((item) => _normalize(item.toString()))
                  .where(_isSpecific),
            );
          }
          final rawMentions = decoded['mentions'];
          if (rawMentions is List) {
            for (final mention in rawMentions.whereType<Map>()) {
              final value =
                  mention['title'] ??
                  mention['name'] ??
                  mention['text'] ??
                  mention['value'];
              if (value == null) continue;
              final normalized = _normalize(value.toString());
              if (_isSpecific(normalized)) entities.add(normalized);
            }
          }
        }
      } catch (_) {
        // Malformed enrichment is treated as absent evidence.
      }
    }
    return _TopicEvidence(tags: tags, topics: topics, entities: entities);
  }
}

const _genericEvidence = <String>{
  'ai',
  'article',
  'book',
  'books',
  'content',
  'education',
  'entertainment',
  'film',
  'films',
  'history',
  'india',
  'instagram',
  'learn',
  'learning',
  'movie',
  'movies',
  'movie recommendation',
  'movie recommendations',
  'recommendation',
  'recommendations',
  'science',
  'social media',
  'technology',
  'travel',
  'video',
  'watch later',
  'watchlist',
};

double? _cosine(List<double>? a, List<double>? b) {
  if (a == null || b == null || a.isEmpty || b.isEmpty) return null;
  if (a.length != b.length) return null;
  var dot = 0.0;
  var normA = 0.0;
  var normB = 0.0;
  for (var index = 0; index < a.length; index++) {
    dot += a[index] * b[index];
    normA += a[index] * a[index];
    normB += b[index] * b[index];
  }
  if (normA == 0 || normB == 0) return null;
  return dot / (math.sqrt(normA) * math.sqrt(normB));
}

String? _bestAnchor(Map<String, int> counts) {
  if (counts.isEmpty) return null;
  final ranked = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      final bySpecificity = b.key.length.compareTo(a.key.length);
      if (bySpecificity != 0) return bySpecificity;
      return a.key.compareTo(b.key);
    });
  return ranked.first.key;
}

String _normalize(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool _isSpecific(String value) {
  return value.length >= 3 && !_genericEvidence.contains(value);
}

String _slug(String value) => _normalize(value).replaceAll(' ', '-');

String _titleCase(String value) {
  return value
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) {
        if (word == 'ai') return 'AI';
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
      .join(' ');
}
