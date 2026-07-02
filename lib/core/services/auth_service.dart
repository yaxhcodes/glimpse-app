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

class GoogleAccountHint {
  const GoogleAccountHint({
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  final String email;
  final String? displayName;
  final String? photoUrl;
}

abstract interface class AuthService {
  bool get isConfigured;

  AppUser? get currentUser;

  Stream<AppUser?> get authStateChanges;

  Future<AppUser?> restoreSession();

  Future<GoogleAccountHint?> restoreGoogleAccountHint();

  Future<AppUser> signInWithGoogleHint();

  Future<AppUser> signInWithGoogle();

  Future<AppUser> signInWithApple();

  Future<void> updateLastSeen();

  Future<AppUser?> markOnboardingCompleted();

  Future<void> signOut();

  Future<void> requestAccountDeletion();
}
