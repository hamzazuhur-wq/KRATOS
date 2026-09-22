// Wave 12: Skills & Tools full UX — SkillDetail + ToolDetail screens.
// Links skills ↔ tools via skill_tools junction.
// ADR-004: Tools are inventory; Skills are graded competencies.

import 'package:flutter/material.dart';

/// Skill detail screen — shows XP attribution, linked tools, and level progress.
class SkillDetailScreen extends StatelessWidget {
  final String skillName;
  final String icon;
  final int xpTotal;
  final int level;
  final List<String> linkedTools;

  const SkillDetailScreen({
    super.key,
    required this.skillName,
    required this.icon,
    required this.xpTotal,
    required this.level,
    required this.linkedTools,
  });

  @override
  Widget build(BuildContext context) {
    const nextLevelXp = 500;
    final inLevelXp = xpTotal % 500;
    final progressFraction = inLevelXp / nextLevelXp;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFC6F135)),
        title: Text(
          skillName.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFC6F135),
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 14,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Level hero
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC6F135).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFFC6F135).withValues(alpha: 0.5),
                        width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(icon, style: const TextStyle(fontSize: 36)),
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFC6F135), Color(0xFF8BC34A)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'LEVEL $level',
                    style: const TextStyle(
                      color: Color(0xFF0D0D0D),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // XP Progress
          _DetailSection(
            label: 'XP ATTRIBUTION',
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      '$inLevelXp / $nextLevelXp XP to next level',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      '$xpTotal total',
                      style: const TextStyle(
                        color: Color(0xFFC6F135),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: progressFraction,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFC6F135)),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'XP shown is attribution only — earned through LifeArea tasks and sessions.',
                  style: TextStyle(color: Colors.white24, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Linked Tools
          _DetailSection(
            label: 'LINKED TOOLS',
            action: TextButton(
              onPressed: () {
                // TODO(Wave 12): link tool bottom sheet
              },
              child: const Text(
                '+ Link Tool',
                style: TextStyle(
                    color: Color(0xFFC6F135),
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
            child: linkedTools.isEmpty
                ? const Text(
                    'No tools linked yet.',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  )
                : Column(
                    children: linkedTools
                        .map((t) => _ToolChip(name: t))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  final String name;
  const _ToolChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.build_circle, color: Color(0xFF7B68EE), size: 16),
          const SizedBox(width: 10),
          Text(name,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          const Icon(Icons.close, color: Colors.white24, size: 14),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DetailSection — reusable section header
// ---------------------------------------------------------------------------

class _DetailSection extends StatelessWidget {
  final String label;
  final Widget child;
  final Widget? action;

  const _DetailSection(
      {required this.label, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (action != null) ...[const Spacer(), action!],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
