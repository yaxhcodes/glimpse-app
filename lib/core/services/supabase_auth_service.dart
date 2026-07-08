import 'dart:async';
import 'dart:developer' as developer;

import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import 'auth_service.dart';
import 'device_diagnostics_service.dart';
import 'supabase_config.dart';

class SupabaseAuthService implements AuthService {
  SupabaseAuthService._();

  static final SupabaseAuthService instance = SupabaseAuthService._();

  static bool _supabaseInitialized = false;
  static bool _googleInitialized = false;

  final _stateController = StreamController<AppUser?>.broadcast();
  StreamSubscription<AuthState>? _authSubscription;
  AppUser? _currentUser;
  GoogleSignInAccount? _googleHintAccount;

  static const _lastGoogleEmailKey = 'auth.last_google_email';
  static const _lastGoogleDisplayNameKey = 'auth.last_google_display_name';
  static const _lastGooglePhotoUrlKey = 'auth.last_google_photo_url';

  static Future<void> initializeSupabaseClient() async {
    if (_supabaseInitialized || !SupabaseConfig.isConfigured) return;
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    _supabaseInitialized = true;
    instance._startAuthListener();
  }

  SupabaseClient get _client => Supabase.instance.client;

  @override
  bool get isConfigured => SupabaseConfig.isConfigured;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> get authStateChanges => _stateController.stream;

  @override
  Future<AppUser?> restoreSession() async {
    if (!isConfigured) return null;
    final user = _client.auth.currentUser;
    if (user == null) {
      _currentUser = null;
      return null;
    }
    final appUser = _offlineAppUser(user);
    _currentUser = appUser;
    unawaited(_refreshRestoredProfile(user));
    return appUser;
  }

  @override
  Future<GoogleAccountHint?> restoreGoogleAccountHint() async {
    if (!isConfigured) return null;
    return _readStoredGoogleHint();
  }

