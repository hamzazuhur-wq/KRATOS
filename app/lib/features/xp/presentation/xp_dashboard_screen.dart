// Wave 10: XP Dashboard screen — Liquid Glass / Acid Lime.
// Shows total XP, per-life-area breakdown, streak bonuses, and daily sparkline.
// Data flows: XpAnalyticsDao → (Riverpod provider) → this screen.

import 'package:flutter/material.dart';

/// XP Dashboard — main analytics hub.
///
/// Full implementation wires Riverpod [XpDashboardNotifier] backed by
/// [XpAnalyticsDao]. This placeholder renders a faithful visual prototype.
class XpDashboardScreen extends StatelessWidget {
  const XpDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'XP DASHBOARD',
          style: TextStyle(
            color: Color(0xFFC6F135),
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 16,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Total XP hero card
          const _HeroXpCard(totalXp: 8740, streakBonus: 320),
          const SizedBox(height: 20),

          // 7-day sparkline
          _SectionLabel(label: 'LAST 7 DAYS'),
          const SizedBox(height: 10),
          const _DailySparkline(
            dailyXp: [120, 85, 200, 0, 145, 310, 95],
          ),
          const SizedBox(height: 20),

          // Per-life-area breakdown
          _SectionLabel(label: 'XP BY LIFE AREA'),
          const SizedBox(height: 10),
          const _LifeAreaXpList(
            entries: [
              (name: 'Career', xp: 3400, color: Color(0xFF7B68EE)),
              (name: 'Health', xp: 2800, color: Color(0xFF4CAF50)),
              (name: 'Learning', xp: 1540, color: Color(0xFF00BCD4)),
              (name: 'Relationships', xp: 1000, color: Color(0xFFFF9500)),
            ],
          ),
          const SizedBox(height: 20),

          // XP source breakdown
          _SectionLabel(label: 'XP BY SOURCE'),
          const SizedBox(height: 10),
          const _XpSourceBreakdown(
            sources: [
              (label: 'Tasks', xp: 4200, icon: Icons.task_alt),
              (label: 'Sessions', xp: 2900, icon: Icons.timer),
              (label: 'Goals', xp: 1640, icon: Icons.flag),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          letterSpacing: 2.0,
          fontWeight: FontWeight.bold,
        ),
      );
}

// ---------------------------------------------------------------------------
// _HeroXpCard — total XP with streak bonus
// ---------------------------------------------------------------------------

class _HeroXpCard extends StatelessWidget {
  final int totalXp;
  final int streakBonus;
  const _HeroXpCard({required this.totalXp, required this.streakBonus});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFC6F135).withValues(alpha: 0.12),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFC6F135).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL XP EARNED',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              letterSpacing: 2.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatXp(totalXp),
            style: const TextStyle(
              color: Color(0xFFC6F135),
              fontWeight: FontWeight.bold,
              fontSize: 48,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.local_fire_department,
                  color: Color(0xFFFF9500), size: 16),
              const SizedBox(width: 5),
              Text(
                '+$streakBonus streak bonus XP earned',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatXp(int xp) {
    if (xp >= 1000) {
      final k = xp / 1000;
      return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}K';
    }
    return '$xp';
  }
}

// ---------------------------------------------------------------------------
// _DailySparkline — simple bar chart for 7-day XP
// ---------------------------------------------------------------------------

class _DailySparkline extends StatelessWidget {
  final List<int> dailyXp;
  const _DailySparkline({required this.dailyXp});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final max = dailyXp.reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(dailyXp.length, (i) {
          final fraction = max > 0 ? dailyXp[i] / max : 0.0;
          final isToday = i == dailyXp.length - 1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 80 * fraction + 4,
                    decoration: BoxDecoration(
                      color: isToday
                          ? const Color(0xFFC6F135)
                          : const Color(0xFFC6F135).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _days[i % _days.length],
                    style: TextStyle(
                      color: isToday ? const Color(0xFFC6F135) : Colors.white38,
                      fontSize: 9,
                      fontWeight: isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LifeAreaXpList — horizontal bar rows per life area
// ---------------------------------------------------------------------------

class _LifeAreaXpList extends StatelessWidget {
  final List<({String name, int xp, Color color})> entries;
  const _LifeAreaXpList({required this.entries});

  @override
  Widget build(BuildContext context) {
    final totalXp = entries.fold<int>(0, (s, e) => s + e.xp);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: entries.map((e) {
          final fraction = totalXp > 0 ? e.xp / totalXp : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: e.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.name,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ),
                    Text(
                      '${e.xp} XP',
                      style: TextStyle(
                        color: e.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: fraction,
                    backgroundColor: Colors.white.withValues(alpha: 0.07),
                    valueColor: AlwaysStoppedAnimation<Color>(e.color),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _XpSourceBreakdown — tiles per sourceType
// ---------------------------------------------------------------------------

class _XpSourceBreakdown extends StatelessWidget {
  final List<({String label, int xp, IconData icon})> sources;
  const _XpSourceBreakdown({required this.sources});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: sources.map((s) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              children: [
                Icon(s.icon, color: const Color(0xFFC6F135), size: 22),
                const SizedBox(height: 8),
                Text(
                  '${s.xp}',
                  style: const TextStyle(
                    color: Color(0xFFC6F135),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.label,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
