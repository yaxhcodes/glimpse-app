import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/isar_service.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../home/home_provider.dart';
import 'rediscover_memory_prefs.dart';
import 'rediscover_topic_pulse.dart';

final rediscoverTopicPulsesProvider =
    FutureProvider<List<RediscoverTopicPulse>>((ref) async {
      ref.watch(
        urlStreamProvider.select(
          (async) => async.whenOrNull(data: (urls) => urls.length),
        ),
      );
      final library = await ref.read(isarServiceProvider).getAllUrls();
      final storedRecords = await RediscoverMemoryPrefs.loadTopicPulses();
      final stored = storedRecords
          .map(RediscoverTopicPulse.fromJson)
          .whereType<RediscoverTopicPulse>()
          .toList();
      final now = DateTime.now();

      final request = _PulseDetectionRequest(
        library: library,
        stored: stored,
        now: now,
      );
      List<RediscoverTopicPulse> pulses;
      try {
        pulses = await compute(_validateOrDetectPulses, request);
      } catch (error, stackTrace) {
        debugPrint('Rediscover pulse isolate fallback: $error\n$stackTrace');
        pulses = _validateOrDetectPulses(request);
      }
      pulses = _dedupePulses(pulses).take(12).toList();
      await RediscoverMemoryPrefs.replaceTopicPulses(
        pulses.map((pulse) => pulse.toJson()).toList(),
      );
      return pulses;
    });

Future<RediscoverTopicPulse?> detectAndPersistTopicPulseForSave({
  required IsarService isar,
  required int sourceId,
}) async {
  final library = await isar.getAllUrls();
  final source = library.where((url) => url.id == sourceId).firstOrNull;
  if (source == null) return null;
  final request = _SinglePulseRequest(
    source: source,
    library: library,
    now: DateTime.now(),
  );
  RediscoverTopicPulse? pulse;
  try {
    pulse = await compute(_detectSinglePulse, request);
  } catch (error, stackTrace) {
    debugPrint('Rediscover pulse isolate fallback: $error\n$stackTrace');
    pulse = _detectSinglePulse(request);
  }
  if (pulse != null) {
    await RediscoverMemoryPrefs.upsertTopicPulse(pulse.toJson());
  }
  return pulse;
}

List<RediscoverTopicPulse> _validateOrDetectPulses(
  _PulseDetectionRequest request,
) {
  const service = RediscoverTopicPulseService();
  if (request.stored.isEmpty) {
    return service.detectRecent(library: request.library, now: request.now);
  }

  final byId = {for (final url in request.library) url.id: url};
  final validated = <RediscoverTopicPulse>[];
  for (final stored in request.stored) {
    if (request.now.difference(stored.detectedAt) > const Duration(days: 30)) {
      continue;
    }
    final source = byId[stored.triggerSaveId];
    if (source == null) continue;
    final current = service.detectForSave(
      source: source,
      library: request.library,
      now: request.now,
    );
    if (current == null || current.topicKey != stored.topicKey) continue;
    validated.add(current.copyWith(detectedAt: stored.detectedAt));
  }
  if (validated.isNotEmpty) return validated;
  return service.detectRecent(library: request.library, now: request.now);
}

RediscoverTopicPulse? _detectSinglePulse(_SinglePulseRequest request) {
  return const RediscoverTopicPulseService().detectForSave(
    source: request.source,
    library: request.library,
    now: request.now,
  );
}

List<RediscoverTopicPulse> _dedupePulses(List<RediscoverTopicPulse> pulses) {
  pulses.sort((a, b) {
    final byConfidence = b.confidence.index.compareTo(a.confidence.index);
    if (byConfidence != 0) return byConfidence;
    final byScore = b.rankScore.compareTo(a.rankScore);
    if (byScore != 0) return byScore;
    return b.detectedAt.compareTo(a.detectedAt);
  });
  final topics = <String>{};
  final triggers = <int>{};
  return [
    for (final pulse in pulses)
      if (topics.add(pulse.topicKey) && triggers.add(pulse.triggerSaveId))
        pulse,
  ];
}

class _PulseDetectionRequest {
  const _PulseDetectionRequest({
    required this.library,
    required this.stored,
    required this.now,
  });

  final List<SavedUrl> library;
  final List<RediscoverTopicPulse> stored;
  final DateTime now;
}

class _SinglePulseRequest {
  const _SinglePulseRequest({
    required this.source,
    required this.library,
    required this.now,
  });

  final SavedUrl source;
  final List<SavedUrl> library;
  final DateTime now;
}
