// KRATOS Mock Authentication Service — Clean Rebuild.
// Provides in-memory auth simulation for local development, tests, and offline runs.

import 'dart:async';
import '../domain/auth_models.dart';
import '../domain/auth_service.dart';

class MockAuthService implements AuthService {
  final _stateController = StreamController<AuthState>.broadcast();
  AuthState _currentState;

  MockAuthService({bool autoAuthenticate = true})
      : _currentState = autoAuthenticate
            ? AuthAuthenticated(KratosUser.devMock())
            : const AuthUnauthenticated();

  @override
  Stream<AuthState> get authStateStream => _stateController.stream;

  @override
  AuthState get currentState => _currentState;

  @override
  KratosUser? get currentUser => switch (_currentState) {
        AuthAuthenticated(user: final u) => u,
        _ => null,
      };

  @override
  Future<void> signInWithGoogle() async {
    _emit(const AuthAuthenticating());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _emit(AuthAuthenticated(KratosUser.devMock(
      displayName: 'Hamza (Google)',
      email: 'hamza@kratos-os.online',
      method: AuthMethod.google,
    )));
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      _emit(const AuthError('Please enter your email.'));
      return;
    }
    if (password.isEmpty) {
      _emit(const AuthError('Please enter your password.'));
      return;
    }

    _emit(const AuthAuthenticating());
    await Future<void>.delayed(const Duration(milliseconds: 50));

    if (password == 'wrong_password' || cleanEmail == 'nonexistent@test.com') {
      _emit(const AuthError('Incorrect email or password.'));
      return;
    }

    _emit(AuthAuthenticated(KratosUser.devMock(
      email: cleanEmail,
      displayName: cleanEmail.contains('@') ? cleanEmail.split('@').first : 'Operative',
      method: AuthMethod.email,
    )));
  }

  @override
  Future<AuthSignUpResult> signUpWithPassword({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final cleanName = fullName.trim();
    final cleanEmail = email.trim();

    _emit(const AuthAuthenticating());
    await Future<void>.delayed(const Duration(milliseconds: 50));

    if (cleanEmail == 'existing@test.com' || cleanEmail == 'duplicate@kratos.dev') {
      _emit(const AuthError('An account with this email already exists. Please sign in instead.'));
      throw Exception('An account with this email already exists. Please sign in instead.');
    }

    final kratosUser = KratosUser.devMock(
      email: cleanEmail,
      displayName: cleanName,
      method: AuthMethod.email,
    );

    _emit(const AuthUnauthenticated());
    return AuthSignUpResult(
      requiresEmailVerification: true,
      email: cleanEmail,
      user: kratosUser,
    );
  }

  @override
  Future<void> verifySignUpOtp({
    required String email,
    required String token,
  }) async {
    final cleanEmail = email.trim();
    final cleanToken = token.trim();

    _emit(const AuthAuthenticating());
    await Future<void>.delayed(const Duration(milliseconds: 50));

    if (cleanToken != '123456') {
      _emit(const AuthError('Invalid or expired code.'));
      throw Exception('Invalid or expired code.');
    }

    _emit(AuthAuthenticated(KratosUser.devMock(
      email: cleanEmail,
      displayName: cleanEmail.contains('@') ? cleanEmail.split('@').first : 'Operative',
      method: AuthMethod.email,
    )));
  }

  @override
  Future<void> resendSignUpOtp({
    required String email,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  Future<void> signInWithDevBypass({
    String userId = 'usr_seed_dev_01',
    String? displayName,
  }) async {
    _emit(AuthAuthenticated(KratosUser.devMock(
      id: userId,
      displayName: displayName ?? 'Dev Operative',
    )));
  }

  @override
  Future<List<String>> getUserIdentities() async {
    final user = currentUser;
    if (user == null) return const [];
    return switch (user.method) {
      AuthMethod.google => ['google'],
      AuthMethod.email => ['email'],
      AuthMethod.developerMock => ['mock'],
    };
  }

  @override
  Future<void> signOut() async {
    _emit(const AuthUnauthenticated());
  }

  @override
  Future<void> resetPasswordForEmail(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    final cleanToken = token.trim();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    if (cleanToken != '123456' && cleanToken != '12345678') {
      _emit(const AuthError('Invalid or expired reset code.'));
      throw Exception('Invalid or expired reset code.');
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _emit(const AuthUnauthenticated());
  }

  @override
  Future<void> completePasswordResetWithOtp({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    await verifyRecoveryOtp(email: email, token: token);
    await updatePassword(newPassword);
  }

  void _emit(AuthState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  @override
  void dispose() {
    _stateController.close();
  }
}
