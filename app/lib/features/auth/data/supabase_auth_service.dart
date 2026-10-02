// KRATOS Supabase Authentication Service — Clean Rebuild.
// Uses official Supabase Flutter SDK (v2.17.2) for Google OAuth, Email/Password sign-in, and session persistence.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../domain/auth_models.dart';
import '../domain/auth_service.dart';

class SupabaseAuthService implements AuthService {
  final supa.SupabaseClient _client;
  final _stateController = StreamController<AuthState>.broadcast();
  StreamSubscription<supa.AuthState>? _authSubscription;
  AuthState _currentState = const AuthInitializing();

  bool _isResettingPassword = false;

  SupabaseAuthService({supa.SupabaseClient? client})
      : _client = client ?? supa.Supabase.instance.client {
    // Check if session is already active in client memory
    final initialSession = _client.auth.currentSession;
    if (initialSession != null) {
      _currentState = AuthAuthenticated(KratosUser.fromSupabase(initialSession.user));
    }

    // Subscribe to official Supabase auth state change stream.
    // SupabaseAuth handles deep links on mobile and initial URI on web automatically.
    _authSubscription = _client.auth.onAuthStateChange.listen(
      (data) {
        _handleAuthChangeEvent(data.event, data.session);
      },
      onError: (error) {
        // Transient network/stream errors must NOT log out an active session.
        if (_client.auth.currentSession != null) return;
        _emit(const AuthError('Authentication error occurred. Please try again.'));
      },
    );
  }

  void _handleAuthChangeEvent(supa.AuthChangeEvent event, supa.Session? session) {
    if (event == supa.AuthChangeEvent.passwordRecovery || _isResettingPassword) {
      // Suppress emitting AuthAuthenticated during recovery so user is not
      // prematurely routed to the main app dashboard before setting their new password
      // and returning to the sign-in screen.
      return;
    }

    if (session != null) {
      _emit(AuthAuthenticated(KratosUser.fromSupabase(session.user)));
      return;
    }

    switch (event) {
      case supa.AuthChangeEvent.signedOut:
        _emit(const AuthUnauthenticated());
      case supa.AuthChangeEvent.initialSession:
        // No persisted session restored
        if (_currentState is! AuthAuthenticated) {
          _emit(const AuthUnauthenticated());
        }
      default:
        if (_client.auth.currentSession == null && _currentState is! AuthError) {
          _emit(const AuthUnauthenticated());
        }
    }
  }

  @override
  Stream<AuthState> get authStateStream => _stateController.stream;

  @override
  AuthState get currentState => _currentState;

  @override
  KratosUser? get currentUser {
    final session = _client.auth.currentSession;
    if (session != null) {
      return KratosUser.fromSupabase(session.user);
    }
    if (_currentState is AuthAuthenticated) {
      return (_currentState as AuthAuthenticated).user;
    }
    return null;
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      _emit(const AuthAuthenticating());

      // Canonical redirect targets:
      // Web: exact canonical production origin
      // Mobile: registered custom URL scheme deep link
      final redirectUrl = kIsWeb
          ? 'https://kratos-os.online/'
          : 'io.supabase.kratos://login-callback/';

      await _client.auth.signInWithOAuth(
        supa.OAuthProvider.google,
        redirectTo: redirectUrl,
      );
    } catch (e) {
      // If a valid session exists, remain authenticated
      if (_client.auth.currentSession != null) {
        _emit(AuthAuthenticated(KratosUser.fromSupabase(_client.auth.currentSession!.user)));
        return;
      }
      _emit(const AuthError('Unable to complete Google sign-in. Please try again.'));
    }
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

    try {
      _emit(const AuthAuthenticating());
      final response = await _client.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );

      final session = response.session ?? _client.auth.currentSession;
      if (session == null) {
        // Unverified email or empty session: do not grant access
        _emit(const AuthError('Please verify your email before signing in.'));
        return;
      }

