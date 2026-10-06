// ignore_for_file: public_member_api_docs
// Wave 32: PrivacyPolicyScreen — in-app privacy & data sovereignty viewer.
// Wave 12: restyled with the Settings kit (same copy).

import 'package:flutter/material.dart';
import '../../settings/presentation/settings_kit.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsPage(
      title: 'Privacy & Data Ownership',
      children: [
        SettingsGroup(
          children: [
            SettingsTextRow(
              icon: Icons.shield_rounded,
              title: '1. Local-First Sovereignty',
              body:
                  'KRATOS operates on an offline-first architecture. Your goals, tasks, notes, sessions, and XP progression live locally in your device SQLite database.',
            ),
            SettingsTextRow(
              icon: Icons.lock_rounded,
              title: '2. Zero Data Monetization',
              body:
                  'We never sell, rent, or monetize your personal habits, routines, or reflection notes to advertisers or third parties.',
            ),
            SettingsTextRow(
              icon: Icons.psychology_rounded,
              title: '3. Advisory AI Guardrails',
              body:
                  'As guaranteed by Invariant #11, AI recommendations are strictly advisory and cannot mutate your personal records without explicit confirmation.',
            ),
            SettingsTextRow(
              icon: Icons.download_rounded,
              title: '4. Full Data Portability',
              body:
                  'You can export your complete structured data to JSON anytime via Data Backup settings or trigger immediate two-phase trash purges.',
            ),
          ],
        ),
      ],
    );
  }
}
