import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/dev_auth_service.dart';
import '../services/subscription_service.dart';
import '../services/supabase_config.dart';
import '../services/supabase_auth_service.dart';
import '../config/app_environment.dart';
import 'usage_providers.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  if (!SupabaseConfig.isConfigured && AppEnvironment.isDevContext) {
    return DevAuthService.instance;
  }
  return SupabaseAuthService.instance;
});

final subscriptionIdentityServiceProvider =
    Provider<SubscriptionIdentityService>((ref) {
      return ref.watch(subscriptionServiceProvider);
    });

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);

final googleAccountHintProvider =
    FutureProvider.autoDispose<GoogleAccountHint?>((ref) {
      return ref.watch(authServiceProvider).restoreGoogleAccountHint();
    });

class AuthController extends AsyncNotifier<AppUser?> {
  StreamSubscription<AppUser?>? _authSubscription;
  Future<void> _subscriptionIdentityQueue = Future<void>.value();
  String? _linkedSubscriptionUserId;
  int _authStateRevision = 0;

  @override
  Future<AppUser?> build() async {
    final auth = ref.watch(authServiceProvider);
    _authSubscription = auth.authStateChanges.listen((user) {
      unawaited(_applyAuthUser(user));
    });
    ref.onDispose(() {
      unawaited(_authSubscription?.cancel());
    });

    final user = await auth.restoreSession();
    if (user != null) {
      unawaited(_linkSubscriptionIdentity(user.id));
    }
    return user;
  }

  Future<void> signInWithGoogle() async {
    final auth = ref.read(authServiceProvider);
    try {
      final user = await auth.signInWithGoogle();
      await _applyAuthUser(user);
    } on AuthCancelled {
      await _applyAuthUser(auth.currentUser);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signInWithGoogleHint() async {
    final auth = ref.read(authServiceProvider);
    try {
      final user = await auth.signInWithGoogleHint();
      await _applyAuthUser(user);
    } on AuthCancelled {
      await _applyAuthUser(auth.currentUser);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signInWithApple() async {
    final auth = ref.read(authServiceProvider);
    try {
      final user = await auth.signInWithApple();
      await _applyAuthUser(user);
    } on AuthCancelled {
      await _applyAuthUser(auth.currentUser);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> markOnboardingCompleted() async {
    try {
      final user = await ref
          .read(authServiceProvider)
          .markOnboardingCompleted();
      state = AsyncData(user);
    } catch (e, st) {
      developer.log(
        'Profile onboarding update failed — $e',
        name: 'Auth',
        stackTrace: st,
      );
    }
  }

  Future<void> signOut() async {
    _authStateRevision++;
    _beginSubscriptionIdentityChange();
    _linkedSubscriptionUserId = null;
    ref.read(subscriptionIdentityServiceProvider).clearAuthenticatedUser();
    await ref.read(authServiceProvider).signOut();
    state = const AsyncData(null);
  }

  Future<void> requestAccountDeletion() async {
    _authStateRevision++;
    _beginSubscriptionIdentityChange();
    await ref.read(authServiceProvider).requestAccountDeletion();
    _linkedSubscriptionUserId = null;
    ref.read(subscriptionIdentityServiceProvider).clearAuthenticatedUser();
    state = const AsyncData(null);
  }

  Future<void> _applyAuthUser(AppUser? user) async {
    final revision = ++_authStateRevision;
    if (user == null) {
      _beginSubscriptionIdentityChange();
      _linkedSubscriptionUserId = null;
      ref.read(subscriptionIdentityServiceProvider).clearAuthenticatedUser();
      state = const AsyncData(null);
      return;
    }

    await _linkSubscriptionIdentity(user.id);
    if (revision == _authStateRevision) {
      state = AsyncData(user);
    }
  }

  Future<bool> _linkSubscriptionIdentity(String userId) {
    final queued = _subscriptionIdentityQueue.then((_) async {
      if (_linkedSubscriptionUserId == userId) return true;

      _beginSubscriptionIdentityChange();
      final linked = await ref
          .read(subscriptionIdentityServiceProvider)
          .logInWithAuthenticatedUser(userId);
      if (linked) {
        _linkedSubscriptionUserId = userId;
        ref.invalidate(subscriptionTierProvider);
      } else {
        ref.read(subscriptionTierProvider.notifier).failAccountSwitchClosed();
      }
      ref.read(usageRevisionProvider.notifier).state++;
      return linked;
    });
    _subscriptionIdentityQueue = queued.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        developer.log(
          'Subscription identity queue failed — $error',
          name: 'Auth',
          stackTrace: stackTrace,
        );
      },
    );
    return queued;
  }

  void _beginSubscriptionIdentityChange() {
    ref.read(subscriptionTierProvider.notifier).beginAccountSwitch();
    ref.read(usageRevisionProvider.notifier).state++;
  }
}
