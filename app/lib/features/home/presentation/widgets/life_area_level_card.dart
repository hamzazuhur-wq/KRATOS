import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/kratos_motion.dart';
import '../../../../app/kratos_theme.dart';
import '../../../../app/kratos_visuals.dart';
import '../../../../data/drift/app_database.dart';
import '../../../levels/data/levels_dashboard_repository.dart';
import '../../../life_areas/presentation/life_area_dashboard_screen.dart';

/// Maps tier string to KRATOS tier color tokens.
Color getTierColor(String tier) {
  final normalized = tier.toLowerCase();
  if (normalized.contains('wood')) {
    return const Color(0xFF8D6E63);
  } else if (normalized.contains('bronze')) {
    return const Color(0xFFCD7F32);
  } else if (normalized.contains('silver')) {
    return const Color(0xFFC0C0C0);
  } else if (normalized.contains('gold')) {
    return const Color(0xFFFFD700);
  } else if (normalized.contains('crystal')) {
    return const Color(0xFF00E5FF);
  } else if (normalized.contains('diamond')) {
    return const Color(0xFFB9F2FF);
  } else if (normalized.contains('mythic')) {
    return const Color(0xFFC6F135);
  }
  return const Color(0xFFC6F135);
}

/// Helper to render Roman numerals for levels.
String formatLevelWithRoman(String tier, int level) {
  const roman = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];
  final numeral = (level >= 1 && level <= 10) ? roman[level - 1] : '$level';
  return '$tier $numeral';
}

/// Life Area Level Card with Liquid Glass + Restrained Tier Environmental Layer.
class LifeAreaLevelCard extends StatelessWidget {
  final AppDatabase database;
  final String ownerId;
  final LevelsDashboardEntry entry;

  const LifeAreaLevelCard({
    super.key,
    required this.database,
    required this.ownerId,
    required this.entry,
  });

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      KratosPageRoute(
        page: LifeAreaDashboardScreen(
          database: database,
          ownerId: ownerId,
          area: entry.area,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final secondaryTextColor = isDark ? Colors.white70 : KratosTheme.lightTextSecondary;

    final tierColor = getTierColor(entry.progression.tier);
    final formatter = NumberFormat('#,###');
    final formattedXp = formatter.format(entry.progression.totalXp);
    final levelDisplay = formatLevelWithRoman(
      entry.progression.tier,
      entry.progression.level,
    );
    final progressPct = entry.progression.progressPct;

    return KratosGlassCard(
      variant: KratosSurfaceVariant.interactive,
      interactive: true,
      dashboardGlass: true,
      accentColor: tierColor,
      borderRadius: BorderRadius.circular(20),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetail(context),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Life Area Name & Tier Tag
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.area.name,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: tierColor.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        entry.progression.tier.toUpperCase(),
                        style: TextStyle(
                          color: tierColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Level Display (e.g. Gold II) & XP
                Row(
                  children: [
                    Text(
                      levelDisplay,
                      style: TextStyle(
                        color: tierColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: TextStyle(
                        color: isDark ? Colors.white24 : const Color(0x33000000),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$formattedXp XP',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    KratosAnimatedMetric(
                      value: progressPct,
                      formatter: (v) => '${v.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Progress Bar within Current Level
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 5,
                    width: double.infinity,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0x14000000),
                    child: KratosProgressAnimation(
                      value: (progressPct / 100.0).clamp(0.0, 1.0),
                      builder: (context, animatedFactor) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: animatedFactor,
                        child: Container(
                          decoration: BoxDecoration(
                            color: tierColor,
                            boxShadow: [
                              BoxShadow(
                                color: tierColor.withValues(alpha: isDark ? 0.5 : 0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
