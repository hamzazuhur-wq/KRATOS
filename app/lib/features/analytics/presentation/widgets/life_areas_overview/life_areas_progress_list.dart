import 'package:flutter/material.dart';

import '../../../../../app/kratos_theme.dart';
import '../../../../../app/kratos_card_tokens.dart';
import 'life_areas_radar_models.dart';

/// Supporting Life Area Progress List for the Life Areas Overview section.
///
/// Implements synchronized hover and tap interaction with the Radar chart:
/// - Each row displays domain icon, name, progress %, progress bar, and real XP level metrics.
/// - Active/selected rows receive high-contrast Liquid Glass highlight with Acid Lime accents.
/// - Fully responsive across Desktop, Tablet, and Mobile.
class LifeAreasProgressList extends StatelessWidget {
  final List<RadarLifeAreaEntry> entries;
  final String? selectedId;
  final String? hoveredId;
  final ValueChanged<String?>? onSelected;
  final ValueChanged<String?>? onHovered;

  const LifeAreasProgressList({
    super.key,
    required this.entries,
    this.selectedId,
    this.hoveredId,
    this.onSelected,
    this.onHovered,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _LifeAreaProgressRow(
            entry: entries[i],
            isSelected: entries[i].id == selectedId,
            isHovered: entries[i].id == hoveredId,
            onTap: () {
              if (selectedId == entries[i].id) {
                onSelected?.call(null); // Toggle off
              } else {
                onSelected?.call(entries[i].id);
              }
            },
            onHover: (hovering) {
              onHovered?.call(hovering ? entries[i].id : null);
            },
          ),
        ],
      ],
    );
  }
}

class _LifeAreaProgressRow extends StatefulWidget {
  final RadarLifeAreaEntry entry;
  final bool isSelected;
  final bool isHovered;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  const _LifeAreaProgressRow({
    required this.entry,
    required this.isSelected,
    required this.isHovered,
    required this.onTap,
    required this.onHover,
  });

  @override
  State<_LifeAreaProgressRow> createState() => _LifeAreaProgressRowState();
}

class _LifeAreaProgressRowState extends State<_LifeAreaProgressRow> {
  bool _localHover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = theme.extension<KratosCardTokens>();

    final isHighlighted = widget.isSelected || widget.isHovered || _localHover;
    final limeAccent = isDark
        ? KratosTheme.acidLime
        : KratosTheme.lightAcidLime;

    final primaryText = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final secondaryText = isDark
        ? Colors.white.withValues(alpha: 0.60)
        : KratosTheme.lightTextSecondary;

    // Background & border treatment
    final rowBg = isDark
        ? (isHighlighted
              ? const Color(0xFF1B201B)
              : const Color(0xFF101311).withValues(alpha: 0.70))
        : (isHighlighted
              ? const Color(0xFFF0F5EC)
              : const Color(0xFFF7F8FA).withValues(alpha: 0.90));

    final rowBorder = isHighlighted
        ? limeAccent.withValues(alpha: isDark ? 0.60 : 0.80)
        : (isDark
              ? Colors.white.withValues(alpha: 0.07)
              : const Color(0x140F172A));

    final iconBg = isDark
        ? (isHighlighted ? const Color(0xFF262C25) : const Color(0xFF181C19))
        : (isHighlighted ? const Color(0xFFE4EDE0) : const Color(0xFFECEFF3));

    final rowRadius = tokens != null ? tokens.radius * 0.75 : 12.0;

    return Semantics(
      button: true,
      label:
          '${widget.entry.name}, ${widget.entry.displayPct} percent progress, ${widget.entry.xpInLevel} of ${widget.entry.xpToNext} XP in level ${widget.entry.level} ${widget.entry.tier}',
      selected: widget.isSelected,
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _localHover = true);
          widget.onHover(true);
        },
        onExit: (_) {
          setState(() => _localHover = false);
          widget.onHover(false);
        },
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: rowBg,
              borderRadius: BorderRadius.circular(rowRadius),
              border: Border.all(
                color: rowBorder,
                width: isHighlighted ? 1.4 : 1.0,
              ),
              boxShadow: isHighlighted
                  ? [
                      BoxShadow(
                        color: limeAccent.withValues(
                          alpha: isDark ? 0.12 : 0.08,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // ── 1. Icon Container ─────────────────────────────────────
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isHighlighted
                          ? limeAccent.withValues(alpha: 0.40)
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.transparent),
                    ),
                  ),
                  child: Icon(
                    widget.entry.icon,
                    size: 20,
                    color: isHighlighted ? limeAccent : primaryText,
                  ),
                ),

                const SizedBox(width: 14),

                // ── 2. Content: Title, Progress Bar, Metrics ──────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top row: Name & Percentage
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              widget.entry.name,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: isHighlighted
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isHighlighted ? limeAccent : primaryText,
                                letterSpacing: -0.1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.entry.displayPct}%',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isHighlighted ? limeAccent : primaryText,
                              fontFamily: 'GeistMono',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 7),

                      // Middle: Animated Progress Track
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Container(
                          height: 5.5,
                          width: double.infinity,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : const Color(0x180F172A),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: widget.entry.normalizedProgress,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              decoration: BoxDecoration(
                                color: isHighlighted
                                    ? limeAccent
                                    : (isDark
                                          ? Colors.white.withValues(alpha: 0.85)
                                          : const Color(0xFF1E293B)),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Bottom: Real XP in-level metric & Tier info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              '${_formatXp(widget.entry.xpInLevel)} / ${_formatXp(widget.entry.xpToNext)} XP',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: secondaryText,
                                fontFamily: 'GeistMono',
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Lvl ${widget.entry.level} • ${widget.entry.tier}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatXp(int val) {
    if (val >= 1000) {
      final whole = val ~/ 1000;
      final remainder = (val % 1000) ~/ 100;
      if (remainder > 0) {
        return '$whole,${(val % 1000).toString().padLeft(3, '0')}';
      }
      return '$whole,000';
    }
    return val.toString();
  }
}
