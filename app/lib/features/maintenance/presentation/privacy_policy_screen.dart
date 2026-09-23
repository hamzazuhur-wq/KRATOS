// ignore_for_file: public_member_api_docs
// Wave 32: PrivacyPolicyScreen — Liquid Glass in-app privacy & data sovereignty viewer.

import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Privacy & Data Ownership',
          style: TextStyle(
            color: Color(0xFFC6F135),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFC6F135)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PolicySection(
              icon: Icons.shield_rounded,
              title: '1. Local-First Sovereignty',
              body:
                  'KRATOS operates on an offline-first architecture. Your goals, tasks, notes, sessions, and XP progression live locally in your device SQLite database.',
            ),
            const SizedBox(height: 16),
            _PolicySection(
              icon: Icons.lock_rounded,
              title: '2. Zero Data Monetization',
              body:
                  'We never sell, rent, or monetize your personal habits, routines, or reflection notes to advertisers or third parties.',
            ),
            const SizedBox(height: 16),
            _PolicySection(
              icon: Icons.psychology_rounded,
              title: '3. Advisory AI Guardrails',
              body:
                  'As guaranteed by Invariant #11, AI recommendations are strictly advisory and cannot mutate your personal records without explicit confirmation.',
            ),
            const SizedBox(height: 16),
            _PolicySection(
              icon: Icons.download_rounded,
              title: '4. Full Data Portability',
              body:
                  'You can export your complete structured data to JSON anytime via Data Backup settings or trigger immediate two-phase trash purges.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PolicySection({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFC6F135), size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
