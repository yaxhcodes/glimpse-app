import '../../core/database/isar_service.dart';
import '../../core/services/dev_simulation_service.dart';

/// Resolves whether onboarding should be shown on this launch.
///
/// The stored `has_seen_onboarding` flag defaults to `true` so that *existing*
/// installs are never disrupted. That means a genuinely fresh install would
/// otherwise skip onboarding entirely. This bootstrap closes that gap: on the
/// very first launch (flag never written) it decides based on the library —
/// an empty library means a new user who should see onboarding; a non-empty
/// library means an existing tester who should not.
class OnboardingBootstrap {
  OnboardingBootstrap._();

  /// Returns `true` when onboarding has already been seen (skip it), or `false`
  /// when it should be shown. Persists the decision on first run.
  static Future<bool> resolveHasSeenOnboarding(IsarService isar) async {
    final stored = await DevSimulationService.getHasSeenOnboardingRaw();
    if (stored != null) return stored;

    final existingUrls = await isar.getAllUrls();
    final hasSeen = existingUrls.isNotEmpty;
    await DevSimulationService.setHasSeenOnboarding(hasSeen);
    return hasSeen;
  }
}
