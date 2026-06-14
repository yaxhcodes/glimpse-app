import 'dart:developer' as developer;

import 'package:flutter/services.dart';

/// Reinstall-surviving key/value store for the stable install id.
///
/// Backed by a native bridge over a single [MethodChannel]:
///   - **iOS:** the Keychain, which persists across app uninstall/reinstall.
///   - **Android:** Play Services Block Store, which restores on reinstall via
///     the device's existing Google account (no in-app login involved).
///
/// All operations are best-effort and fail-soft: on any platform without the
/// bridge (tests, desktop) or any native error, [read] returns `null` and
/// [write] is a no-op. Callers must treat a `null` read as "not found" and fall
/// back to their own storage — never as an error.
class DurableIdStore {
  DurableIdStore._();

  static const MethodChannel _channel =
      MethodChannel('com.shinrinyoku.glimpse/stable_id');

  /// Returns the durable id, or `null` if none is stored / the platform has no
  /// bridge / the lookup failed.
  static Future<String?> read() async {
    try {
      final value = await _channel.invokeMethod<String>('read');
      if (value == null || value.isEmpty) return null;
      return value;
    } on MissingPluginException {
      return null;
    } catch (e) {
      developer.log('DurableIdStore.read failed: $e', name: 'DurableIdStore');
      return null;
    }
  }

  /// Persists [id] to the durable store. Best-effort; silently no-ops when the
  /// bridge is unavailable or the write fails.
  static Future<void> write(String id) async {
    if (id.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('write', {'id': id});
    } on MissingPluginException {
      // No native bridge on this platform — nothing to do.
    } catch (e) {
      developer.log('DurableIdStore.write failed: $e', name: 'DurableIdStore');
    }
  }
}
