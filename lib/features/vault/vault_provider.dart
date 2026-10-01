import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/service_providers.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/services/subscription_service.dart';
import '../../core/services/vault/vault_crypto.dart';
import '../../core/services/vault/vault_repository.dart';

final vaultCryptoProvider = Provider<VaultCrypto>(
  (ref) => const PlatformVaultCrypto(),
);

final vaultRepositoryProvider = Provider<VaultRepository>(
  (ref) => VaultRepository(
    isarService: ref.watch(isarServiceProvider),
    crypto: ref.watch(vaultCryptoProvider),
  ),
);

/// How many items the vault holds; readable while it's locked.
final vaultCountProvider = StreamProvider<int>((ref) async* {
  final repository = ref.watch(vaultRepositoryProvider);
  await for (final _ in repository.watch()) {
    yield await repository.count();
  }
});

/// Whether this person can file new things into the vault. What's already
/// inside stays theirs to open, move out and delete whatever their plan.
///
/// [liveIsPro] is the app's own answer; the share sheet doesn't start
/// billing, so it falls back to the last plan the app saw.
Future<bool> canAddToVault({required bool liveIsPro}) async {
  if (liveIsPro) return true;
  if (await EntitlementService.loadEffectiveProSnapshot()) return true;
  return EntitlementService.isProUser(
    SubscriptionTier.free,
    devProOverride: await EntitlementService.getDevProOverride(),
  );
}

enum VaultPhase {
  locked,
  unlocking,
  open,

  /// No screen lock on the phone: the vault can't be locked, so it can't
  /// be used.
  noScreenLock,

  /// Android destroyed the key (the screen lock was removed, or this is a
  /// restore onto another phone). Only a reset can make it usable again.
  invalidated,
}

class VaultState {
  const VaultState({
    this.phase = VaultPhase.locked,
    this.entries = const [],
    this.unreadable = 0,
    this.lastUnlock,
  });

  final VaultPhase phase;
  final List<VaultEntry> entries;
  final int unreadable;

  /// How the last unlock attempt ended, for the screen to explain it.
  final VaultUnlockStatus? lastUnlock;

  bool get isOpen => phase == VaultPhase.open;

  VaultState copyWith({
    VaultPhase? phase,
    List<VaultEntry>? entries,
    int? unreadable,
    VaultUnlockStatus? lastUnlock,
  }) => VaultState(
    phase: phase ?? this.phase,
    entries: entries ?? this.entries,
    unreadable: unreadable ?? this.unreadable,
    lastUnlock: lastUnlock,
  );
}

final vaultControllerProvider =
    StateNotifierProvider.autoDispose<VaultController, VaultState>((ref) {
      final controller = VaultController(ref.watch(vaultRepositoryProvider));
      // Leaving the vault locks it.
      ref.onDispose(controller.lockQuietly);
      return controller;
    });

class VaultController extends StateNotifier<VaultState> {
  VaultController(this._repository) : super(const VaultState());

  final VaultRepository _repository;

  /// Checks the phone before offering to unlock: no screen lock, or a key
  /// Android already destroyed, each need saying first.
  Future<void> checkDevice() async {
    try {
      final status = await _repository.deviceStatus();
      if (!mounted) return;
      if (!status.hasScreenLock) {
        state = const VaultState(phase: VaultPhase.noScreenLock);
      } else if (status.keyInvalidated) {
        state = const VaultState(phase: VaultPhase.invalidated);
      } else if (state.phase == VaultPhase.noScreenLock) {
        state = const VaultState();
      }
    } catch (error) {
      developer.log('Vault status failed', name: 'Vault', error: error);
    }
  }

  Future<void> unlock({required String title, String? subtitle}) async {
    if (state.phase == VaultPhase.unlocking || state.isOpen) return;
    state = state.copyWith(phase: VaultPhase.unlocking);
    VaultUnlockStatus outcome;
    try {
      outcome = (await _repository.unlock(
        title: title,
        subtitle: subtitle,
      )).status;
    } catch (error) {
      developer.log('Vault unlock failed', name: 'Vault', error: error);
      outcome = VaultUnlockStatus.failed;
    }
    if (!mounted) return;
    switch (outcome) {
      case VaultUnlockStatus.ok:
        await _load();
      case VaultUnlockStatus.noScreenLock:
        state = const VaultState(phase: VaultPhase.noScreenLock);
      case VaultUnlockStatus.invalidated:
        state = const VaultState(phase: VaultPhase.invalidated);
      case VaultUnlockStatus.cancelled:
      case VaultUnlockStatus.failed:
      case VaultUnlockStatus.lockout:
        state = VaultState(lastUnlock: outcome);
    }
  }

  Future<void> _load() async {
    try {
      final contents = await _repository.openAll();
      if (!mounted) return;
      state = VaultState(
        phase: VaultPhase.open,
        entries: contents.entries,
        unreadable: contents.unreadable,
      );
    } on VaultCryptoException catch (error) {
      if (!mounted) return;
      state = VaultState(
        phase: error.code == 'invalidated'
            ? VaultPhase.invalidated
            : VaultPhase.locked,
        lastUnlock: VaultUnlockStatus.failed,
      );
    }
  }

  /// Reads what's inside again (after something was filed while open).
  Future<void> refresh() async {
    if (state.isOpen) await _load();
  }

  Future<void> lock() async {
    await lockQuietly();
    if (mounted) state = const VaultState();
  }

  Future<void> lockQuietly() async {
    try {
      await _repository.lock();
    } catch (_) {}
  }

  Future<void> updateNote(VaultEntry entry, String? note) async {
    await _repository.updateNote(entry, note);
    if (!mounted) return;
    state = state.copyWith(
      phase: state.phase,
      entries: [
        for (final e in state.entries)
          e.id == entry.id ? e.edited(title: e.title, note: note) : e,
      ],
    );
  }

  Future<void> rename(VaultEntry entry, String? title) async {
    await _repository.rename(entry, title);
    if (!mounted) return;
    state = state.copyWith(
      phase: state.phase,
      entries: [
        for (final e in state.entries)
          e.id == entry.id ? e.edited(title: title, note: e.note) : e,
      ],
    );
  }

  /// Deletes [entry] for good.
  Future<void> delete(VaultEntry entry) async {
    await _repository.delete(entry.id);
    forget(entry);
  }

  /// Drops [entry] from the open list (it has already left the vault).
  void forget(VaultEntry entry) {
    if (!mounted) return;
    state = state.copyWith(
      phase: state.phase,
      entries: state.entries.where((e) => e.id != entry.id).toList(),
    );
  }

  /// Empties the vault once the owner has confirmed it's them. False when
  /// they didn't (cancelled, wrong finger, locked out): nothing is touched.
  Future<bool> reset({required String title, String? subtitle}) async {
    final confirmed = await _repository.confirmOwner(
      title: title,
      subtitle: subtitle,
    );
    if (!confirmed) return false;
    await _repository.reset();
    if (mounted) state = const VaultState();
    return true;
  }
}
