// KRATOS Authentication Service Interface — Clean Rebuild.
// Defines contract for authentication, session lifecycle, Google OAuth, and Email sign-in.

import 'auth_models.dart';

abstract class AuthService {
  /// Stream of authentication state transitions.
  Stream<AuthState> get authStateStream;

  /// Current authentication state.
  AuthState get currentState;

  /// Authenticated user, or null if unauthenticated.
  KratosUser? get currentUser;

  /// Initiates Google OAuth using official Supabase SDK.
  Future<void> signInWithGoogle();

  /// Authenticates using email and password via Supabase Auth.
  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  /// Creates a new Supabase account with full name, email, and password.
  Future<AuthSignUpResult> signUpWithPassword({
    required String fullName,
    required String email,
    required String password,
  });

  /// Verifies a 6-digit signup OTP code for an email address.
  Future<void> verifySignUpOtp({
    required String email,
    required String token,
  });

  /// Resends a signup verification code to an email address.
  Future<void> resendSignUpOtp({
    required String email,
  });

  /// Retrieves the list of linked authentication providers for the current user.
  Future<List<String>> getUserIdentities();

  /// Sends a password reset recovery email or OTP to the user.
  Future<void> resetPasswordForEmail(String email);

  /// Verifies a recovery OTP token and creates a session for resetting password.
  Future<void> verifyRecoveryOtp({
    required String email,
    required String token,
  });

  /// Signs out of current Supabase session.
  Future<void> signOut();

  /// Updates password for authenticated user (if supported).
  Future<void> updatePassword(String newPassword);

  /// Verifies a 6-digit recovery OTP, updates the user's password, and signs out
  /// cleanly so the user can sign in with their new credentials.
  Future<void> completePasswordResetWithOtp({
    required String email,
    required String token,
    required String newPassword,
  });

  /// Disposes stream controllers and subscriptions.
  void dispose();
}