  @override
  Future<AppUser> signInWithGoogleHint() async {
    _ensureConfigured();
    await _ensureGoogleInitialized();

    try {
      final googleUser =
          _googleHintAccount ??
          await GoogleSignIn.instance.attemptLightweightAuthentication(
            reportAllExceptions: true,
          ) ??
          await GoogleSignIn.instance.authenticate();
      return _signInWithGoogleAccount(googleUser);
    } on AuthFailure {
      rethrow;
    } on GoogleSignInException catch (e, st) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        developer.log('Google hint sign-in cancelled by user', name: 'Auth');
        throw const AuthCancelled();
      }
      developer.log(
        'Google hint sign-in error: ${e.code} ${e.description}',
        name: 'Auth',
        stackTrace: st,
      );
      throw AuthFailure(
        'Google sign-in failed: ${e.description ?? e.code.name}',
        e,
      );
    } catch (e, st) {
      developer.log(
        'Google hint sign-in failed: $e',
        name: 'Auth',
        stackTrace: st,
      );
      throw AuthFailure('Google sign-in failed: $e', e);
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    _ensureConfigured();
    await _ensureGoogleInitialized();

    try {
      final googleUser = await _authenticateWithGoogleUi();
      return _signInWithGoogleAccount(googleUser);
    } on AuthFailure {
      rethrow;
    } on GoogleSignInException catch (e, st) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        developer.log('Google sign-in cancelled by user', name: 'Auth');
        throw const AuthCancelled();
      }
      developer.log(
        'Google Sign-In error: ${e.code} ${e.description}',
        name: 'Auth',
        stackTrace: st,
      );
      throw AuthFailure(
        'Google sign-in failed: ${e.description ?? e.code.name}',
        e,
      );
    } on AuthException catch (e, st) {
      developer.log(
        'Supabase Google token exchange failed: ${e.message}',
        name: 'Auth',
        stackTrace: st,
      );
      throw AuthFailure('Supabase rejected Google sign-in: ${e.message}', e);
    } on PlatformException catch (e, st) {
      developer.log(
        'Google Sign-In platform error: ${e.code} ${e.message}',
        name: 'Auth',
        stackTrace: st,
      );
      throw AuthFailure('Google sign-in failed: ${e.message ?? e.code}', e);
    } catch (e, st) {
      developer.log('Google sign-in failed: $e', name: 'Auth', stackTrace: st);
      throw AuthFailure('Google sign-in failed: $e', e);
    }
  }

  Future<GoogleSignInAccount> _authenticateWithGoogleUi() async {
    final lightweightAuth = GoogleSignIn.instance
        .attemptLightweightAuthentication(reportAllExceptions: true);
    final lightweightUser = lightweightAuth == null
        ? null
        : await lightweightAuth;
    return lightweightUser ?? GoogleSignIn.instance.authenticate();
  }

  Future<AppUser> _signInWithGoogleAccount(
    GoogleSignInAccount googleUser,
  ) async {
    final idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthFailure('Google did not return an identity token.');
    }

    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthFailure('Supabase did not return a signed-in user.');
    }
    final hint = _googleHint(googleUser);
    await _storeGoogleHint(hint);
    final appUser = await _loadOrCreateAppUser(
      user,
      displayNameHint: googleUser.displayName,
      photoUrlHint: googleUser.photoUrl,
    );
    _currentUser = appUser;
    _stateController.add(appUser);
    return appUser;
  }

  @override
  Future<AppUser> signInWithApple() async {
    _ensureConfigured();

    try {
      final rawNonce = generateNonce();
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: rawNonce,
      );
      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthFailure('Apple did not return an identity token.');
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthFailure('Supabase did not return a signed-in user.');
      }

      final name = _joinName(credential.givenName, credential.familyName);
      final appUser = await _loadOrCreateAppUser(user, displayNameHint: name);
      _currentUser = appUser;
      _stateController.add(appUser);
      return appUser;
    } on AuthFailure {
      rethrow;
    } on AuthException catch (e, st) {
      developer.log(
        'Supabase Apple token exchange failed: ${e.message}',
        name: 'Auth',
        stackTrace: st,
      );
      throw AuthFailure('Supabase rejected Apple sign-in: ${e.message}', e);
    } catch (e, st) {
      developer.log('Apple sign-in failed: $e', name: 'Auth', stackTrace: st);
      throw AuthFailure('Apple sign-in failed: $e', e);
    }
  }

  @override
  Future<void> updateLastSeen() async {
    if (!isConfigured) return;
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final diagnostics = await DeviceDiagnosticsService().load();
      final now = DateTime.now().toUtc().toIso8601String();
      await _client.from('profiles').upsert({
        'id': user.id,
        'last_seen': now,
        'platform': diagnostics.platform,
        'app_version': diagnostics.appVersion,
        'build_version': diagnostics.buildVersion,
        'timezone': DateTime.now().timeZoneName,
      });
    } catch (e) {
      developer.log('Auth last_seen update failed — $e', name: 'Auth');
    }
  }

  @override
  Future<AppUser?> markOnboardingCompleted() async {
    if (!isConfigured) return _currentUser;
    final user = _client.auth.currentUser;
    if (user == null) return null;
    await _client
        .from('profiles')
        .update({'onboarding_completed': true})
        .eq('id', user.id);
    final updated = await _loadOrCreateAppUser(user);
    _currentUser = updated;
    _stateController.add(updated);
    return updated;
  }

  @override
  Future<void> signOut() async {
    if (!isConfigured) return;
    final signedInUser = _client.auth.currentUser;
    if (signedInUser != null) {
      await _storeGoogleHint(
        GoogleAccountHint(
          email: signedInUser.email ?? '',
          displayName: _displayNameFromMetadata(signedInUser.userMetadata),
          photoUrl: _photoUrlFromMetadata(signedInUser.userMetadata),
        ),
      );
    }
    _googleHintAccount = null;
    try {
      await _ensureGoogleInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      developer.log('Google sign-out cleanup failed — $e', name: 'Auth');
    }
    await _client.auth.signOut();
    _currentUser = null;
    _stateController.add(null);
  }

  @override
  Future<void> requestAccountDeletion() async {
    _ensureConfigured();
    throw const AuthFailure(
      'Account deletion requires the server deletion endpoint to be enabled.',
    );
  }

  void _startAuthListener() {
    if (_authSubscription != null || !isConfigured) return;
    _authSubscription = _client.auth.onAuthStateChange.listen((state) async {
      final user = state.session?.user;
      if (user == null) {
        _currentUser = null;
        _stateController.add(null);
        return;
      }
      try {
        final appUser = await _loadOrCreateAppUser(user);
        _currentUser = appUser;
        _stateController.add(appUser);
      } catch (e, st) {
        developer.log(
          'Auth state profile load failed — $e',
          name: 'Auth',
          stackTrace: st,
        );
        _currentUser = null;
        _stateController.addError(
          const AuthFailure('Could not load your account profile.'),
        );
      }
    });
  }

  Future<void> _refreshRestoredProfile(User user) async {
    try {
      final appUser = await _loadOrCreateAppUser(user);
      _currentUser = appUser;
      _stateController.add(appUser);
    } catch (e, st) {
      developer.log(
        'Auth profile restore failed — using offline session fallback: $e',
        name: 'Auth',
        stackTrace: st,
      );
    }
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: SupabaseConfig.hasGoogleWebClientId
          ? SupabaseConfig.googleWebClientId
          : null,
    );
    _googleInitialized = true;
  }

  Future<AppUser> _loadOrCreateAppUser(
    User user, {
    String? displayNameHint,
    String? photoUrlHint,
  }) async {
    final diagnostics = await DeviceDiagnosticsService().load();
    final existing = await _fetchProfile(user.id);
    final displayName =
        _profileString(existing, 'display_name') ??
        displayNameHint ??
        _displayNameFromMetadata(user.userMetadata);

    await _client.from('profiles').upsert({
      'id': user.id,
      'display_name': displayName,
      'last_seen': DateTime.now().toUtc().toIso8601String(),
      'platform': diagnostics.platform,
      'app_version': diagnostics.appVersion,
      'build_version': diagnostics.buildVersion,
      'timezone': DateTime.now().timeZoneName,
      if (existing == null) 'onboarding_completed': false,
    });

    final profile = await _fetchProfile(user.id);
    return _mapAppUser(user, profile ?? existing, photoUrlHint: photoUrlHint);
  }

  Future<Map<String, dynamic>?> _fetchProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  AppUser _mapAppUser(
    User user,
    Map<String, dynamic>? profile, {
    String? photoUrlHint,
  }) {
    final createdAt = _date(profile?['created_at']) ?? _date(user.createdAt);
    final diagnosticsProfile = profile ?? const <String, dynamic>{};
    return AppUser(
      id: user.id,
      email: user.email,
      displayName:
          _profileString(diagnosticsProfile, 'display_name') ??
          _displayNameFromMetadata(user.userMetadata),
      photoUrl:
          _trimOrNull(photoUrlHint) ?? _photoUrlFromMetadata(user.userMetadata),
      createdAt: createdAt,
      lastSeen: _date(diagnosticsProfile['last_seen']),
      platform: _profileString(diagnosticsProfile, 'platform') ?? 'unknown',
      appVersion: _profileString(diagnosticsProfile, 'app_version') ?? '',
      buildVersion: _profileString(diagnosticsProfile, 'build_version') ?? '',
      country: _profileString(diagnosticsProfile, 'country'),
      timezone: _profileString(diagnosticsProfile, 'timezone'),
      onboardingCompleted:
          diagnosticsProfile['onboarding_completed'] as bool? ?? false,
    );
  }

  AppUser _offlineAppUser(User user) {
    return AppUser(
      id: user.id,
      email: user.email,
      displayName: _displayNameFromMetadata(user.userMetadata),
      photoUrl: _photoUrlFromMetadata(user.userMetadata),
      createdAt: _date(user.createdAt),
      lastSeen: null,
      platform: 'unknown',
      appVersion: '',
      buildVersion: '',
      onboardingCompleted: true,
    );
  }

  String? _displayNameFromMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;
    for (final key in const ['full_name', 'name', 'display_name']) {
      final value = metadata[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  String? _photoUrlFromMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;
    for (final key in const ['avatar_url', 'picture', 'photo_url']) {
      final value = metadata[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  String? _profileString(Map<String, dynamic>? data, String key) {
    final value = data?[key];
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String? _joinName(String? first, String? last) {
    final parts = [first, last]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(' ');
  }

  GoogleAccountHint _googleHint(GoogleSignInAccount account) {
    return GoogleAccountHint(
      email: account.email,
      displayName: _trimOrNull(account.displayName),
      photoUrl: _trimOrNull(account.photoUrl),
    );
  }

  Future<GoogleAccountHint?> _readStoredGoogleHint() async {
    final prefs = await SharedPreferences.getInstance();
    final email = _trimOrNull(prefs.getString(_lastGoogleEmailKey));
    if (email == null) return null;
    return GoogleAccountHint(
      email: email,
      displayName: _trimOrNull(prefs.getString(_lastGoogleDisplayNameKey)),
      photoUrl: _trimOrNull(prefs.getString(_lastGooglePhotoUrlKey)),
    );
  }

  Future<void> _storeGoogleHint(GoogleAccountHint hint) async {
    if (hint.email.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastGoogleEmailKey, hint.email);
    await _setOptionalString(
      prefs,
      _lastGoogleDisplayNameKey,
      hint.displayName,
    );
    await _setOptionalString(prefs, _lastGooglePhotoUrlKey, hint.photoUrl);
  }

  Future<void> _setOptionalString(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    final trimmed = _trimOrNull(value);
    if (trimmed == null) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, trimmed);
  }

  String? _trimOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  void _ensureConfigured() {
    if (!isConfigured) {
      throw const AuthFailure(
        'Authentication is not configured for this build.',
      );
    }
  }
}
