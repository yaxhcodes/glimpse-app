import 'rediscover_journey_provider.dart';
import 'rediscover_memory.dart';

enum RediscoverSurface { home, rediscover }

enum RediscoverReasonCode {
  dueRevisit,
  strongTopicReturn,
  supportedTopicReturn,
  seasonalReturn,
  exceptionalGem,
  coherentJourney,
}

class RediscoverOpenContext {
  const RediscoverOpenContext({
    required this.memoryId,
    required this.topicKey,
    required this.surface,
    required this.position,
    required this.reasonCode,
    required this.algorithmVersion,
    required this.exposureId,
    this.confidenceTier,
    required this.createdAt,
  });

  static const algorithm = 'rediscover-topic-return-v1';
  static const validity = Duration(hours: 6);

  final String memoryId;
  final String topicKey;
  final RediscoverSurface surface;
  final int position;
  final RediscoverReasonCode reasonCode;
  final String? confidenceTier;
  final String algorithmVersion;
  final String exposureId;
  final DateTime createdAt;

  bool isValidAt(DateTime now) =>
      !now.isBefore(createdAt) && now.difference(createdAt) <= validity;

  static RediscoverOpenContext forMemory(
    RediscoverMemory memory, {
    required RediscoverSurface surface,
    required int position,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    return RediscoverOpenContext(
      memoryId: memory.id,
      topicKey: memory.topicKey,
      surface: surface,
      position: position,
      reasonCode: reasonFor(memory),
      confidenceTier: memory.journey.topicPulseConfidence,
      algorithmVersion: algorithm,
      exposureId: '${_dateKey(at)}:${memory.id}',
      createdAt: at,
    );
  }

  static RediscoverReasonCode reasonFor(RediscoverMemory memory) {
    if (memory.journey.items.any((item) => item.url.isRevisitDue)) {
      return RediscoverReasonCode.dueRevisit;
    }
    return switch (memory.journey.kind) {
      RediscoverJourneyKind.returningTopic =>
        memory.journey.topicPulseConfidence == 'strong'
            ? RediscoverReasonCode.strongTopicReturn
            : RediscoverReasonCode.supportedTopicReturn,
      RediscoverJourneyKind.onThisDay => RediscoverReasonCode.seasonalReturn,
      RediscoverJourneyKind.forgottenGems =>
        RediscoverReasonCode.exceptionalGem,
      _ => RediscoverReasonCode.coherentJourney,
    };
  }

  static String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class RediscoverJourneyRouteArgs {
  const RediscoverJourneyRouteArgs({
    required this.journey,
    required this.openContext,
  });

  final RediscoverJourney journey;
  final RediscoverOpenContext openContext;
}

class UrlDetailRouteArgs {
  const UrlDetailRouteArgs({
    this.siblingIds = const [],
    this.rediscoverContext,
  });

  final List<int> siblingIds;
  final RediscoverOpenContext? rediscoverContext;
}
