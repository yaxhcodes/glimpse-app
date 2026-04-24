import '../config/app_environment.dart';

/// Features tracked for monthly usage limits.
enum UsageFeature {
  aiSave,
  ask,
  search,
}

/// Centralized limits configuration.
///
/// Production and dev builds share the same logic; only the numeric
/// thresholds differ. Dev limits are lower so testers can hit ceilings
/// quickly without waiting for a full month.
///
/// Uses [AppEnvironment.isDevContext] so both `--dart-define=ENV=dev` **and**
/// the Android dev product flavour (`com.shinrinyoku.glimpse.dev`) are
/// recognised without requiring the dart-define.
class UsageLimits {
  UsageLimits._();

  static bool get _isDev => AppEnvironment.isDevContext;

  static int getLimit(UsageFeature feature) {
    final limit = _isDev ? _devLimit(feature) : _prodLimit(feature);
    // ignore: avoid_print
    print('[UsageLimits] limit for ${feature.name}: $limit (dev: $_isDev)');
    return limit;
  }

  static int _prodLimit(UsageFeature feature) => switch (feature) {
    UsageFeature.aiSave => 15,
    UsageFeature.ask => 5,
    UsageFeature.search => 15,
  };

  static int _devLimit(UsageFeature feature) => switch (feature) {
    UsageFeature.aiSave => 3,
    UsageFeature.ask => 2,
    UsageFeature.search => 3,
  };
}
