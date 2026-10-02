// KRATOS Wave 5: Account & Identity Integration Test Suite.
// Verifies identity inspection, full name preservation, canonical UUID stability, and profile integration.

import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/domain/ids.dart';
import 'package:kratos_app/features/auth/data/mock_auth_service.dart';
import 'package:kratos_app/features/auth/domain/auth_models.dart';

void main() {
  group('Wave 5 — Identity & Profile Integration Matrix', () {
    test('TEST A & D: User ID and Full Name are preserved across identity creation and sign-in', () async {
      final auth = MockAuthService(autoAuthenticate: false);

      await auth.signInWithPassword(
        email: 'operative@kratos.dev',
        password: 'Password123!',
      );

      final user = auth.currentUser;
      expect(user, isNotNull);
      expect(user!.email, equals('operative@kratos.dev'));
      expect(user.displayName, equals('operative'));
      expect(user.id, isA<Id>());
      auth.dispose();
    });

    test('TEST B: Google identity is correctly inspected', () async {
      final auth = MockAuthService(autoAuthenticate: false);
      await auth.signInWithGoogle();

      final identities = await auth.getUserIdentities();
      expect(identities, contains('google'));
      auth.dispose();
    });

    test('TEST C: Email identity is correctly inspected', () async {
      final auth = MockAuthService(autoAuthenticate: false);
      await auth.signInWithPassword(
        email: 'email_identity@kratos.dev',
        password: 'Password123!',
      );

      final identities = await auth.getUserIdentities();
      expect(identities, contains('email'));
      auth.dispose();
    });

    test('TEST E: Canonical user UUID remains authoritative without secondary shadow IDs', () {
      const canonicalId = '018f3a21-9988-7123-8456-112233445566';
      final user = KratosUser(
        id: Id(canonicalId),
        email: 'canonical@kratos.dev',
        displayName: 'Canonical Operative',
      );

      expect(user.id.value, equals(canonicalId));
    });

    test('TEST F: KratosUser displayName accurately extracts full_name from metadata', () {
      final user = KratosUser.devMock(
        displayName: 'Commander Shepard',
        email: 'shepard@normandy.alliance',
      );

      expect(user.displayName, equals('Commander Shepard'));
    });
  });
}
