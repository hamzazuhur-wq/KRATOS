// Wave 8: Skills Registry screen.
// Liquid Glass / Acid Lime — KRATOS design system.
// ADR-004: Distinguishes Skills (competencies) from Tools (inventory).
// Invariant #4: Skill XP is attribution metadata only — displayed as rollup.

import 'package:flutter/material.dart';

/// Skills Registry screen — placeholder for Wave 8 UX.
///
/// Full implementation will use Riverpod [SkillsNotifier] backed by [SkillsDao]
/// and read XP attribution from [XpLedgerDao].
class SkillsRegistryScreen extends StatelessWidget {
  const SkillsRegistryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'SKILLS',
          style: TextStyle(
            color: Color(0xFFC6F135),
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFFC6F135)),
            onPressed: () {
              // TODO(Wave 12 UX): create skill sheet
            },
            tooltip: 'New Skill',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                _SkillCard(
                  name: 'Flutter Development',
                  icon: '⚡',
                  xpTotal: 2400,
                  level: 8,
                  toolCount: 3,
                ),
                SizedBox(height: 12),
                _SkillCard(
                  name: 'System Design',
                  icon: '🏗️',
                  xpTotal: 1200,
                  level: 5,
                  toolCount: 2,
                ),
                SizedBox(height: 12),
                _SkillCard(
                  name: 'Writing',
                  icon: '✍️',
                  xpTotal: 600,
                  level: 3,
                  toolCount: 1,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO(Wave 12): create skill flow
        },
        backgroundColor: const Color(0xFFC6F135),
        foregroundColor: const Color(0xFF0D0D0D),
        icon: const Icon(Icons.psychology),
        label: const Text(
          'New Skill',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SkillCard — Liquid Glass card for a skill with XP attribution bar
// ---------------------------------------------------------------------------

class _SkillCard extends StatelessWidget {
  final String name;
  final String icon;
  final int xpTotal;
  final int level;
  final int toolCount;

  const _SkillCard({
    required this.name,
    required this.icon,
    required this.xpTotal,
    required this.level,
    required this.toolCount,
  });

  @override
  Widget build(BuildContext context) {
    // Progress within current level (simplified display only — real calc via ProgressionCalculator)
    final progressFraction = (xpTotal % 500) / 500.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon container
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFC6F135).withValues(alpha: 0.3)),
                ),
                alignment: Alignment.center,
                child: Text(icon, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$toolCount tool${toolCount == 1 ? '' : 's'} linked',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _LevelBadge(level: level),
            ],
          ),
          const SizedBox(height: 14),
          // XP Attribution bar
          Row(
            children: [
              const Text(
                'XP (attribution)',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const Spacer(),
              Text(
                '$xpTotal XP',
                style: const TextStyle(
                  color: Color(0xFFC6F135),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressFraction,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFC6F135)),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final int level;
  const _LevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC6F135), Color(0xFF8BC34A)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'LVL $level',
        style: const TextStyle(
          color: Color(0xFF0D0D0D),
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
