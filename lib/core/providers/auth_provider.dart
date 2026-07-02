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

final authServiceProvider = Provider<AuthService>((ref) {
  if (!SupabaseConfig.isConfigured && AppEnvironment.isDevContext) {
    return DevAuthService.instance;
  }
  return SupabaseAuthService.instance;
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

  @override
  Future<AppUser?> build() async {
    final auth = ref.watch(authServiceProvider);
    _authSubscription = auth.authStateChanges.listen((user) {
      state = AsyncData(user);
      if (user != null) {
        unawaited(_linkSubscriptionIdentity(user.id));
      }
    });
    ref.onDispose(() {
      unawaited(_authSubscription?.cancel());
    });

    final user = await auth.restoreSession();
    if (user != null) {
      await _linkSubscriptionIdentity(user.id);
    }
    return user;
  }

  Future<void> signInWithGoogle() async {
    final auth = ref.read(authServiceProvider);
    try {
      final user = await auth.signInWithGoogle();
      await _linkSubscriptionIdentity(user.id);
      state = AsyncData(user);
    } on AuthCancelled {
      state = AsyncData(auth.currentUser);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signInWithGoogleHint() async {
    final auth = ref.read(authServiceProvider);
    try {
      final user = await auth.signInWithGoogleHint();
      await _linkSubscriptionIdentity(user.id);
      state = AsyncData(user);
    } on AuthCancelled {
      state = AsyncData(auth.currentUser);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signInWithApple() async {
    final auth = ref.read(authServiceProvider);
    try {
      final user = await auth.signInWithApple();
      await _linkSubscriptionIdentity(user.id);
      state = AsyncData(user);
    } on AuthCancelled {
      state = AsyncData(auth.currentUser);
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
    SubscriptionService.instance.clearAuthenticatedUser();
    await ref.read(authServiceProvider).signOut();
    state = const AsyncData(null);
  }

  Future<void> requestAccountDeletion() {
    return ref.read(authServiceProvider).requestAccountDeletion();
  }

  Future<void> _linkSubscriptionIdentity(String userId) async {
    await SubscriptionService.instance.logInWithAuthenticatedUser(userId);
    ref.invalidate(subscriptionTierProvider);
  }
}
