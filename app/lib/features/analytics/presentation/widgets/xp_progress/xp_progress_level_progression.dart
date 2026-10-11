import 'package:flutter/material.dart';

import '../../../../../app/kratos_theme.dart';
import '../../../../../app/kratos_visuals.dart';
import '../../../domain/xp_progress_models.dart';
import 'kratos_crystal_emblem.dart';

/// Bottom-Left Level Progression timeline ladder (Section 16).
///
/// Features:
/// - Real KRATOS tier progression nodes: Bronze (I), Silver (II), Gold (III), Crystal (IV), Diamond (V)
/// - Vector geometric crystal emblems on each milestone node
/// - Active node highlighted with glowing Acid Lime underline and illuminated emblem
/// - Locked/future nodes subdued with clean micro padlock icons
/// - Connecting progression track representing completed vs locked span.
class XpProgressLevelProgression extends StatelessWidget {
  final List<XpProgressMilestone> milestones;
  final String lifeAreaName;
  final bool isAllLifeAreas;
  final bool isDark;
  final Color? accentColor;

  const XpProgressLevelProgression({
    super.key,
    required this.milestones,
    required this.lifeAreaName,
    required this.isAllLifeAreas,
    required this.isDark,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final lime = accentColor ?? (isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime);
    final primary = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final secondary = isDark ? const Color(0xFFA7A7A7) : KratosTheme.lightTextSecondary;

    final title = 'Level Progression';
    final subtitle = isAllLifeAreas
        ? 'Progression milestone ladder across system tiers.'
        : 'Your journey in $lifeAreaName.';

    return KratosGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row ────────────────────────────────────────────────────
          Text(
            title,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: primary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w400,
              color: secondary,
            ),
          ),

          const SizedBox(height: 22),

          // ── Progression Nodes Ladder ──────────────────────────────────────
          if (milestones.isEmpty)
            _buildEmptyTrack(secondary)
          else
            _buildTimeline(lime, primary, secondary),
        ],
      ),
    );
  }

  Widget _buildEmptyTrack(Color secondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          'No progression milestones recorded yet.',
          style: TextStyle(fontSize: 12, color: secondary),
        ),
      ),
    );
  }

  Widget _buildTimeline(Color lime, Color primary, Color secondary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final nodeCount = milestones.length;
        final slotWidth = nodeCount > 0 ? availableWidth / nodeCount : 40.0;

        return Stack(
          alignment: Alignment.center,
          children: [
            // ── Background Connecting Track ──────────────────────────────────
            Positioned(
              top: 14,
              left: slotWidth / 2,
              right: slotWidth / 2,
              child: Row(
                children: [
                  for (var i = 0; i < nodeCount - 1; i++) ...[
                    Expanded(
                      child: Container(
                        height: 2.0,
                        color: milestones[i].isCompleted && milestones[i + 1].isCompleted
                            ? (isDark ? Colors.white.withValues(alpha: 0.65) : const Color(0x600F172A))
                            : (milestones[i].isCurrent
                                ? lime.withValues(alpha: 0.70)
                                : (isDark ? const Color(0xFF292C2F) : const Color(0xFFD8DADB))),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Nodes Row ────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final node in milestones)
                  Expanded(
                    child: _buildNodeItem(
                      node: node,
                      lime: lime,
                      primary: primary,
                      secondary: secondary,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildNodeItem({
    required XpProgressMilestone node,
    required Color lime,
    required Color primary,
    required Color secondary,
  }) {
    final isCurrent = node.isCurrent;
    final isCompleted = node.isCompleted;
    final isLocked = node.isLocked;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Emblem Anchor
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF0F120F) : const Color(0xFFF0F0EB),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: lime.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: KratosCrystalEmblem(
              size: 22,
              isActive: isCurrent,
              isCompleted: isCompleted,
              isLocked: isLocked,
              accentColor: lime,
            ),
          ),

          const SizedBox(height: 7),

          // Roman Numeral
          Text(
            node.roman,
            style: TextStyle(
              fontFamily: 'IBM Plex Mono',
              fontSize: 12.0,
              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
              color: isCurrent
                  ? lime
                  : (isCompleted
                      ? primary
                      : secondary.withValues(alpha: 0.50)),
            ),
          ),

          const SizedBox(height: 3),

          // Tier Name
          Text(
            node.tierName,
            style: TextStyle(
              fontSize: 11.0,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: isCurrent
                  ? primary
                  : (isCompleted
                      ? secondary
                      : secondary.withValues(alpha: 0.50)),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 5),

          // Active Underline Indicator Bar
          if (isCurrent)
            Container(
              width: 28,
              height: 2.5,
              decoration: BoxDecoration(
                color: lime,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: lime.withValues(alpha: 0.60),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            )
          else
            const SizedBox(height: 2.5),
        ],
      );
  }
}
