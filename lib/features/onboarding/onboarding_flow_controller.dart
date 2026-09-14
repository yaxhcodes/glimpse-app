import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/analytics_provider.dart';
import '../../core/providers/dev_simulation_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/demo_seed_service.dart';
import 'onboarding_progress.dart';

final onboardingFlowCoordinatorProvider = Provider<OnboardingFlowCoordinator>((
  ref,
) {
  final coordinator = OnboardingFlowCoordinator(
    seedDemo: () => DemoSeedService(ref.read(isarServiceProvider)).seed(),
    markOnboardingSeen: () =>
        ref.read(hasSeenOnboardingProvider.notifier).set(true),
    trackEvent: (event) => ref.read(analyticsServiceProvider).trackEvent(event),
    prepareCompletion: (pro) => OnboardingProgress.prepare(pro: pro),
  );
  ref.listen(hasSeenOnboardingProvider, (previous, next) {
    if (previous == true && !next) coordinator._resetForReplay();
  });
  return coordinator;
});

class OnboardingFlowCoordinator {
  OnboardingFlowCoordinator({
    required Future<int> Function() seedDemo,
    required Future<void> Function() markOnboardingSeen,
    required Future<void> Function(AnalyticsEvent event) trackEvent,
    Future<void> Function(bool pro)? prepareCompletion,
    Duration criticalTimeout = const Duration(seconds: 3),
  }) : _prepareCompletion = prepareCompletion,
       _seedDemo = seedDemo,
       _markOnboardingSeen = markOnboardingSeen,
       _trackEvent = trackEvent,
       _criticalTimeout = criticalTimeout;

  final Future<int> Function() _seedDemo;
  final Future<void> Function() _markOnboardingSeen;
  final Future<void> Function(AnalyticsEvent event) _trackEvent;
  final Duration _criticalTimeout;
  final Future<void> Function(bool pro)? _prepareCompletion;
  final _seenChapters = <int>{};

  Future<void> trackChapter(int chapter) async {
    if (!_seenChapters.add(chapter)) return;
    await _trackSafely(
      [
        AnalyticsEvent.onboardingChapterWelcome,
        AnalyticsEvent.onboardingChapterReader,
        AnalyticsEvent.onboardingChapterLibrary,
        AnalyticsEvent.onboardingChapterDiscovered,
        AnalyticsEvent.onboardingChapterAsk,
        AnalyticsEvent.onboardingChapterRediscover,
        AnalyticsEvent.onboardingChapterPro,
      ][chapter],
    );
  }

  Future<void>? _completion;
  bool _finished = false;

  void _resetForReplay() {
    _finished = false;
    _completion = null;
    _seenChapters.clear();
  }

  Future<void> trackStarted() => _trackSafely(AnalyticsEvent.onboardingStarted);

  Future<void> complete({bool explorePro = false}) =>
      _finish(skip: false, pro: explorePro);

  Future<void> skip() => _finish(skip: true);

  Future<void> _finish({required bool skip, bool pro = false}) {
    if (_finished) return Future.value();
    final running = _completion;
    if (running != null) return running;

    late final Future<void> operation;
    operation = _runCompletion(skip: skip, pro: pro).whenComplete(() {
      if (!_finished) _completion = null;
    });
    _completion = operation;
    return operation;
  }

  Future<void> _runCompletion({required bool skip, required bool pro}) async {
    // This write controls root routing and is the only critical operation.
    // Nothing optional is allowed to delay it: opening Isar for the demo seed
    // can be slow on a first Android launch and previously trapped the user on
    // a disabled completion button.
    if (_prepareCompletion != null) {
      await _prepareCompletion(pro).timeout(_criticalTimeout);
    }
    if (pro) unawaited(_trackSafely(AnalyticsEvent.onboardingProExplored));
    await _markOnboardingSeen().timeout(_criticalTimeout);
    _finished = true;

    if (!skip) {
      unawaited(_runNonCritical('seed onboarding memory', _seedDemo));
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

class OnboardingChapterController {
  static const count = 7;
  int chapter = 0;
}
