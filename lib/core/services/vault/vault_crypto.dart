import 'package:flutter/services.dart';

/// How an unlock attempt ended.
enum VaultUnlockStatus {
  ok,
  cancelled,
  failed,

  /// Too many wrong attempts; the phone's own lockout is in force.
  lockout,

  /// The phone has no screen lock, so there is nothing to lock with.
  noScreenLock,

  /// The screen lock was removed at some point, and Android destroyed the
  /// vault's key with it. What's inside can never be opened again.
  invalidated,
}

class VaultUnlockResult {
  const VaultUnlockResult(this.status, {this.wrappedDataKey});

  final VaultUnlockStatus status;

  /// Set on the very first unlock: the newly made data key, wrapped, for
  /// the caller to keep.
  final Uint8List? wrappedDataKey;
}

/// What the Keystore currently says about the vault.
class VaultDeviceStatus {
  const VaultDeviceStatus({
    required this.hasScreenLock,
    required this.keyInvalidated,
  });

  final bool hasScreenLock;
  final bool keyInvalidated;
}

/// Thrown when sealing can't happen: [code] is `no_screen_lock`,
/// `invalidated`, `locked` or `failed`.
class VaultCryptoException implements Exception {
  const VaultCryptoException(this.code);

  final String code;

  @override
  String toString() => 'VaultCryptoException($code)';
}

/// The vault's lock. Android holds the key (see `VaultBridge.kt`); Glimpse
/// only ever sees sealed bytes, and opened ones while the vault is unlocked.
abstract class VaultCrypto {
  Future<VaultDeviceStatus> status();

  /// Seals [plain]. Works while locked, so the share sheet can file into
  /// the vault without asking for a fingerprint.
  Future<Uint8List> seal(Uint8List plain);

  /// Shows the phone's own fingerprint / face / screen-lock prompt.
  Future<VaultUnlockResult> unlock({
    required String title,
    String? subtitle,
    Uint8List? wrappedDataKey,
  });

  /// Asks the person to prove who they are, without using the vault's key:
  /// for a reset, which must still work once the key is gone.
  Future<VaultUnlockStatus> confirm({required String title, String? subtitle});

  /// Opens each of [sealed]; null where one can't be opened. Unlocked only.
  Future<List<Uint8List?>> open(List<Uint8List> sealed);

  /// Forgets the open vault's key.
  Future<void> lock();

  /// Destroys the key for good.
  Future<void> reset();

  /// Keeps the screen out of screenshots and the recent-apps preview.
  Future<void> setSecureScreen(bool secure);
}

class PlatformVaultCrypto implements VaultCrypto {
  const PlatformVaultCrypto();

  static const _channel = MethodChannel('com.shinrinyoku.glimpse/vault');

  @override
  Future<VaultDeviceStatus> status() async {
    final result = await _channel.invokeMapMethod<String, Object?>('status');
    return VaultDeviceStatus(
      hasScreenLock: result?['screenLock'] == true,
      keyInvalidated: result?['key'] == 'invalidated',
    );
  }

  @override
  Future<Uint8List> seal(Uint8List plain) async {
    try {
      final sealed = await _channel.invokeMethod<Uint8List>('seal', {
        'plain': plain,
      });
      if (sealed == null) throw const VaultCryptoException('failed');
      return sealed;
    } on PlatformException catch (error) {
      throw VaultCryptoException(error.code);
    }
  }

  @override
  Future<VaultUnlockResult> unlock({
    required String title,
    String? subtitle,
    Uint8List? wrappedDataKey,
  }) async {
    final result = await _channel.invokeMapMethod<String, Object?>('unlock', {
      'title': title,
      'subtitle': subtitle,
      'wrappedDataKey': wrappedDataKey,
    });
    final status = switch (result?['status']) {
      'ok' => VaultUnlockStatus.ok,
      'cancelled' => VaultUnlockStatus.cancelled,
      'lockout' => VaultUnlockStatus.lockout,
      'no_screen_lock' => VaultUnlockStatus.noScreenLock,
      'invalidated' => VaultUnlockStatus.invalidated,
      _ => VaultUnlockStatus.failed,
    };
    return VaultUnlockResult(
      status,
      wrappedDataKey: result?['wrappedDataKey'] as Uint8List?,
    );
  }

  @override
  Future<VaultUnlockStatus> confirm({
    required String title,
    String? subtitle,
  }) async {
    final status = await _channel.invokeMethod<String>('confirm', {
      'title': title,
      'subtitle': subtitle,
    });
    return switch (status) {
      'ok' => VaultUnlockStatus.ok,
      'cancelled' => VaultUnlockStatus.cancelled,
      'lockout' => VaultUnlockStatus.lockout,
      'no_screen_lock' => VaultUnlockStatus.noScreenLock,
      _ => VaultUnlockStatus.failed,
    };
  }

  @override
  Future<List<Uint8List?>> open(List<Uint8List> sealed) async {
    if (sealed.isEmpty) return const [];
    try {
      final opened = await _channel.invokeListMethod<Object?>('open', {
        'sealed': sealed,
      });
      return [for (final item in opened ?? const []) item as Uint8List?];
    } on PlatformException catch (error) {
      throw VaultCryptoException(error.code);
    }
  }

  @override
  Future<void> lock() => _channel.invokeMethod<void>('lock');

  @override
  Future<void> reset() => _channel.invokeMethod<void>('reset');

  @override
  Future<void> setSecureScreen(bool secure) async {
    try {
      await _channel.invokeMethod<void>('setSecure', {'secure': secure});
    } on MissingPluginException {
      // Not on Android (tests, desktop): nothing to protect.
    }
  }
}
