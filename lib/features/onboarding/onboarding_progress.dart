import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import '../../core/services/analytics_service.dart';

enum OnboardingProDestination { wait, cancel, subscription }

abstract final class OnboardingProgress {
  static OnboardingProDestination proDestination({
    required bool ready,
    required bool externalIntent,
    required bool atHome,
  }) {
    if (!ready) return OnboardingProDestination.wait;
    if (externalIntent) return OnboardingProDestination.cancel;
    return atHome
        ? OnboardingProDestination.subscription
        : OnboardingProDestination.wait;
  }

  static final _recording = <AnalyticsEvent>{};
  static final _recorded = <AnalyticsEvent>{};
  static Future<void> recordMilestone(
    AnalyticsService analytics,
    AnalyticsEvent event,
  ) async {
    if (_recorded.contains(event) || !_recording.add(event)) return;
    try {
      final p = await SharedPreferences.getInstance();
      final key = 'onboarding_v2_${event.name}';
      if (p.getBool(enabledKey) != true) return;
      if (p.getBool(key) != true) {
        await p.setBool(key, true);
        await analytics.trackEvent(event);
      }
      _recorded.add(event);
    } catch (error, stackTrace) {
      developer.log(
        'Could not record onboarding milestone',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _recording.remove(event);
    }
  }

  static const enabledKey = 'onboarding_v2_guidance';
  static const proKey = 'onboarding_v2_pending_pro';
  static Future<void> prepare({required bool pro}) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(enabledKey, true);
    await p.setBool(proKey, pro);
  }

  static Future<bool> pendingPro() async =>
      (await SharedPreferences.getInstance()).getBool(proKey) ?? false;
  static Future<void> clearPro() async =>
      (await SharedPreferences.getInstance()).remove(proKey);
}
