import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glimpse/features/onboarding/onboarding_progress.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Pro intent survives authentication and is consumed once', () async {
    await OnboardingProgress.prepare(pro: true);
    expect(await OnboardingProgress.pendingPro(), true);
    expect(
      OnboardingProgress.proDestination(
        ready: false,
        externalIntent: false,
        atHome: true,
      ),
      OnboardingProDestination.wait,
    );
    expect(await OnboardingProgress.pendingPro(), true);
    expect(
      OnboardingProgress.proDestination(
        ready: true,
        externalIntent: false,
        atHome: true,
      ),
      OnboardingProDestination.subscription,
    );
    await OnboardingProgress.clearPro();
    expect(await OnboardingProgress.pendingPro(), false);
  });
  test(
    'external intents take priority and other routes are not interrupted',
    () {
      expect(
        OnboardingProgress.proDestination(
          ready: true,
          externalIntent: true,
          atHome: true,
        ),
        OnboardingProDestination.cancel,
      );
      expect(
        OnboardingProgress.proDestination(
          ready: true,
          externalIntent: false,
          atHome: false,
        ),
        OnboardingProDestination.wait,
      );
    },
  );
  test('free continuation clears an older pending Pro intent', () async {
    await OnboardingProgress.prepare(pro: true);
    await OnboardingProgress.prepare(pro: false);
    expect(await OnboardingProgress.pendingPro(), false);
  });
}