      _emit(AuthAuthenticated(KratosUser.fromSupabase(session.user)));
    } on supa.AuthException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('confirm') || message.contains('not verified')) {
        _emit(const AuthError('Please verify your email before signing in.'));
      } else {
        // Uniform safe error message to prevent account enumeration
        _emit(const AuthError('Incorrect email or password.'));
      }
    } catch (e) {
      debugPrint('[KRATOS] Sign in error: $e');
      _emit(const AuthError('Unable to connect to server. Please check your internet connection.'));
    }
  }

  @override
  Future<AuthSignUpResult> signUpWithPassword({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final cleanName = fullName.trim();
    final cleanEmail = email.trim();

    try {
      final response = await _client.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {'full_name': cleanName},
      );

      final session = response.session;
      final user = response.user;

      if (session != null) {
        final kratosUser = KratosUser.fromSupabase(user ?? session.user);
        _emit(AuthAuthenticated(kratosUser));
        return AuthSignUpResult(
          requiresEmailVerification: false,
          email: cleanEmail,
          user: kratosUser,
        );
      }

      // Supabase anti-enumeration protection:
      // When a user already exists, Supabase returns a dummy user object with empty identities
      // and does NOT send an email! We detect this and guide the user to Sign In or Reset Password.
      if (user != null && (user.identities == null || user.identities!.isEmpty)) {
        const errorMsg = 'An account with this email already exists. Please sign in or reset your password.';
        _emit(const AuthError(errorMsg));
        throw const supa.AuthException(errorMsg);
      }

      // Email confirmation required for newly registered account.
      // We remain unauthenticated without disrupting UI state.
      return AuthSignUpResult(
        requiresEmailVerification: true,
        email: cleanEmail,
        user: user != null ? KratosUser.fromSupabase(user) : null,
      );
    } on supa.AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') ||
          msg.contains('user already exists') ||
          msg.contains('already in use')) {
        _emit(const AuthError('An account with this email already exists. Please sign in instead.'));
        throw const supa.AuthException('An account with this email already exists. Please sign in instead.');
      }
      _emit(const AuthError('Unable to create account. Please check your details or try again.'));
      throw const supa.AuthException('Unable to create account. Please check your details or try again.');
    }
  }

  @override
  Future<void> verifySignUpOtp({
    required String email,
    required String token,
  }) async {
    final cleanEmail = email.trim();
    final cleanToken = token.trim();

    try {
      _emit(const AuthAuthenticating());
      final response = await _client.auth.verifyOTP(
        email: cleanEmail,
        token: cleanToken,
        type: supa.OtpType.signup,
      );

      final session = response.session ?? _client.auth.currentSession;
      if (session == null) {
        _emit(const AuthError('Invalid or expired code.'));
        throw const supa.AuthException('Invalid or expired code.');
      }

      _emit(AuthAuthenticated(KratosUser.fromSupabase(session.user)));
    } on supa.AuthException catch (_) {
      _emit(const AuthError('Invalid or expired code.'));
      throw const supa.AuthException('Invalid or expired code.');
    } catch (_) {
      _emit(const AuthError('Invalid or expired code.'));
      throw const supa.AuthException('Invalid or expired code.');
    }
  }

  @override
  Future<void> resendSignUpOtp({
    required String email,
  }) async {
    final cleanEmail = email.trim();
    try {
      await _client.auth.resend(
        email: cleanEmail,
        type: supa.OtpType.signup,
      );
    } on supa.AuthException catch (e) {
      throw supa.AuthException(e.message);
    } catch (_) {
      throw const supa.AuthException('Unable to resend verification code. Please try again.');
    }
  }

  @override
  Future<List<String>> getUserIdentities() async {
    try {
      final identities = await _client.auth.getUserIdentities();
      return identities.map((i) => i.provider).toSet().toList();
    } catch (_) {
      final user = _client.auth.currentUser;
      if (user != null && user.identities != null) {
        return user.identities!.map((i) => i.provider).toSet().toList();
      }
      return const [];
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Ignored to ensure clean local transition
    } finally {
      _emit(const AuthUnauthenticated());
    }
  }

  @override
  Future<void> resetPasswordForEmail(String email) async {
    final cleanEmail = email.trim();
    try {
      final redirectUrl = kIsWeb
          ? 'https://kratos-os.online/'
          : 'io.supabase.kratos://login-callback/';

      await _client.auth.resetPasswordForEmail(
        cleanEmail,
        redirectTo: redirectUrl,
      );
    } on supa.AuthException catch (e) {
      throw supa.AuthException(e.message);
    } catch (_) {
      throw const supa.AuthException('Unable to send reset email. Please try again.');
    }
  }

  @override
  Future<void> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    final cleanEmail = email.trim();
    final cleanToken = token.trim();

    _isResettingPassword = true;
    try {
      supa.AuthResponse response;
      try {
        response = await _client.auth.verifyOTP(
          email: cleanEmail,
          token: cleanToken,
          type: supa.OtpType.recovery,
        );
      } catch (_) {
        // Fallback to OtpType.email in case OTP was issued via email OTP flow
        response = await _client.auth.verifyOTP(
          email: cleanEmail,
          token: cleanToken,
          type: supa.OtpType.email,
        );
      }

      final session = response.session ?? _client.auth.currentSession;
      if (session == null) {
        throw const supa.AuthException('Invalid or expired reset code.');
      }
      // Note: We deliberately do NOT emit AuthAuthenticated here,
      // so the user remains on the ResetPasswordScreen to enter their new password.
    } on supa.AuthException catch (e) {
      _isResettingPassword = false;
      throw supa.AuthException(e.message);
    } catch (_) {
      _isResettingPassword = false;
      throw const supa.AuthException('Invalid or expired reset code.');
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(supa.UserAttributes(password: newPassword));
      // Once password is saved in DB, sign out of the temporary recovery session
      await _client.auth.signOut();
    } on supa.AuthException catch (e) {
      throw supa.AuthException(e.message);
    } catch (_) {
      throw const supa.AuthException('Failed to update password. Please try again.');
    } finally {
      _isResettingPassword = false;
      _emit(const AuthUnauthenticated());
    }
  }

  @override
  Future<void> completePasswordResetWithOtp({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim();
    final cleanToken = token.trim();

    _isResettingPassword = true;
    try {
      supa.AuthResponse response;
      try {
        response = await _client.auth.verifyOTP(
          email: cleanEmail,
          token: cleanToken,
          type: supa.OtpType.recovery,
        );
      } catch (_) {
        // Fallback if token was generated under email type
        response = await _client.auth.verifyOTP(
          email: cleanEmail,
          token: cleanToken,
          type: supa.OtpType.email,
        );
      }

      final session = response.session ?? _client.auth.currentSession;
      if (session == null) {
        throw const supa.AuthException('Invalid or expired reset code.');
      }

      // Update password for currently verified recovery session
      await _client.auth.updateUser(supa.UserAttributes(password: newPassword));

      // Terminate temporary recovery session cleanly
      await _client.auth.signOut();
    } on supa.AuthException {
      rethrow;
    } catch (_) {
      throw const supa.AuthException('Failed to complete password reset. Please try again.');
    } finally {
      _isResettingPassword = false;
      _emit(const AuthUnauthenticated());
    }
  }

  void _emit(AuthState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    _stateController.close();
  }
}
