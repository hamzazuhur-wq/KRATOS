// ignore_for_file: public_member_api_docs
// Wave 15: Abstract AuthService interface.
// Follows DI and Riverpod decoupling patterns: UI interacts exclusively through this interface.

import 'auth_models.dart';

abstract class AuthService {
  /// Stream of authentication state changes.
  Stream<AuthState> get authStateStream;

  /// Current authentication state.
  AuthState get currentState;

  /// Current authenticated user, or null if unauthenticated.
  KratosUser? get currentUser;

  /// Sign in via Google OAuth.
  Future<void> signInWithGoogle({String? redirectTo});

  /// Sign in with email and password or magic link.
  Future<void> signInWithEmail(String email, {String? password});

  /// Sign in using instant developer bypass (active in debug/mock modes).
  Future<void> signInWithDevBypass({String? userId, String? displayName});

  /// Sign out current session.
  Future<void> signOut();
}
