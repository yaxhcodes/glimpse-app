import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/analytics_provider.dart';
import '../../core/providers/dev_simulation_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/demo_seed_service.dart';

final onboardingFlowCoordinatorProvider = Provider<OnboardingFlowCoordinator>((
  ref,
) {
  return OnboardingFlowCoordinator(
    seedDemo: () => DemoSeedService(ref.read(isarServiceProvider)).seed(),
    markShareLessonSeen: () =>
        ref.read(hasSeenShareTipProvider.notifier).set(true),
    markOnboardingSeen: () =>
        ref.read(hasSeenOnboardingProvider.notifier).set(true),
    trackEvent: (event) => ref.read(analyticsServiceProvider).trackEvent(event),
  );
});

class OnboardingFlowCoordinator {
  OnboardingFlowCoordinator({
    required Future<int> Function() seedDemo,
    required Future<void> Function() markShareLessonSeen,
    required Future<void> Function() markOnboardingSeen,
    required Future<void> Function(AnalyticsEvent event) trackEvent,
    Duration criticalTimeout = const Duration(seconds: 3),
  }) : _seedDemo = seedDemo,
       _markShareLessonSeen = markShareLessonSeen,
       _markOnboardingSeen = markOnboardingSeen,
       _trackEvent = trackEvent,
       _criticalTimeout = criticalTimeout;

  final Future<int> Function() _seedDemo;
  final Future<void> Function() _markShareLessonSeen;
  final Future<void> Function() _markOnboardingSeen;
  final Future<void> Function(AnalyticsEvent event) _trackEvent;
  final Duration _criticalTimeout;

  Future<void>? _completion;
  bool _finished = false;
  bool _transformationTracked = false;

  Future<void> trackStarted() => _trackSafely(AnalyticsEvent.onboardingStarted);

  Future<void> trackTransformation() async {
    if (_transformationTracked) return;
    _transformationTracked = true;
    await _trackSafely(AnalyticsEvent.onboardingTransformed);
  }

  Future<void> complete() => _finish(skip: false);

  Future<void> skip() => _finish(skip: true);

  Future<void> _finish({required bool skip}) {
    if (_finished) return Future.value();
    final running = _completion;
    if (running != null) return running;

    late final Future<void> operation;
    operation = _runCompletion(skip: skip).whenComplete(() {
      if (!_finished) _completion = null;
    });
    _completion = operation;
    return operation;
  }

  Future<void> _runCompletion({required bool skip}) async {
    // This write controls root routing and is the only critical operation.
    // Nothing optional is allowed to delay it: opening Isar for the demo seed
    // can be slow on a first Android launch and previously trapped the user on
    // a disabled completion button.
    await _markOnboardingSeen().timeout(_criticalTimeout);
    _finished = true;

    if (!skip) {
      unawaited(_runNonCritical('seed onboarding memory', _seedDemo));
      unawaited(_runNonCritical('persist share lesson', _markShareLessonSeen));
    }
    unawaited(
      _trackSafely(
        skip
            ? AnalyticsEvent.onboardingSkipped
            : AnalyticsEvent.onboardingCompleted,
      ),
    );
  }

  Future<void> _trackSafely(AnalyticsEvent event) {
    return _runNonCritical('track ${event.name}', () => _trackEvent(event));
  }

  Future<void> _runNonCritical(
    String operation,
    Future<Object?> Function() action,
  ) async {
    try {
      await action();
    } catch (error, stackTrace) {
      developer.log(
        'Could not $operation: $error',
        name: 'Onboarding',
        stackTrace: stackTrace,
      );
    }
  }
}
