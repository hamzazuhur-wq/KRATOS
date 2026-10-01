// Wave 7: Streak badge widget with freeze indicator.
// Liquid Glass / Acid Lime aesthetic.

import 'package:flutter/material.dart';

import '../domain/streak_config.dart';
import '../domain/streak_models.dart';

class StreakBadgeWidget extends StatelessWidget {
  final StreakInfo streakInfo;

  const StreakBadgeWidget({super.key, required this.streakInfo});

  @override
  Widget build(BuildContext context) {
    final hasStreak = streakInfo.currentStreak > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasStreak ? const Color(0xFFFF9500) : Colors.white24,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department,
            color: hasStreak ? const Color(0xFFFF9500) : Colors.white38,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            '${streakInfo.currentStreak} DAYS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 10),
          // Freeze token indicators
          Row(
            children: List.generate(
              streakInfo.freezeTokensAvailable.clamp(
                0,
                StreakConfig.maxFreezes,
              ),
              (index) => const Padding(
                padding: EdgeInsets.only(left: 3),
                child: Icon(Icons.ac_unit, size: 13, color: Color(0xFF00FFFF)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
