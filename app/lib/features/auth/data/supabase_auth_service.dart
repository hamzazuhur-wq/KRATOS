// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../domain/ids.dart';
import '../domain/auth_models.dart';
import '../domain/auth_service.dart';

class SupabaseAuthService implements AuthService {
  final SupabaseClient _client;
  final _stateController = StreamController<AuthState>.broadcast();
  late final StreamSubscription<dynamic> _sub;
  AuthState _currentState = const AuthUnauthenticated();
  DateTime? _lastOtpRequestAt;
  bool _otpRequestInFlight = false;

  static const _otpCooldown = Duration(seconds: 60);

  SupabaseAuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client {
    _restoreCurrentSession();
    _sub = _client.auth.onAuthStateChange.map((data) {
      final session = data.session;
      if (session == null) return const AuthUnauthenticated();
      return _authenticatedState(session.user);
    }).listen(
      _emit,
      onError: (Object error, StackTrace stack) {
        // ignore: avoid_print
        print('[SupabaseAuthService] auth stream error: $error\n$stack');
        _emit(const AuthUnauthenticated());
      },
    );
  }

  void _restoreCurrentSession() {
    final session = _client.auth.currentSession;
    _currentState = session == null
        ? const AuthUnauthenticated()
        : _authenticatedState(session.user);
    scheduleMicrotask(() {
      if (!_stateController.isClosed) _stateController.add(_currentState);
    });
  }

  static AuthAuthenticated _authenticatedState(User user) {
    final provider = user.appMetadata['provider'] as String?;
    return AuthAuthenticated(
      KratosUser(
        id: Id(user.id),
        email: user.email ?? 'unknown@kratos.app',
        displayName: user.userMetadata?['full_name'] as String?,
        avatarUrl: user.userMetadata?['avatar_url'] as String?,
        method: provider == 'google' ? AuthMethod.google : AuthMethod.email,
        createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now().toUtc(),
      ),
    );
  }

  @override
  bool get isDevBypassEnabled => false;

  @override
  Stream<AuthState> get authStateStream => _stateController.stream;

  @override
  AuthState get currentState => _currentState;

  @override
  KratosUser? get currentUser => _currentState is AuthAuthenticated
      ? (_currentState as AuthAuthenticated).user
      : null;

  @override
  bool get hasValidSession => _client.auth.currentSession != null;

  @override
  Future<void> signInWithGoogle({String? redirectTo}) async {
    try {
      _emit(const AuthLoading('Signing in with Google...'));
      // On web, explicitly set redirectTo to the current origin so PKCE code
      // exchange always resolves at the correct URL registered in Google Cloud
      // Console. Without this, the code verifier stored in sessionStorage may
      // not survive a cross-origin redirect, causing a silent auth failure.
      final defaultRedirect = kIsWeb
          ? Uri.base.origin // e.g. https://kratos-os.online
          : 'io.supabase.kratos://login-callback';
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo ?? defaultRedirect,
      );
    } catch (error) {
      _fail(_friendlyError(error, 'Google sign-in failed.'));
    }
  }

  @override
  Future<void> signInWithEmail(String email, {String? password}) async {
    // Passwords are intentionally not part of the production UX.
    await _requestOtp(email);
  }

  @override
  Future<void> resendEmailOtp(String email) async {
    await _requestOtp(email);
  }

  Future<void> _requestOtp(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (_otpRequestInFlight) {
      throw AuthFailure('A verification code is already being sent.');
    }
    final last = _lastOtpRequestAt;
    if (last != null) {
      final remaining = _otpCooldown - DateTime.now().difference(last);
      if (remaining > Duration.zero) {
        throw AuthFailure('Please wait before requesting another code.');
      }
    }
    _otpRequestInFlight = true;
    try {
      _emit(const AuthLoading('Sending verification code...'));
      await _client.auth.signInWithOtp(email: normalizedEmail);
      _lastOtpRequestAt = DateTime.now();
    } catch (error) {
      _fail(_friendlyError(error, 'Could not send the verification code.'));
    } finally {
      _otpRequestInFlight = false;
    }
  }

  @override
  Future<void> verifyEmailOtp(String email, String token) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedToken = token.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalizedToken)) {
      throw AuthFailure('Enter the 6-digit verification code.');
    }
    try {
      _emit(const AuthLoading('Verifying code...'));
      final response = await _client.auth.verifyOTP(
        email: normalizedEmail,
        token: normalizedToken,
        type: OtpType.email,
      );
      if (response.session == null || _client.auth.currentSession == null) {
        throw AuthFailure('The code was accepted but no session was created.');
      }
    } catch (error) {
      _fail(_friendlyError(error, 'The code is invalid or expired.'));
    }
  }

  String _friendlyError(Object error, String fallback) {
    if (error is AuthFailure) return error.message;
    final text = error.toString().toLowerCase();
    if (text.contains('rate') || text.contains('too many') || text.contains('429')) {
      return 'Too many attempts. Please wait and try again.';
    }
    if (text.contains('expired')) return 'This code has expired. Request a new one.';
    if (text.contains('invalid') || text.contains('otp')) return 'The code is invalid or expired.';
    if (text.contains('network') || text.contains('socket')) return 'Network unavailable. Try again when you are online.';
    return fallback;
  }

  void _fail(String message) {
    _currentState = AuthError(message);
    _stateController.add(_currentState);
    throw AuthFailure(message);
  }

  void _emit(AuthState state) {
    _currentState = state;
    if (!_stateController.isClosed) _stateController.add(state);
  }

  @override
  Future<void> signInWithDevBypass({String? userId, String? displayName}) async {
    throw AuthFailure('Developer sign-in is disabled in production.');
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } catch (error) {
      _fail(_friendlyError(error, 'Password update failed.'));
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    _emit(const AuthUnauthenticated());
  }

  Future<void> dispose() async {
    await _sub.cancel();
    await _stateController.close();
  }
}
