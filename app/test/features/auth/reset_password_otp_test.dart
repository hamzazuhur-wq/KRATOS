// KRATOS Wave 5+: Reset Password OTP Unit Test Suite.
// Verifies 6 and 8-digit OTP reset, step-by-step verification, and clean transition to unauthenticated sign-in.

import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/features/auth/data/mock_auth_service.dart';
import 'package:kratos_app/features/auth/domain/auth_models.dart';

void main() {
  group('Reset Password OTP & Re-Authentication Matrix', () {
    test('TEST 1: Valid 6-digit code resets password and leaves user unauthenticated for login', () async {
      final auth = MockAuthService(autoAuthenticate: false);

      await auth.completePasswordResetWithOtp(
        email: 'operative@kratos.dev',
        token: '123456',
        newPassword: 'NewSecurePassword123!',
      );

      // Must remain unauthenticated so user can sign in via LoginScreen
      expect(auth.currentState, isA<AuthUnauthenticated>());
      auth.dispose();
    });

    test('TEST 2: Valid 8-digit code verifies and allows separate password update', () async {
      final auth = MockAuthService(autoAuthenticate: false);

      // Step 2: Verify 8-digit OTP
      await auth.verifyRecoveryOtp(
        email: 'operative@kratos.dev',
        token: '12345678',
      );

      // Remains unauthenticated (does NOT prematurely auto-login)
      expect(auth.currentState, isA<AuthUnauthenticated>());

      // Step 3: Set new password
      await auth.updatePassword('BrandNewPass999#');

      // Ready for Sign-In
      expect(auth.currentState, isA<AuthUnauthenticated>());
      auth.dispose();
    });

    test('TEST 3: Invalid code throws error and sets AuthError', () async {
      final auth = MockAuthService(autoAuthenticate: false);

      await expectLater(
        auth.verifyRecoveryOtp(
          email: 'operative@kratos.dev',
          token: '99999999',
        ),
        throwsA(isA<Exception>()),
      );

      expect(auth.currentState, isA<AuthError>());
      final error = auth.currentState as AuthError;
      expect(error.message, equals('Invalid or expired reset code.'));
      auth.dispose();
    });
  });
}
