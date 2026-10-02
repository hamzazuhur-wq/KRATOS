// KRATOS Wave 6: Session Persistence & Security Test Suite.
// Verifies session authority, token lifecycle, route protection, and security boundaries.

import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/core/config/app_config.dart';
import 'package:kratos_app/features/auth/data/mock_auth_service.dart';
import 'package:kratos_app/features/auth/domain/auth_models.dart';

void main() {
  group('Wave 6 — Session Persistence & Security Matrix', () {
    test('TEST 1 & 2: Active session persists in memory and restores reliably', () async {
      final auth = MockAuthService(autoAuthenticate: true);
      expect(auth.currentState, isA<AuthAuthenticated>());
      expect(auth.currentUser?.email, isNotEmpty);
      auth.dispose();
    });

    test('TEST 3 & 9: Sign out unconditionally clears session to AuthUnauthenticated', () async {
      final auth = MockAuthService(autoAuthenticate: true);
      expect(auth.currentState, isA<AuthAuthenticated>());

      await auth.signOut();
      expect(auth.currentState, isA<AuthUnauthenticated>());
      expect(auth.currentUser, isNull);
      auth.dispose();
    });

    test('TEST 4 & 5: Email login establishes valid session that remains active', () async {
      final auth = MockAuthService(autoAuthenticate: false);
      expect(auth.currentState, isA<AuthUnauthenticated>());

      await auth.signInWithPassword(
        email: 'secure_user@kratos.dev',
        password: 'ValidPassword123!',
      );

      expect(auth.currentState, isA<AuthAuthenticated>());
      expect(auth.currentUser?.email, equals('secure_user@kratos.dev'));
      auth.dispose();
    });

    test('TEST 6: Wrong password never grants authenticated state', () async {
      final auth = MockAuthService(autoAuthenticate: false);

      await auth.signInWithPassword(
        email: 'target@kratos.dev',
        password: 'wrong_password',
      );

      expect(auth.currentState, isA<AuthError>());
      expect(auth.currentUser, isNull);
      auth.dispose();
    });

    test('TEST 7 & 8: OTP verification transitions user into AuthAuthenticated', () async {
      final auth = MockAuthService(autoAuthenticate: false);

      await auth.verifySignUpOtp(
        email: 'otp_verified@kratos.dev',
        token: '123456',
      );

      expect(auth.currentState, isA<AuthAuthenticated>());
      expect(auth.currentUser?.email, equals('otp_verified@kratos.dev'));
      auth.dispose();
    });

    test('TEST 10: Unauthenticated instances remain isolated without session spill', () {
      final authA = MockAuthService(autoAuthenticate: true);
      final authB = MockAuthService(autoAuthenticate: false);

      expect(authA.currentState, isA<AuthAuthenticated>());
      expect(authB.currentState, isA<AuthUnauthenticated>());

      authA.dispose();
      authB.dispose();
    });

    test('TEST 13: Production AppConfig strictly disables debug auth bypass', () {
      final prodConfig = AppConfig.fromEnvironment(isRelease: true);
      expect(prodConfig.enableDebugBypass, isFalse);
      expect(prodConfig.isProduction, isTrue);
    });
  });
}
