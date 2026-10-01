import 'package:flutter/material.dart';

import '../../../data/drift/app_database.dart';
import '../domain/streak_config.dart';
import '../domain/streak_models.dart';

/// Wave 7 / Home Integration: Minimal dedicated Streak Screen.
/// Provides a real destination for the Streak control in the top bar.
class StreakScreen extends StatelessWidget {
  final AppDatabase database;
  final String userId;
  final StreakInfo streakInfo;

  const StreakScreen({
    super.key,
    required this.database,
    required this.userId,
    required this.streakInfo,
  });

  @override
  Widget build(BuildContext context) {
    final hasStreak = streakInfo.currentStreak > 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'STREAK PROTOCOL',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            fontSize: 14,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Streak Display Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: hasStreak
                        ? const Color(0xFFFF9500).withValues(alpha: 0.4)
                        : Colors.white12,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (hasStreak
                                  ? const Color(0xFFFF9500)
                                  : Colors.transparent)
                              .withValues(alpha: 0.12),
                      blurRadius: 28,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            (hasStreak
                                    ? const Color(0xFFFF9500)
                                    : Colors.white24)
                                .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.local_fire_department,
                        color: hasStreak
                            ? const Color(0xFFFF9500)
                            : Colors.white38,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${streakInfo.currentStreak}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                      ),
                    ),
                    Text(
                      streakInfo.currentStreak == 1
                          ? 'DAY STREAK'
                          : 'DAYS STREAK',
                      style: TextStyle(
                        color: hasStreak
                            ? const Color(0xFFFF9500)
                            : Colors.white38,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Metrics Grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'LONGEST RECORD',
                      value: '${streakInfo.longestStreak} days',
                      icon: Icons.emoji_events_outlined,
                      accentColor: const Color(0xFFFFD700),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'FREEZE TOKENS',
                      value:
                          '${streakInfo.freezeTokensAvailable} / ${StreakConfig.maxFreezes}',
                      icon: Icons.ac_unit,
                      accentColor: const Color(0xFF00E5FF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Streak Rules & Protection Info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: Color(0xFFC6F135),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'STREAK PROTOCOL INVARIANTS',
                          style: TextStyle(
                            color: Color(0xFFC6F135),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildRuleItem(
                      'Qualifying completion',
                      'Complete a task, activity session, goal, or project to count the local calendar day.',
                    ),
                    _buildRuleItem(
                      'Daily Streak XP',
                      'Starting on streak day ${StreakConfig.minimumStreakDaysForReward}, earn the current streak day multiplied by ${StreakConfig.streakXpPerDay} XP.',
                    ),
                    _buildRuleItem(
                      'Freeze Shield',
                      'Up to ${StreakConfig.maxFreezes} freezes in a rolling ${StreakConfig.freezeWindowDays}-day window protect one missed day each; frozen days earn no XP.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: '$title: ',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                children: [
                  TextSpan(
                    text: desc,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
