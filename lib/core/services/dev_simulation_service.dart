import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

/// Dev-only simulation controls for testing first-time user experiences
/// without touching real user data.
class DevSimulationService {
  static const String _forceEmptyLibraryKey = 'dev_force_empty_library';
  static const String _hasSeenOnboardingKey = 'has_seen_onboarding';
  static const String _hasSeenShareTipKey = 'has_seen_share_tip';
  static const String _hasShownFirstSaveCelebrationKey =
      'has_shown_first_save_celebration';
  static const String _hasSeenGuideCardKey = 'has_seen_guide_card';
  static const String _hasSeenRediscoverTipKey = 'has_seen_rediscover_tip';
  static const String _simulateFirstSaveKey = 'dev_simulate_first_save';

  /// Whether the library should appear empty (dev-only).
  static Future<bool> getForceEmptyLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_forceEmptyLibraryKey) ?? false;
  }

  static Future<void> setForceEmptyLibrary(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_forceEmptyLibraryKey, value);
    developer.log(
      'Force Empty Library set to $value',
      name: 'DevSimulation',
    );
  }

  /// Whether the user has completed onboarding.
  ///
  /// Defaults to `true` so existing installs are not disrupted.
  static Future<bool> getHasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenOnboardingKey) ?? true;
  }

  static Future<void> setHasSeenOnboarding(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboardingKey, value);
    developer.log(
      'HasSeenOnboarding set to $value',
      name: 'DevSimulation',
    );
  }

  /// Raw stored onboarding flag, or `null` when it has never been written
  /// (i.e. a fresh install). Used by the onboarding bootstrap to distinguish
  /// new users from existing installs without overriding the safe default.
  static Future<bool?> getHasSeenOnboardingRaw() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenOnboardingKey);
  }

  /// Resets onboarding (and the first-run guidance that follows it) so the next
  /// app launch replays the whole first-time experience.
  static Future<void> resetOnboarding() async {
    await setHasSeenOnboarding(false);
    await setHasSeenGuideCard(false);
    await setHasSeenRediscoverTip(false);
    await setHasShownFirstSaveCelebration(false);
  }

  /// Whether the user has dismissed the post-onboarding "how Glimpse works"
  /// guide card. Defaults to `false` so new users see it.
  static Future<bool> getHasSeenGuideCard() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenGuideCardKey) ?? false;
  }

  static Future<void> setHasSeenGuideCard(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenGuideCardKey, value);
  }

  /// Whether the user has seen the one-time Rediscover explainer tip.
  /// Defaults to `false` so it shows the first time Rediscover appears.
  static Future<bool> getHasSeenRediscoverTip() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenRediscoverTipKey) ?? false;
  }

  static Future<void> setHasSeenRediscoverTip(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenRediscoverTipKey, value);
  }

  /// Whether the user has seen the share-tip snackbar.
  static Future<bool> getHasSeenShareTip() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenShareTipKey) ?? false;
  }

  static Future<void> setHasSeenShareTip(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenShareTipKey, value);
  }

  /// Whether the user has seen the first-save celebration.
  static Future<bool> getHasShownFirstSaveCelebration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasShownFirstSaveCelebrationKey) ?? false;
  }

  static Future<void> setHasShownFirstSaveCelebration(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasShownFirstSaveCelebrationKey, value);
    developer.log(
      'First save celebration flag set to $value',
      name: 'DevSimulation',
    );
  }

  /// Whether the first-save simulation is enabled (dev-only).
  static Future<bool> getSimulateFirstSave() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_simulateFirstSaveKey) ?? false;
  }

  static Future<void> setSimulateFirstSave(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_simulateFirstSaveKey, value);
    developer.log(
      'Simulate First Save set to $value',
      name: 'DevSimulation',
    );
  }
}
