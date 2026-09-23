// Wave 15: Unit tests for Authentication domain and MockAuthService.

import 'package:test/test.dart';
import '../../lib/domain/ids.dart';
import '../../lib/features/auth/data/mock_auth_service.dart';
import '../../lib/features/auth/domain/auth_models.dart';

void main() {
  group('KratosUser and Auth Models', () {
    test('devMock factory produces valid dev operative', () {
      final user = KratosUser.devMock();
      expect(user.id.value, equals('usr_seed_dev_01'));
      expect(user.email, equals('dev@kratos.internal'));
      expect(user.method, equals(AuthMethod.developerMock));
    });

    test('custom devMock attributes are respected', () {
      final user = KratosUser.devMock(
        id: 'usr_hamza_custom',
        email: 'hamza@kratos.dev',
        displayName: 'Hamza',
      );
      expect(user.id.value, equals('usr_hamza_custom'));
      expect(user.email, equals('hamza@kratos.dev'));
      expect(user.displayName, equals('Hamza'));
    });
  });

  group('MockAuthService lifecycle', () {
    test('autoAuthenticate=true boots into AuthAuthenticated', () {
      final service = MockAuthService(autoAuthenticate: true);
      expect(service.currentState, isA<AuthAuthenticated>());
      expect(service.currentUser?.id.value, equals('usr_seed_dev_01'));
      service.dispose();
    });

    test('autoAuthenticate=false boots into AuthUnauthenticated', () {
      final service = MockAuthService(autoAuthenticate: false);
      expect(service.currentState, isA<AuthUnauthenticated>());
      expect(service.currentUser, isNull);
      service.dispose();
    });

    test('signInWithDevBypass transitions to AuthAuthenticated', () async {
      final service = MockAuthService(autoAuthenticate: false);
      await service.signInWithDevBypass(userId: 'usr_test_bypass');
      expect(service.currentState, isA<AuthAuthenticated>());
      expect(service.currentUser?.id.value, equals('usr_test_bypass'));
      service.dispose();
    });

    test('signInWithGoogle transitions to AuthAuthenticated', () async {
      final service = MockAuthService(autoAuthenticate: false);
      await service.signInWithGoogle();
      expect(service.currentState, isA<AuthAuthenticated>());
      expect(service.currentUser?.displayName, equals('Hamza (Google)'));
      service.dispose();
    });

    test('signOut transitions back to AuthUnauthenticated', () async {
      final service = MockAuthService(autoAuthenticate: true);
      expect(service.currentState, isA<AuthAuthenticated>());
      await service.signOut();
      expect(service.currentState, isA<AuthUnauthenticated>());
      expect(service.currentUser, isNull);
      service.dispose();
    });
  });
}
