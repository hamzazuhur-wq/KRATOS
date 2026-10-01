import 'auth_models.dart';

/// Safe, user-facing authentication failure. Raw provider details are not exposed.
class AuthFailure extends StateError {
  AuthFailure(super.message);
}

abstract class AuthService {
  bool get isDevBypassEnabled;

  Stream<AuthState> get authStateStream;
  AuthState get currentState;
  KratosUser? get currentUser;

  /// True only when Supabase has a usable current session.
  bool get hasValidSession;

  Future<void> signInWithGoogle({String? redirectTo});

  /// Sends a passwordless email OTP. This is not a magic-link flow.
  Future<void> signInWithEmail(String email, {String? password});

  Future<void> verifyEmailOtp(String email, String token);

  /// Resends an OTP subject to the service-level cooldown.
  Future<void> resendEmailOtp(String email);

  /// Invalidates a pending email-code attempt without removing server limits.
  void cancelEmailOtpAttempt() {}

  /// Creates a new account with email + password.
  /// Supabase sends a 6-digit OTP to the email; call [verifySignUpOtp] next.
  Future<void> signUpWithPassword({
    required String email,
    required String password,
    required String displayName,
  });

  /// Confirms a sign-up with the 6-digit OTP sent to the email.
  Future<void> verifySignUpOtp({
    required String email,
    required String token,
  });

  /// Signs in with email + password (no OTP step).
  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> signInWithDevBypass({String? userId, String? displayName});
  Future<void> updatePassword(String newPassword);
  Future<void> signOut();
}
