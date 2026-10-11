import 'package:flutter/material.dart';

import '../../../../../app/kratos_theme.dart';
import '../../../../../app/kratos_visuals.dart';
import 'kratos_crystal_emblem.dart';

/// Top-Right Level Summary Card displaying current Level, Tier, and status.
///
/// Adheres strictly to Section 7 & 16:
/// - In specific Life Area mode: shows real Level IV — Crystal and real progression attributes
/// - In "All Life Areas" mode: shows Portfolio Overview without fabricating fake single-area levels.
class XpProgressLevelSummary extends StatelessWidget {
  final bool isAllLifeAreas;
  final String levelRoman;
  final String tierName;
  final String tierDescription;
  final bool canPromote;
  final int activeLifeAreasCount;
  final String? topLifeAreaName;
  final bool isDark;
  final Color? accentColor;

  const XpProgressLevelSummary({
    super.key,
    required this.isAllLifeAreas,
    required this.levelRoman,
    required this.tierName,
    required this.tierDescription,
    required this.canPromote,
    required this.activeLifeAreasCount,
    this.topLifeAreaName,
    required this.isDark,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final lime = accentColor ?? (isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime);
    final primary = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final secondary = isDark ? const Color(0xFFA7A7A7) : KratosTheme.lightTextSecondary;

    final title = isAllLifeAreas
        ? 'Portfolio Overview'
        : 'Level $levelRoman — $tierName';

    final subtitle = isAllLifeAreas
        ? 'Balanced performance across $activeLifeAreasCount active Life Areas.'
        : tierDescription;

    final bullet1 = isAllLifeAreas
        ? '$activeLifeAreasCount active developmental domains'
        : (canPromote ? 'Compound gate objectives verified' : 'Unlock new skill nodes');

    final bullet2 = isAllLifeAreas
        ? (topLifeAreaName != null
            ? 'Leading domain: $topLifeAreaName'
            : 'Steady cross-domain momentum')
        : 'Increased XP efficiency & focus';

    return KratosGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      borderRadius: BorderRadius.circular(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Large Vector Crystal Emblem ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 16),
            child: KratosCrystalEmblem(
              size: 52,
              isActive: !isAllLifeAreas,
              accentColor: lime,
            ),
          ),

          // ── Level Details & Status Items ────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: primary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w400,
                    color: secondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),

                // Bullet 1
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: isDark ? lime : const Color(0xFF557B00),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bullet1,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: primary.withValues(alpha: 0.90),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Bullet 2
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 15,
                      color: isDark ? lime : const Color(0xFF557B00),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bullet2,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: primary.withValues(alpha: 0.90),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
