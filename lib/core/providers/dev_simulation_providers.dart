import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_environment.dart';
import '../../core/services/dev_simulation_service.dart';

/// Reactive flag: when `true` the UI behaves as if the library is empty.
/// Dev-only; production default is `false`.
final forceEmptyLibraryProvider = StateNotifierProvider<ForceEmptyLibraryNotifier, bool>(
  (ref) => ForceEmptyLibraryNotifier(),
);

class ForceEmptyLibraryNotifier extends StateNotifier<bool> {
  ForceEmptyLibraryNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    if (AppEnvironment.isProd) return;
    final value = await DevSimulationService.getForceEmptyLibrary();
    if (mounted) state = value;
  }

  Future<void> set(bool value) async {
    await DevSimulationService.setForceEmptyLibrary(value);
    state = value;
  }
}

/// Whether the user has completed onboarding.
/// Defaults to `true` so existing installs are not disrupted.
final hasSeenOnboardingProvider = StateNotifierProvider<HasSeenOnboardingNotifier, bool>(
  (ref) => HasSeenOnboardingNotifier(),
);

class HasSeenOnboardingNotifier extends StateNotifier<bool> {
  HasSeenOnboardingNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final value = await DevSimulationService.getHasSeenOnboarding();
    if (mounted) state = value;
  }

  Future<void> set(bool value) async {
    await DevSimulationService.setHasSeenOnboarding(value);
    state = value;
  }

  Future<void> reset() async {
    await DevSimulationService.resetOnboarding();
    state = false;
  }
}

/// Whether the user has seen the share-feature tip.
final hasSeenShareTipProvider = StateNotifierProvider<HasSeenShareTipNotifier, bool>(
  (ref) => HasSeenShareTipNotifier(),
);

class HasSeenShareTipNotifier extends StateNotifier<bool> {
  HasSeenShareTipNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final value = await DevSimulationService.getHasSeenShareTip();
    if (mounted) state = value;
  }

  Future<void> set(bool value) async {
    await DevSimulationService.setHasSeenShareTip(value);
    state = value;
  }
}

/// Whether the user has seen the first-save celebration.
final hasShownFirstSaveCelebrationProvider =
    StateNotifierProvider<HasShownFirstSaveCelebrationNotifier, bool>(
  (ref) => HasShownFirstSaveCelebrationNotifier(),
);

class HasShownFirstSaveCelebrationNotifier extends StateNotifier<bool> {
  HasShownFirstSaveCelebrationNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final value = await DevSimulationService.getHasShownFirstSaveCelebration();
    if (mounted) state = value;
  }

  Future<void> set(bool value) async {
    await DevSimulationService.setHasShownFirstSaveCelebration(value);
    state = value;
  }

  Future<void> reset() async {
    await DevSimulationService.setHasShownFirstSaveCelebration(false);
    state = false;
  }
}

/// Whether the first-save simulation is enabled (dev-only).
/// When active the home screen pretends the library is empty until a link is
/// saved, then shows only that single link so the first-save animation can be
/// tested repeatedly without clearing data.
final simulateFirstSaveProvider = StateNotifierProvider<SimulateFirstSaveNotifier, bool>(
  (ref) => SimulateFirstSaveNotifier(),
);

class SimulateFirstSaveNotifier extends StateNotifier<bool> {
  SimulateFirstSaveNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    if (AppEnvironment.isProd) return;
    final value = await DevSimulationService.getSimulateFirstSave();
    if (mounted) state = value;
  }

  Future<void> set(bool value) async {
    await DevSimulationService.setSimulateFirstSave(value);
    state = value;
  }
}

/// In-memory session flag for the first-save simulation.
/// Resets on app restart or when the developer manually resets it.
final hasSimulatedFirstSaveInSessionProvider = StateProvider<bool>((ref) => false);
