import 'dart:convert';
import 'dart:developer' as developer;

class UrlProcessingObserver {
  static void logStage(
    String stage, {
    required String processingId,
    required String url,
    String? saveId,
    String? platform,
    int? attempt,
    Duration? duration,
    Object? error,
    Map<String, Object?> fields = const {},
  }) {
    final payload = <String, Object?>{
      'stage': stage,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'save_id': saveId,
      'processing_id': processingId,
      'url': url,
      'platform': platform,
      'worker_id': 'flutter-client',
      'attempt': attempt,
      'processing_duration_ms': duration?.inMilliseconds,
      'error': error?.toString(),
      ...fields,
    }..removeWhere((_, value) => value == null);

    developer.log(jsonEncode(payload), name: 'UrlProcessing');
  }
}
