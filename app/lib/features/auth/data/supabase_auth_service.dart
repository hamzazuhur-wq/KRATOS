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
  final List<DateTime> _otpRequestStarts = [];
  final Map<String, DateTime> _lastOtpRequestAtByEmail = {};
  int _nextOtpRequestId = 0;
  int? _activeOtpRequestId;
  int _inFlightOtpRequests = 0;

  static const _otpCooldown = Duration(seconds: 60);
  static const _maxOtpRequestsPerWindow = 2;

  SupabaseAuthService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client {
    // On web, we start with AuthLoading because Supabase's deeplink observer
    // (_handleInitialUri) may still be in-flight when this constructor runs.
    // The onAuthStateChange stream will emit either initialSession (no session)
    // or signedIn (OAuth callback) once deeplink processing completes.
    // On other platforms, restore synchronously from the cached session.
    if (kIsWeb) {
      _currentState = const AuthLoading('Restoring session...');
    } else {
      _restoreCurrentSession();
    }
    _sub = _client.auth.onAuthStateChange
        .listen(
          (data) {
            print('[AUTH-TRACE] auth event: ');
            final event = data.event;
            final session = data.session;
            // initialSession fires once at startup — it tells us whether
            // a persisted or OAuth-callback session exists.
            if (event == AuthChangeEvent.initialSession ||
                event == AuthChangeEvent.signedIn ||
                event == AuthChangeEvent.tokenRefreshed ||
                event == AuthChangeEvent.userUpdated) {
              if (session != null) {
                _emit(_authenticatedState(session.user));
              } else {
                _emit(const AuthUnauthenticated());
              }
            } else if (event == AuthChangeEvent.signedOut) {
              _emit(const AuthUnauthenticated());
            }
            // Ignore mfaChallengeVerified and passwordRecovery events here.
          },
          onError: (Object error, StackTrace stack) {
            // ignore: avoid_print
            print('[SupabaseAuthService] auth stream error: $error\n$stack');
            _emit(const AuthUnauthenticated());
          },
        );
    // On web: if Supabase has already emitted its initialSession event
    // synchronously before our subscription was set up (edge case), fall
    // back to reading currentSession after a microtask delay.
    if (kIsWeb) {
      scheduleMicrotask(() {
        if (_currentState is AuthLoading) {
          _restoreCurrentSession();
        }
      });
    }
  }

  void _restoreCurrentSession() {
    print('[AUTH-TRACE] _restoreCurrentSession() called');
    final session = _client.auth.currentSession;
    _currentState = session == null
        ? const AuthUnauthenticated()
        : _authenticatedState(session.user);
    if (!_stateController.isClosed) _stateController.add(_currentState);
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
      final isMobile =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      // Web must supply an explicit redirectTo so Supabase knows where to
      // send the user back after OAuth — the Site URL alone is not enough
      // when the project's redirect-allowlist is narrow.
      final webRedirect = redirectTo ?? (kIsWeb ? "${Uri.base.origin}/" : "https://kratos-os.online/");
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo:
            isMobile ? 'io.supabase.kratos://login-callback/' : webRedirect,
        authScreenLaunchMode: isMobile
            ? LaunchMode.inAppBrowserView
            : LaunchMode.platformDefault,
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

  @override
  void cancelEmailOtpAttempt() {
    // Supabase's HTTP request cannot be cancelled once sent. Invalidate its
    // result so it cannot alter the active login flow, while still accounting
    // for it in the bounded in-flight / rate-limit guards below.
    _activeOtpRequestId = null;
    if (_currentState is AuthLoading) {
      _emit(const AuthUnauthenticated());
    }
  }

  Future<void> _requestOtp(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (_activeOtpRequestId != null) {
      throw AuthFailure('A verification code is already being sent.');
    }
    if (_inFlightOtpRequests >= _maxOtpRequestsPerWindow) {
      throw AuthFailure(
        'A previous email request is still processing. Please wait briefly.',
      );
    }
    final requestStartedAt = DateTime.now();
    _otpRequestStarts.removeWhere(
      (time) => requestStartedAt.difference(time) >= _otpCooldown,
    );
    _lastOtpRequestAtByEmail.removeWhere(
      (_, time) => requestStartedAt.difference(time) >= _otpCooldown,
    );
    if (_otpRequestStarts.length >= _maxOtpRequestsPerWindow) {
      throw AuthFailure('Too many attempts. Please wait before trying again.');
    }
    final lastForEmail = _lastOtpRequestAtByEmail[normalizedEmail];
    if (lastForEmail != null &&
        requestStartedAt.difference(lastForEmail) < _otpCooldown) {
      throw AuthFailure(
        'Please wait before requesting another code for this email.',
      );
    }

    final requestId = ++_nextOtpRequestId;
    _activeOtpRequestId = requestId;
    _inFlightOtpRequests++;
    _otpRequestStarts.add(requestStartedAt);
    _lastOtpRequestAtByEmail[normalizedEmail] = requestStartedAt;
    try {
      _emit(const AuthLoading('Sending verification code...'));
      await _client.auth.signInWithOtp(email: normalizedEmail);
      // A cancelled request may finish, but only its own attempt may continue
      // to affect the current auth flow.
    } catch (error) {
      if (_activeOtpRequestId != requestId) return;
      _fail(_friendlyError(error, 'Could not send the verification code.'));
    } finally {
      _inFlightOtpRequests--;
      if (_activeOtpRequestId == requestId) _activeOtpRequestId = null;
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

  @override
  Future<void> signUpWithPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      _emit(const AuthLoading('Creating your account...'));
      await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {'full_name': displayName.trim()},
      );
      // Supabase sends a 6-digit OTP to the email automatically.
      // UI should transition to the OTP verification step.
    } catch (error) {
      _fail(_friendlyError(error, 'Could not create account.'));
    }
  }

  @override
  Future<void> verifySignUpOtp({
    required String email,
    required String token,
  }) async {
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
        type: OtpType.signup,
      );
      if (response.session == null) {
        throw AuthFailure('Session could not be established.');
      }
    } catch (error) {
      _fail(_friendlyError(error, 'The code is invalid or expired.'));
    }
  }

  @override
  Future<void> signInWithPassword({required String email, required String password}) async {
    print('[AUTH-TRACE] action started: signInWithPassword');
    try {
      _emit(const AuthLoading('Signing in...'));
      await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } catch (error) {
      _fail(_friendlyError(error, 'Incorrect email or password.'));
    }
  }

  String _friendlyError(Object error, String fallback) {
    if (error is AuthFailure) return error.message;
    final text = error.toString().toLowerCase();
    if (text.contains('rate') ||
        text.contains('too many') ||
        text.contains('429')) {
      return 'Too many attempts. Please wait and try again.';
    }
    if (text.contains('expired')) {
      return 'This code has expired. Request a new one.';
    }
    if (text.contains('invalid') || text.contains('otp')) {
      return 'The code is invalid or expired.';
    }
    if (text.contains('network') || text.contains('socket')) {
      return 'Network unavailable. Try again when you are online.';
    }
    return fallback;
  }

  void _fail(String message) {
    print('[AUTH-TRACE] _fail() called with: $message');
    _currentState = AuthError(message);
    _stateController.add(_currentState);
    throw AuthFailure(message);
  }

  void _emit(AuthState state) {
    print('[AUTH-TRACE] _emit() called with state: ${state.runtimeType}');
    _currentState = state;
    if (!_stateController.isClosed) _stateController.add(state);
  }

  @override
  Future<void> signInWithDevBypass({
    String? userId,
    String? displayName,
  }) async {
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



