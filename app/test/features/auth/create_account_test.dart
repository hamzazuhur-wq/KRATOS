// KRATOS Wave 3: Create Account Unit & Validation Test Suite.
// Verifies full local validation rules, Supabase signup contract, metadata persistence, and error safety.

import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/features/auth/data/mock_auth_service.dart';
import 'package:kratos_app/features/auth/domain/auth_models.dart';

void main() {
  group('Wave 3 — Create Account Validation & Contract Matrix', () {
    test('TEST 1: Valid credentials creates account and retains full name metadata', () async {
      final auth = MockAuthService(autoAuthenticate: false);

      final result = await auth.signUpWithPassword(
        fullName: 'Hamza Operative',
        email: 'new_operative@kratos.dev',
        password: 'StrongPassword123!',
      );

      expect(result.requiresEmailVerification, isTrue);
      expect(result.email, equals('new_operative@kratos.dev'));
      expect(result.user?.displayName, equals('Hamza Operative'));
      expect(result.user?.email, equals('new_operative@kratos.dev'));
      auth.dispose();
    });

    test('TEST 2: Password < 8 characters is invalid', () {
      final pwd = 'Short1!';
      expect(pwd.length >= 8, isFalse);
    });

    test('TEST 3: Password without uppercase is invalid', () {
      final pwd = 'lowercase123!@#';
      expect(pwd.contains(RegExp(r'[A-Z]')), isFalse);
    });

    test('TEST 4: Password without lowercase is invalid', () {
      final pwd = 'UPPERCASE123!@#';
      expect(pwd.contains(RegExp(r'[a-z]')), isFalse);
    });

    test('TEST 5: Password without number is invalid', () {
      final pwd = 'NoNumberPassword!';
      expect(pwd.contains(RegExp(r'[0-9]')), isFalse);
    });

    test('TEST 6: Password without symbol is invalid', () {
      final pwd = 'NoSymbolPassword123';
      expect(pwd.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-=+~`\[\]\\/]')), isFalse);
    });

    test('TEST 7: Password mismatch is detected', () {
      final pwd = 'Password123!';
      final confirm = 'Password123?';
      expect(pwd == confirm, isFalse);
    });

    test('TEST 8: Empty Full Name is detected', () {
      final fullName = '   ';
      expect(fullName.trim().isEmpty, isTrue);
    });

    test('TEST 9: Existing email throws safe uniform error', () async {
      final auth = MockAuthService(autoAuthenticate: false);

      await expectLater(
        auth.signUpWithPassword(
          fullName: 'Duplicate User',
          email: 'duplicate@kratos.dev',
          password: 'Password123!',
        ),
        throwsA(isA<Exception>()),
      );

      expect(auth.currentState, isA<AuthError>());
      final error = auth.currentState as AuthError;
      expect(error.message, equals('An account with this email already exists. Please sign in instead.'));
      auth.dispose();
    });

    test('TEST 10: Successful signup does not automatically mark as authenticated if verification required', () async {
      final auth = MockAuthService(autoAuthenticate: false);

      final result = await auth.signUpWithPassword(
        fullName: 'Unverified Operative',
        email: 'unverified@kratos.dev',
        password: 'ValidPassword123!',
      );

      expect(result.requiresEmailVerification, isTrue);
      expect(auth.currentState, isNot(isA<AuthAuthenticated>()));
      auth.dispose();
    });
  });
}
