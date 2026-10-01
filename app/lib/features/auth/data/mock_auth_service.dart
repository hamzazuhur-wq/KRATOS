// ignore_for_file: public_member_api_docs
// Wave 15: MockAuthService for seamless local development, testing, and vibe coding.
// Avoids blocking developer workflows on external Google OAuth configuration.

import 'dart:async';

import '../domain/auth_models.dart';
import '../domain/auth_service.dart';

class MockAuthService implements AuthService {
  final _stateController = StreamController<AuthState>.broadcast();
  AuthState _currentState;

  MockAuthService({bool autoAuthenticate = true})
    : _currentState = autoAuthenticate
          ? AuthAuthenticated(KratosUser.devMock())
          : const AuthUnauthenticated() {
    // Emit initial state
    Future.microtask(() {
      if (!_stateController.isClosed) _stateController.add(_currentState);
    });
  }

  @override
  bool get isDevBypassEnabled => true;

  @override
  Stream<AuthState> get authStateStream => _stateController.stream;

  @override
  AuthState get currentState => _currentState;

  @override
  bool get hasValidSession => _currentState is AuthAuthenticated;

  @override
  KratosUser? get currentUser {
    final state = _currentState;
    if (state is AuthAuthenticated) return state.user;
    return null;
  }

  @override
  Future<void> signInWithGoogle({String? redirectTo}) async {
    _emit(const AuthLoading('Signing in with Google (Mock)...'));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final user = KratosUser.devMock(
      email: 'hamza@kratos.dev',
      displayName: 'Hamza (Google)',
    );
    _emit(AuthAuthenticated(user));
  }

  @override
  Future<void> signInWithEmail(String email, {String? password}) async {
    _emit(const AuthLoading('Sending verification code...'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<void> verifyEmailOtp(String email, String token) async {
    if (!RegExp(r'^\d{6}$').hasMatch(token.trim())) {
      throw AuthFailure('Enter the 6-digit verification code.');
    }
    final user = KratosUser.devMock(
      email: email,
      displayName: email.split('@').first,
    );
    _emit(AuthAuthenticated(user));
  }

  @override
  Future<void> resendEmailOtp(String email) async {
    await signInWithEmail(email);
  }

  @override
  void cancelEmailOtpAttempt() {}

  @override
  Future<void> signUpWithPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _emit(const AuthLoading('Creating your account...'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // Mock: pretend OTP was sent — UI shows OTP step.
  }

  @override
  Future<void> verifySignUpOtp({
    required String email,
    required String token,
  }) async {
    if (!RegExp(r'^\d{6}$').hasMatch(token.trim())) {
      throw AuthFailure('Enter the 6-digit verification code.');
    }
    final user = KratosUser.devMock(
      email: email,
      displayName: email.split('@').first,
    );
    _emit(AuthAuthenticated(user));
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    _emit(const AuthLoading('Signing in...'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final user = KratosUser.devMock(
      email: email,
      displayName: email.split('@').first,
    );
    _emit(AuthAuthenticated(user));
  }

  @override
  Future<void> signInWithDevBypass({
    String? userId,
    String? displayName,
  }) async {
    _emit(const AuthLoading('Activating dev bypass...'));
    final user = KratosUser.devMock(
      id: userId ?? 'usr_seed_dev_01',
      displayName: displayName ?? 'Dev Operative',
    );
    _emit(AuthAuthenticated(user));
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    // Mock password update simulation
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  @override
  Future<void> signOut() async {
    _emit(const AuthUnauthenticated());
  }

  void _emit(AuthState state) {
    _currentState = state;
    _stateController.add(state);
  }

  void dispose() {
    _stateController.close();
  }
}
