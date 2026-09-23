// ignore_for_file: public_member_api_docs
// Wave 15: SupabaseAuthService implementing real Supabase Authentication & Google OAuth.
// Adheres strictly to the supabase-auth-sync skill specifications.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/ids.dart';
import '../domain/auth_models.dart';
import '../domain/auth_service.dart';

class SupabaseAuthService implements AuthService {
  final SupabaseClient _client;
  final _stateController = StreamController<AuthState>.broadcast();
  late final StreamSubscription<AuthState> _sub;
  AuthState _currentState = const AuthUnauthenticated();

  SupabaseAuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client {
    // Listen to Supabase auth state transitions
    _client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      final user = session?.user;
      if (user != null) {
        _currentState = AuthAuthenticated(
          KratosUser(
            id: Id(user.id),
            email: user.email ?? 'unknown@kratos.app',
            displayName: user.userMetadata?['full_name'] as String?,
            avatarUrl: user.userMetadata?['avatar_url'] as String?,
            method: AuthMethod.google,
            createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now().toUtc(),
          ),
        );
      } else {
        _currentState = const AuthUnauthenticated();
      }
      _stateController.add(_currentState);
    });
  }

  @override
  Stream<AuthState> get authStateStream => _stateController.stream;

  @override
  AuthState get currentState => _currentState;

  @override
  KratosUser? get currentUser {
    final state = _currentState;
    if (state is AuthAuthenticated) return state.user;
    return null;
  }

  @override
  Future<void> signInWithGoogle({String? redirectTo}) async {
    try {
      _stateController.add(const AuthLoading('Redirecting to Google...'));
      final defaultRedirect = kIsWeb
          ? null // Web relies on current origin callback
          : 'io.supabase.kratos://login-callback';

      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo ?? defaultRedirect,
      );
    } catch (e) {
      _currentState = AuthError('Google Sign-In failed: $e', e);
      _stateController.add(_currentState);
      rethrow;
    }
  }

  @override
  Future<void> signInWithEmail(String email, {String? password}) async {
    try {
      _stateController.add(const AuthLoading('Sending magic link / signing in...'));
      if (password != null && password.isNotEmpty) {
        await _client.auth.signInWithPassword(email: email, password: password);
      } else {
        await _client.auth.signInWithOtp(email: email);
      }
    } catch (e) {
      _currentState = AuthError('Email Sign-In failed: $e', e);
      _stateController.add(_currentState);
      rethrow;
    }
  }

  @override
  Future<void> signInWithDevBypass({String? userId, String? displayName}) async {
    // In production Supabase service, dev bypass is a mock overlay
    final user = KratosUser.devMock(
      id: userId ?? 'usr_seed_dev_01',
      displayName: displayName ?? 'Dev Operative',
    );
    _currentState = AuthAuthenticated(user);
    _stateController.add(_currentState);
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    _currentState = const AuthUnauthenticated();
    _stateController.add(_currentState);
  }

  void dispose() {
    _stateController.close();
  }
}
