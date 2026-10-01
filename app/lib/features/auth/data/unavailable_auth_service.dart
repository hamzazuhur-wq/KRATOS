import '../domain/auth_models.dart';
import '../domain/auth_service.dart';

/// Fails closed when the runtime has no usable identity provider.
class UnavailableAuthService implements AuthService {
  const UnavailableAuthService();

  @override
  bool get isDevBypassEnabled => true;

  StateError _error() => StateError('Authentication is not configured.');

  @override
  Stream<AuthState> get authStateStream => const Stream.empty();

  @override
  AuthState get currentState => const AuthUnauthenticated();

  @override
  KratosUser? get currentUser => null;

  @override
  bool get hasValidSession => false;

  @override
  Future<void> signInWithDevBypass({
    String? userId,
    String? displayName,
  }) async {
    // Graceful dev bypass fallback
  }

  @override
  Future<void> signInWithEmail(String email, {String? password}) async =>
      throw _error();

  @override
  Future<void> verifyEmailOtp(String email, String token) async =>
      throw _error();

  @override
  Future<void> resendEmailOtp(String email) async => throw _error();

  @override
  void cancelEmailOtpAttempt() {}

  @override
  Future<void> signInWithGoogle({String? redirectTo}) async => throw _error();

  @override
  Future<void> updatePassword(String newPassword) async => throw _error();

  @override
  Future<void> signUpWithPassword({
    required String email,
    required String password,
    required String displayName,
  }) async =>
      throw _error();

  @override
  Future<void> verifySignUpOtp({
    required String email,
    required String token,
  }) async =>
      throw _error();

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async =>
      throw _error();

  @override
  Future<void> signOut() async {}
}
