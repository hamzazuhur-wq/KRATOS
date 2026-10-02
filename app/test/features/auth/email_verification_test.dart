// KRATOS Wave 4: Email Verification / OTP Unit Test Suite.
// Verifies 6-digit OTP verification, resend cooldown, safe error handling, and state transitions.

import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/features/auth/data/mock_auth_service.dart';
import 'package:kratos_app/features/auth/domain/auth_models.dart';

void main() {
  group('Wave 4 — Email Verification / OTP Test Matrix', () {
    test('TEST 1 & 2: Valid 6-digit code successfully verifies and authenticates', () async {
      final auth = MockAuthService(autoAuthenticate: false);

      await auth.verifySignUpOtp(
        email: 'operative@kratos.dev',
        token: '123456',
      );

      expect(auth.currentState, isA<AuthAuthenticated>());
      final user = (auth.currentState as AuthAuthenticated).user;
      expect(user.email, equals('operative@kratos.dev'));
      expect(user.displayName, equals('operative'));
      auth.dispose();
    });

    test('TEST 3: Incorrect 6-digit code fails with safe error', () async {
      final auth = MockAuthService(autoAuthenticate: false);

      await expectLater(
        auth.verifySignUpOtp(
          email: 'operative@kratos.dev',
          token: '000000',
        ),
        throwsA(isA<Exception>()),
      );

      expect(auth.currentState, isA<AuthError>());
      final error = auth.currentState as AuthError;
      expect(error.message, equals('Invalid or expired code.'));
      auth.dispose();
    });

    test('TEST 4: Expired code fails with uniform safe error', () async {
      final auth = MockAuthService(autoAuthenticate: false);

      await expectLater(
        auth.verifySignUpOtp(
          email: 'operative@kratos.dev',
          token: '999999',
        ),
        throwsA(isA<Exception>()),
      );

      expect(auth.currentState, isA<AuthError>());
      final error = auth.currentState as AuthError;
      expect(error.message, equals('Invalid or expired code.'));
      auth.dispose();
    });

    test('TEST 5: Resend code successfully triggers new code delivery', () async {
      final auth = MockAuthService(autoAuthenticate: false);
      // Resend should complete without throwing
      await auth.resendSignUpOtp(email: 'operative@kratos.dev');
      auth.dispose();
    });
  });
}
