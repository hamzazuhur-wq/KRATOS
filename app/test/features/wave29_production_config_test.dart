// Wave 29 Unit Tests: Production Build & Packaging Configuration
//
// Tests cover:
//   1. Production config flags: debug bypass disabled, production flag active
//   2. Staging config flags: debug bypass enabled for QA
//   3. Development config flags: local endpoints
//   4. Version and build number integrity

import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('production configuration disables debug bypass and sets production flags', () {
      final config = AppConfig.production();

      expect(config.isProduction, isTrue);
      expect(config.isDevelopment, isFalse);
      expect(config.enableDebugBypass, isFalse);
      expect(config.enableDetailedLogging, isFalse);
      expect(config.appVersion, '1.0.0');
      expect(config.buildNumber, 100);
      expect(config.appName, 'KRATOS');
      expect(config.hasSupabaseConfiguration, isFalse);
    });

    test('staging configuration permits debug bypass for QA testing', () {
      final config = AppConfig.staging();

      expect(config.isProduction, isFalse);
      expect(config.enableDebugBypass, isTrue);
      expect(config.enableDetailedLogging, isTrue);
      expect(config.appName, contains('Staging'));
    });

    test('development configuration points to local endpoints', () {
      final config = AppConfig.development();

      expect(config.isDevelopment, isTrue);
      expect(config.isProduction, isFalse);
      expect(config.supabaseUrl, contains('localhost'));
      expect(config.enableDebugBypass, isTrue);
    });
  });
}
