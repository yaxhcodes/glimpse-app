import 'dart:async';

import '../config/app_environment.dart';
import '../models/app_user.dart';
import 'auth_service.dart';

class DevAuthService implements AuthService {
  DevAuthService._();

  static final DevAuthService instance = DevAuthService._();

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;

  static const _devUser = AppUser(
    id: 'local-dev-user',
    email: 'dev@glimpse.local',
    displayName: 'Dev',
    platform: 'dev',
    appVersion: 'dev',
    buildVersion: 'dev',
    onboardingCompleted: true,
  );

  @override
  bool get isConfigured => AppEnvironment.isDevContext;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  @override
  Future<AppUser?> restoreSession() async {
    if (!isConfigured) return null;
    return _currentUser;
  }

  @override
  Future<AppUser> signInWithGoogle() async => _startDevSession();

  @override
  Future<AppUser> signInWithApple() async => _startDevSession();

  Future<AppUser> startDevSession() async => _startDevSession();

  @override
  Future<void> updateLastSeen() async {}

  @override
  Future<AppUser?> markOnboardingCompleted() async {
    _currentUser = (_currentUser ?? _devUser).copyWith(
      onboardingCompleted: true,
    );
    _controller.add(_currentUser);
    return _currentUser;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<void> requestAccountDeletion() async {
    throw const AuthFailure('Account deletion is not available in local dev.');
  }

  AppUser _startDevSession() {
    _currentUser = _devUser;
    _controller.add(_currentUser);
    return _currentUser!;
  }
}
