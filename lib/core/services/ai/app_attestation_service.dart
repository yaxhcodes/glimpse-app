import 'dart:developer' as developer;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../config/app_environment.dart';
import '../../../firebase_options.dart' as prod_options;
import '../../../firebase_options_dev.dart' as dev_options;

/// App attestation for Glimpse's no-login AI proxy.
///
/// Firebase App Check provides Play Integrity on Android release builds and
/// App Attest/DeviceCheck on Apple builds. Debug builds use the debug provider
/// once their debug token is registered in Firebase.
class AppAttestationService {
  AppAttestationService._();

  static const _debugToken = String.fromEnvironment(
    'FIREBASE_APP_CHECK_DEBUG_TOKEN',
  );

  static bool _initialized = false;
  static Future<void>? _initialization;
  static Object? _initError;
  static String? _lastTokenError;

  static bool get isAvailable => _initialized;
  static Object? get initError => _initError;
  static String? get lastTokenError => _lastTokenError;

  static Future<void> initialize() async {
    if (_initialized || _initError != null) return;
    final inProgress = _initialization;
    if (inProgress != null) return inProgress;

    final initialization = _initialize();
    _initialization = initialization;
    await initialization;
  }

  static Future<void> _initialize() async {
    try {
      await Firebase.initializeApp(
        options: AppEnvironment.isDevContext
            ? dev_options.DefaultFirebaseOptions.currentPlatform
            : prod_options.DefaultFirebaseOptions.currentPlatform,
      );
      await FirebaseAppCheck.instance.activate(
        providerAndroid: AppEnvironment.isDevContext
            ? AndroidDebugProvider(
                debugToken: _debugToken.isEmpty ? null : _debugToken,
              )
            : const AndroidPlayIntegrityProvider(),
        providerApple: AppEnvironment.isDevContext
            ? AppleDebugProvider(
                debugToken: _debugToken.isEmpty ? null : _debugToken,
              )
            : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
      _initialized = true;
      _debugLog(
        'App Check initialized (${AppEnvironment.isDevContext ? "debug" : "attested"}, '
        'debugToken=${_debugToken.isEmpty ? "auto" : "provided"})',
      );
    } catch (e, st) {
      _initError = e;
      developer.log(
        'App Check initialization failed: $e',
        name: 'AppAttestation',
        stackTrace: st,
      );
      _debugLog('App Check initialization failed: $e');
    }
  }

  static Future<String?> getToken({bool forceRefresh = false}) async {
    await initialize();
    if (!_initialized) {
      _debugLog(
        'App Check token skipped: not initialized'
        '${_initError != null ? ' ($_initError)' : ''}',
      );
      return null;
    }
    try {
      final token = await FirebaseAppCheck.instance.getToken(forceRefresh);
      _lastTokenError = null;
      _debugLog(
        'App Check token ${token == null || token.isEmpty ? 'EMPTY' : 'OK (${token.length} chars)'}',
      );
      return token;
    } catch (e, st) {
      developer.log(
        'App Check token unavailable: $e',
        name: 'AppAttestation',
        stackTrace: st,
      );
      _lastTokenError = e.toString();
      _debugLog('App Check token unavailable: $e');
      return null;
    }
  }

  static void _debugLog(String message) {
    developer.log(message, name: 'AppAttestation');
    debugPrint('[AppAttestation] $message');
  }
}
