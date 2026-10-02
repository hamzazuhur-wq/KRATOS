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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasStreak = streakInfo.currentStreak > 0;
    const flameColor = Color(0xFFFF9500);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? (hasStreak
                ? flameColor.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04))
            : (hasStreak
                ? flameColor.withValues(alpha: 0.10)
                : const Color(0x0C0F172A)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasStreak
              ? flameColor.withValues(alpha: isDark ? 0.50 : 0.60)
              : (isDark ? Colors.white12 : const Color(0x1F0F172A)),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department,
            color: hasStreak ? flameColor : (isDark ? Colors.white38 : const Color(0xFF8A92A0)),
            size: 18,
          ),
          const SizedBox(width: 5),
          Text(
            '${streakInfo.currentStreak} DAYS',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F1115),
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.0,
            ),
          ),
          if (streakInfo.freezeTokensAvailable > 0) ...[
            const SizedBox(width: 8),
            Row(
              children: List.generate(
                streakInfo.freezeTokensAvailable.clamp(
                  0,
                  StreakConfig.maxFreezes,
                ),
                (index) => const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Icon(Icons.ac_unit, size: 12, color: Color(0xFF00FFFF)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
