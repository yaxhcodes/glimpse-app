import '../models/app_user.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class AuthCancelled implements Exception {
  const AuthCancelled();
}

abstract interface class AuthService {
  bool get isConfigured;

  AppUser? get currentUser;

  Stream<AppUser?> get authStateChanges;

  Future<AppUser?> restoreSession();

  Future<AppUser> signInWithGoogle();

  Future<AppUser> signInWithApple();

  Future<void> updateLastSeen();

  Future<AppUser?> markOnboardingCompleted();

  Future<void> signOut();

  Future<void> requestAccountDeletion();
}
