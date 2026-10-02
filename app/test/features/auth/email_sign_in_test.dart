// KRATOS Wave 2: Email Sign In Unit & Functional Test Suite.
// Verifies Email/Password sign in, safe error handling, input validation, and Google safety.

import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/features/auth/data/mock_auth_service.dart';
import 'package:kratos_app/features/auth/domain/auth_models.dart';

void main() {
  group('Wave 2 — Email Sign In Test Matrix', () {
    test('TEST 1: Valid email and password results in AuthAuthenticated', () async {
      final auth = MockAuthService(autoAuthenticate: false);
      expect(auth.currentState, isA<AuthUnauthenticated>());

      await auth.signInWithPassword(
        email: 'operative@kratos.dev',
        password: 'SecurePassword123!',
      );

      expect(auth.currentState, isA<AuthAuthenticated>());
      final user = (auth.currentState as AuthAuthenticated).user;
      expect(user.email, equals('operative@kratos.dev'));
      expect(user.displayName, equals('operative'));
      expect(user.method, equals(AuthMethod.email));
      auth.dispose();
    });

    test('TEST 2: Existing email + wrong password fails with safe error', () async {
      final auth = MockAuthService(autoAuthenticate: false);

      await auth.signInWithPassword(
        email: 'operative@kratos.dev',
        password: 'wrong_password',
      );

      expect(auth.currentState, isA<AuthError>());
      final error = auth.currentState as AuthError;
      expect(error.message, equals('Incorrect email or password.'));
      auth.dispose();
    });

    test('TEST 3: Non-existent email fails with uniform safe error (no enumeration)', () async {
      final auth = MockAuthService(autoAuthenticate: false);

      await auth.signInWithPassword(
        email: 'nonexistent@test.com',
        password: 'AnyPassword999!',
      );

      expect(auth.currentState, isA<AuthError>());
      final error = auth.currentState as AuthError;
      expect(error.message, equals('Incorrect email or password.'));
      auth.dispose();
    });

    test('TEST 4: Empty email fails validation immediately', () async {
      final auth = MockAuthService(autoAuthenticate: false);

      await auth.signInWithPassword(
        email: '   ',
        password: 'ValidPassword123!',
      );

      expect(auth.currentState, isA<AuthError>());
      final error = auth.currentState as AuthError;
      expect(error.message, equals('Please enter your email.'));
      auth.dispose();
    });

    test('TEST 5: Empty password fails validation immediately', () async {
      final auth = MockAuthService(autoAuthenticate: false);

      await auth.signInWithPassword(
        email: 'operative@kratos.dev',
        password: '',
      );

      expect(auth.currentState, isA<AuthError>());
      final error = auth.currentState as AuthError;
      expect(error.message, equals('Please enter your password.'));
      auth.dispose();
    });

    test('TEST 6: Valid session persists across state queries', () async {
      final auth = MockAuthService(autoAuthenticate: false);

      await auth.signInWithPassword(
        email: 'persist@kratos.dev',
        password: 'ValidPassword123!',
      );

      expect(auth.currentState, isA<AuthAuthenticated>());
      expect(auth.currentUser?.email, equals('persist@kratos.dev'));
      auth.dispose();
    });

    test('TEST 7: Sign out clears session to AuthUnauthenticated', () async {
      final auth = MockAuthService(autoAuthenticate: true);
      expect(auth.currentState, isA<AuthAuthenticated>());

      await auth.signOut();
      expect(auth.currentState, isA<AuthUnauthenticated>());
      expect(auth.currentUser, isNull);
      auth.dispose();
    });

    test('TEST 8: Google sign-in remains completely functional and untouched', () async {
      final auth = MockAuthService(autoAuthenticate: false);
      expect(auth.currentState, isA<AuthUnauthenticated>());

      await auth.signInWithGoogle();

      expect(auth.currentState, isA<AuthAuthenticated>());
      final user = (auth.currentState as AuthAuthenticated).user;
      expect(user.displayName, equals('Hamza (Google)'));
      expect(user.method, equals(AuthMethod.google));
      auth.dispose();
    });
  });
}
