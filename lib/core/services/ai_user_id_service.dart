import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Generates and persists a stable per-install user ID for the AI proxy.
///
/// On first launch a UUID v4 is generated, stored in SharedPreferences, and
/// reused forever. The ID never changes unless the user clears app data.
///
/// Migration: if an older build stored the ID under the RevenueCat key
/// ([_legacyKey]), it is migrated to the canonical key so the user keeps
/// their established identity.
class AiUserIdService {
  AiUserIdService._();

  static const _key = 'ai_proxy_user_id';
  static const _legacyKey = 'glimpse_rc_app_user_id';
  static const _uuid = Uuid();

  static String? _cached;

  /// Returns the persisted user ID, creating one on first call.
  ///
  /// Thread-safe: concurrent callers will block on the same SharedPreferences
  /// write and all receive the same ID.
  static Future<String> getOrCreateUserId() async {
    if (_cached != null && _cached!.isNotEmpty) return _cached!;

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);

    if (existing != null && existing.isNotEmpty) {
      _cached = existing;
      developer.log('AiUserId: loaded existing ID ${_cached!.substring(0, 8)}...',
          name: 'AiUserId');
      return _cached!;
    }

    // Migration: adopt the legacy RevenueCat key if it exists
    final legacy = prefs.getString(_legacyKey);
    if (legacy != null && legacy.isNotEmpty) {
      await prefs.setString(_key, legacy);
      _cached = legacy;
      developer.log('AiUserId: migrated from legacy key ${legacy.substring(0, 8)}...',
          name: 'AiUserId');
      return _cached!;
    }

    final newId = _uuid.v4();
    await prefs.setString(_key, newId);
    _cached = newId;
    developer.log('AiUserId: generated new ID ${newId.substring(0, 8)}...',
        name: 'AiUserId');
    return _cached!;
  }

  /// Returns the cached ID synchronously, or null if not yet initialised.
  /// Useful for fast-path reads after [getOrCreateUserId] has completed.
  static String? get cachedUserId => _cached;

  /// Clear the cached ID (e.g. for testing). Does NOT remove from storage.
  static void clearCache() {
    _cached = null;
  }
}