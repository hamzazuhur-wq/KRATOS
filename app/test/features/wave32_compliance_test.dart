// Wave 32 Unit & Widget Tests: Store Compliance, Privacy Policies & Distribution Assets
//
// Tests cover:
//   1. Compliance documents exist and include required sections
//   2. Store listing permissions match technical justifications
//   3. PrivacyPolicyScreen widget renders in-app compliance content

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/features/maintenance/presentation/privacy_policy_screen.dart';

void main() {
  group('Store Compliance Documents', () {
    test('PRIVACY_POLICY.md exists and contains local-first commitment', () {
      final file = File('../docs/PRIVACY_POLICY.md');
      // If run from app/ dir
      final content = file.existsSync()
          ? file.readAsStringSync()
          : File('docs/PRIVACY_POLICY.md').readAsStringSync();

      expect(content, contains('Local-First Data Sovereignty'));
      expect(content, contains('Invariant #11'));
      expect(content, contains('Right to Erasure'));
    });

    test('STORE_LISTING_METADATA.md exists and specifies required permissions', () {
      final file = File('../docs/STORE_LISTING_METADATA.md');
      final content = file.existsSync()
          ? file.readAsStringSync()
          : File('docs/STORE_LISTING_METADATA.md').readAsStringSync();

      expect(content, contains('RECORD_AUDIO'));
      expect(content, contains('POST_NOTIFICATIONS'));
      expect(content, contains('FOREGROUND_SERVICE'));
    });
  });

  group('PrivacyPolicyScreen Widget', () {
    testWidgets('renders all policy sections on screen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyPolicyScreen(),
        ),
      );

      expect(find.text('Privacy & Data Ownership'), findsOneWidget);
      expect(find.text('1. Local-First Sovereignty'), findsOneWidget);
      expect(find.text('2. Zero Data Monetization'), findsOneWidget);
      expect(find.text('3. Advisory AI Guardrails'), findsOneWidget);
    });
  });
}
