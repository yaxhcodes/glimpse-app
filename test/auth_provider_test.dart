import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/app_user.dart';
import 'package:glimpse/core/providers/auth_provider.dart';
import 'package:glimpse/core/services/auth_service.dart';
import 'package:glimpse/core/services/subscription_service.dart';

void main() {
  test('restored auth resolves before subscription identity linking', () async {
    const restoredUser = AppUser(
      id: 'restored-user',
      email: 'user@example.com',
      platform: 'android',
      appVersion: '1.0.0',
      buildVersion: '1',
      onboardingCompleted: true,
    );
    final authService = _RestoringAuthService(restoredUser);
    final identityService = _PendingSubscriptionIdentityService();
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        subscriptionIdentityServiceProvider.overrideWithValue(identityService),
        subscriptionTierProvider.overrideWith(
          _TestSubscriptionTierNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final user = await container
        .read(authControllerProvider.future)
        .timeout(const Duration(seconds: 1));

    expect(user, same(restoredUser));
    await identityService.started.timeout(const Duration(seconds: 1));
    expect(identityService.userId, restoredUser.id);
    expect(identityService.isPending, isTrue);

    identityService.complete(true);
  });
}

class _RestoringAuthService implements AuthService {
  _RestoringAuthService(this._user);

  final AppUser? _user;

  @override
  Stream<AppUser?> get authStateChanges => const Stream.empty();

  @override
  AppUser? get currentUser => _user;

  @override
  bool get isConfigured => true;

  @override
  Future<AppUser?> restoreSession() async => _user;

  @override
  Future<GoogleAccountHint?> restoreGoogleAccountHint() async => null;

  @override
  Future<AppUser> signInWithApple() => throw UnimplementedError();

  @override
  Future<AppUser> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<AppUser> signInWithGoogleHint() => throw UnimplementedError();

  @override
  Future<AppUser?> markOnboardingCompleted() => throw UnimplementedError();

  @override
  Future<void> requestAccountDeletion() => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<void> updateLastSeen() => throw UnimplementedError();
}

class _PendingSubscriptionIdentityService
    implements SubscriptionIdentityService {
  final _started = Completer<void>();
  final _result = Completer<bool>();

  Future<void> get started => _started.future;
  bool get isPending => !_result.isCompleted;
  String? userId;

  @override
  void clearAuthenticatedUser() {}

  @override
  Future<bool> logInWithAuthenticatedUser(String userId) {
    this.userId = userId;
    if (!_started.isCompleted) {
      _started.complete();
    }
    return _result.future;
  }

  void complete(bool linked) {
    if (!_result.isCompleted) {
      _result.complete(linked);
    }
  }
}

class _TestSubscriptionTierNotifier extends SubscriptionTierNotifier {
  @override
  Future<SubscriptionTier> build() async => SubscriptionTier.free;
}
