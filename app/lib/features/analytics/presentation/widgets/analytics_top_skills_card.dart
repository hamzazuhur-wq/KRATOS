import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/kratos_skeleton.dart';
import '../../../../app/kratos_theme.dart';
import '../../../../app/kratos_visuals.dart';
import '../../domain/analytics_models.dart';
import 'top_skills/skill_trend_chart.dart';

/// KRATOS Analytics — Wave 08: Top Skills Card.
///
/// Production implementation displaying the user's most developed skills
/// based on authoritative KRATOS activity and XP allocation data.
///
/// Product Contract Guarantees:
/// - Skills ≠ Tools (strictly learned competencies, never tools inventory)
/// - Authoritative KRATOS Mastery Ranks: D, C, B, A, S
/// - Real database values (period XP, growth deltas, contribution %, trend series)
/// - Deterministic ranking order
/// - Full date range & life area filter awareness
/// - Responsive composition (Desktop two-column, Mobile stacked)
/// - Unified KRATOS Liquid Glass Card System integration
class AnalyticsTopSkillsCard extends StatefulWidget {
  final AnalyticsSnapshot? snapshot;
  final bool isLoading;
  final String periodSubtitle;
  final VoidCallback? onRetry;
  final String? initialSelectedSkillId;
  final ValueChanged<String>? onSkillSelected;
  final ValueChanged<String?>? onLifeAreaChanged;
  final List<({String id, String name})>? lifeAreas;
  final String? selectedLifeAreaId;

  const AnalyticsTopSkillsCard({
    super.key,
    required this.snapshot,
    this.isLoading = false,
    this.periodSubtitle = 'Last 30 Days',
    this.onRetry,
    this.initialSelectedSkillId,
    this.onSkillSelected,
    this.onLifeAreaChanged,
    this.lifeAreas,
    this.selectedLifeAreaId,
  });

  @override
  State<AnalyticsTopSkillsCard> createState() => _AnalyticsTopSkillsCardState();
}

class _AnalyticsTopSkillsCardState extends State<AnalyticsTopSkillsCard> {
  static const int _defaultTopCount = 6;

  String? _selectedSkillId;
  bool _showAllSkills = false;

  @override
  void initState() {
    super.initState();
    _selectedSkillId = widget.initialSelectedSkillId;
  }

  @override
  void didUpdateWidget(AnalyticsTopSkillsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelectedSkillId != oldWidget.initialSelectedSkillId) {
      _selectedSkillId = widget.initialSelectedSkillId;
    }
  }

  void _selectSkill(String id) {
    setState(() {
      _selectedSkillId = id;
    });
    widget.onSkillSelected?.call(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.isLoading) {
      return _buildSkeletonCard(context, isDark);
    }

    final allSkills = widget.snapshot?.topSkills ?? const [];

    if (allSkills.isEmpty) {
      return _buildEmptyCard(context, isDark);
    }

    // Auto-select rank #1 skill if none selected or if selected skill is no longer in list
    final hasSelected = allSkills.any((s) => s.id == _selectedSkillId);
    final activeSelectedId = hasSelected ? _selectedSkillId! : allSkills.first.id;
    final selectedSkill = allSkills.firstWhere(
      (s) => s.id == activeSelectedId,
      orElse: () => allSkills.first,
    );

    // Apply Top-N display strategy
    final displayedSkills = _showAllSkills
        ? allSkills
        : allSkills.take(_defaultTopCount).toList();

    // Compute max XP in the active list for proportional progress bar normalization
    final maxXp = allSkills.map((s) => s.periodXp).fold<int>(0, math.max);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 960;
        final isMobile = width < 580;

        return KratosGlassCard(
          variant: KratosSurfaceVariant.normal,
          borderRadius: BorderRadius.circular(20),
          padding: EdgeInsets.all(isCompact ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header & Filter Controls ──────────────────────────────
              _buildHeader(context, isDark, allSkills.length, isMobile: isMobile),

              const SizedBox(height: 18),

              // ── Main Content Area (Responsive Split / Stack) ─────────
              if (isCompact) ...[
                _buildRankedList(
                  context,
                  isDark,
                  allSkills: allSkills,
                  displayedSkills: displayedSkills,
                  selectedId: activeSelectedId,
                  maxXp: maxXp,
                ),
                const SizedBox(height: 20),
                Divider(
                  color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1F0F172A),
                  height: 1,
                  thickness: 1,
                ),
                const SizedBox(height: 20),
                _buildDetailPanel(context, isDark, selectedSkill),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Ranked Skills List (~56%)
                    Expanded(
                      flex: 14,
                      child: _buildRankedList(
                        context,
                        isDark,
                        allSkills: allSkills,
                        displayedSkills: displayedSkills,
                        selectedId: activeSelectedId,
                        maxXp: maxXp,
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Vertical Liquid Glass Separator
                    Container(
                      width: 1,
                      height: math.max(380, displayedSkills.length * 68.0),
                      color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1F0F172A),
                    ),
                    const SizedBox(width: 24),
                    // Right Column: Selected Skill Detail Panel (~44%)
                    Expanded(
                      flex: 11,
                      child: _buildDetailPanel(context, isDark, selectedSkill),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CARD HEADER & CONTROLS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    int totalCount, {
    required bool isMobile,
  }) {
    final titleColor = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.60)
        : KratosTheme.lightTextSecondary;

    final titleSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.military_tech_outlined,
                  size: 20,
                  color: isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime,
                ),
                const SizedBox(width: 8),
                Text(
                  'Top Skills',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: titleColor,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0x1AFFFFFF)
                    : const Color(0x0F0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? const Color(0x22FFFFFF)
                      : const Color(0x140F172A),
                  width: 0.8,
                ),
              ),
              child: Text(
                '$totalCount tracked',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : KratosTheme.lightTextSecondary,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Your most developed skills based on real activity and XP allocation.',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
            color: subtitleColor,
            height: 1.35,
          ),
        ),
      ],
    );

    final hasFilter = widget.lifeAreas != null && widget.lifeAreas!.isNotEmpty;

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          titleSection,
          if (hasFilter) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: _buildLifeAreaFilterPill(context, isDark),
            ),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: titleSection),
        if (hasFilter) ...[
          const SizedBox(width: 12),
          _buildLifeAreaFilterPill(context, isDark),
        ],
      ],
    );
  }

  Widget _buildLifeAreaFilterPill(BuildContext context, bool isDark) {
    final areas = widget.lifeAreas!;
    final currentAreaId = widget.selectedLifeAreaId;
    final currentArea = areas.where((a) => a.id == currentAreaId).firstOrNull;
    final label = currentArea?.name ?? 'All Areas';

    return PopupMenuButton<String?>(
      tooltip: 'Filter by Life Area',
      onSelected: (id) => widget.onLifeAreaChanged?.call(id),
      color: isDark ? const Color(0xFF141815) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? const Color(0x26FFFFFF) : const Color(0x1F0F172A),
          width: 0.8,
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String?>(
          value: null,
          child: Text(
            'All Life Areas',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: currentAreaId == null ? FontWeight.w700 : FontWeight.w500,
              color: currentAreaId == null
                  ? (isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime)
                  : (isDark ? Colors.white : KratosTheme.lightTextPrimary),
            ),
          ),
        ),
        const PopupMenuDivider(height: 1),
        ...areas.map(
          (area) => PopupMenuItem<String?>(
            value: area.id,
            child: Text(
              area.name,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: currentAreaId == area.id ? FontWeight.w700 : FontWeight.w500,
                color: currentAreaId == area.id
                    ? (isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime)
                    : (isDark ? Colors.white : KratosTheme.lightTextPrimary),
              ),
            ),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0x14FFFFFF) : const Color(0x0F0F172A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0x24FFFFFF) : const Color(0x1F0F172A),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list,
              size: 14,
              color: isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 14,
              color: isDark ? Colors.white54 : KratosTheme.lightTextMuted,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LEFT COLUMN: RANKED SKILL LIST
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRankedList(
    BuildContext context,
    bool isDark, {
    required List<AnalyticsSkillMetric> allSkills,
    required List<AnalyticsSkillMetric> displayedSkills,
    required String selectedId,
    required int maxXp,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // List Column Headers
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  'RANK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'SKILL CAPABILITY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
                  ),
                ),
              ),
              Text(
                'XP & GROWTH',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
                ),
              ),
            ],
          ),
        ),

        // Ranked Rows
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayedSkills.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final skill = displayedSkills[index];
            final rankNumber = index + 1;
            final isSelected = skill.id == selectedId;
            final ratio = maxXp > 0 ? (skill.periodXp / maxXp).clamp(0.04, 1.0) : 0.04;

            return _SkillRowItem(
              skill: skill,
              rankNumber: rankNumber,
              isSelected: isSelected,
              relativeProgress: ratio,
              isDark: isDark,
              onTap: () => _selectSkill(skill.id),
            );
          },
        ),

        // Expand / Collapse Footer if more skills exist
        if (allSkills.length > _defaultTopCount) ...[
          const SizedBox(height: 10),
          Center(
            child: InkWell(
              onTap: () {
                setState(() {
                  _showAllSkills = !_showAllSkills;
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _showAllSkills
                          ? 'Show Top $_defaultTopCount'
                          : 'View all ${allSkills.length} skills',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showAllSkills ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 16,
                      color: isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RIGHT COLUMN: SELECTED SKILL DETAIL PANEL
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDetailPanel(
    BuildContext context,
    bool isDark,
    AnalyticsSkillMetric skill,
  ) {
    final rankColor = _getSkillRankColor(skill.rank, isDark);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x12FFFFFF) : const Color(0x0A0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x22FFFFFF) : const Color(0x1F0F172A),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Detail Header: Icon + Name + Mastery Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: rankColor.withValues(alpha: isDark ? 0.16 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: rankColor.withValues(alpha: isDark ? 0.40 : 0.30),
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.psychology_outlined,
                    size: 24,
                    color: rankColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      skill.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (skill.groupName != null || skill.lifeAreaName != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (skill.groupName != null && skill.groupName!.isNotEmpty)
                            skill.groupName!,
                          if (skill.lifeAreaName != null && skill.lifeAreaName!.isNotEmpty)
                            skill.lifeAreaName!,
                        ].join(' • '),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white60 : KratosTheme.lightTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Large KRATOS Rank Badge
              _MasteryRankBadge(rank: skill.rank, isDark: isDark, isLarge: true),
            ],
          ),

          const SizedBox(height: 18),

          // Primary Readout: Period XP & Growth Delta
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x0FFFFFFF) : const Color(0x080F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0x18FFFFFF) : const Color(0x140F172A),
                width: 0.8,
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PERIOD GAIN',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_formatNumber(skill.periodXp)} XP',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'VS PREVIOUS',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildDeltaPill(skill.xpDelta, isDark),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Secondary KPI Grid (2x2)
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'ALL-TIME XP',
                  value: '${_formatNumber(skill.allTimeXp)} XP',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  title: 'CONTRIBUTION',
                  value: '${skill.contributionPct.toStringAsFixed(1)}%',
                  isDark: isDark,
                  accentColor: isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'TASKS COMPLETED',
                  value: '${skill.completedTasksCount}',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  title: 'FOCUS TIME',
                  value: _formatMinutes(skill.focusMinutes),
                  isDark: isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Sparkline Trend Section
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'XP ACCELERATION TREND',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 2,
                    color: rankColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Current',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : KratosTheme.lightTextSecondary,
                    ),
                  ),
                  if (skill.previousXpOverTime.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 2,
                      color: isDark ? Colors.white24 : KratosTheme.lightTextMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Prior',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // CustomPainter Sparkline Chart
          SkillTrendChart(
            currentSeries: skill.xpOverTime,
            previousSeries: skill.previousXpOverTime,
            accentColor: rankColor,
            height: 100,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required bool isDark,
    Color? accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x0AFFFFFF) : const Color(0x060F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0x14FFFFFF) : const Color(0x0F0F172A),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: accentColor ?? (isDark ? Colors.white : KratosTheme.lightTextPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeltaPill(MetricDelta delta, bool isDark) {
    final isPositive = delta.isPositive;
    final isNegative = delta.isNegative;
    final isNeutral = !isPositive && !isNegative;

    final Color badgeColor;
    final IconData icon;

    if (isPositive) {
      badgeColor = isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime;
      icon = Icons.arrow_drop_up;
    } else if (isNegative) {
      badgeColor = isDark ? const Color(0xFFFF5252) : const Color(0xFFDC2626);
      icon = Icons.arrow_drop_down;
    } else {
      badgeColor = isDark ? Colors.white38 : KratosTheme.lightTextMuted;
      icon = Icons.remove;
    }

    final formattedPct = isNeutral ? '0.0%' : delta.formattedPercent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: badgeColor.withValues(alpha: isDark ? 0.40 : 0.30),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: badgeColor),
          Text(
            formattedPct,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SKELETON / LOADING & EMPTY STATES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSkeletonCard(BuildContext context, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 960;
        return KratosGlassCard(
          variant: KratosSurfaceVariant.normal,
          borderRadius: BorderRadius.circular(20),
          padding: EdgeInsets.all(isCompact ? 16 : 22),
          child: KratosShimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    KratosBone(width: 160, height: 22, borderRadius: BorderRadius.circular(6)),
                    KratosBone(width: 90, height: 26, borderRadius: BorderRadius.circular(10)),
                  ],
                ),
                const SizedBox(height: 8),
                KratosBone(width: 240, height: 14, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 24),
                if (isCompact) ...[
                  for (var i = 0; i < 4; i++) ...[
                    KratosBone(
                      width: double.infinity,
                      height: 54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 16),
                  KratosBone(
                    width: double.infinity,
                    height: 260,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 14,
                        child: Column(
                          children: [
                            for (var i = 0; i < 5; i++) ...[
                              KratosBone(
                                width: double.infinity,
                                height: 54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 11,
                        child: KratosBone(
                          width: double.infinity,
                          height: 320,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyCard(BuildContext context, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 580;
        final titleColor = isDark ? Colors.white : KratosTheme.lightTextPrimary;
        final subtitleColor = isDark
            ? Colors.white.withValues(alpha: 0.60)
            : KratosTheme.lightTextSecondary;

        return KratosGlassCard(
          variant: KratosSurfaceVariant.normal,
          borderRadius: BorderRadius.circular(20),
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context, isDark, 0, isMobile: isMobile),
          const SizedBox(height: 36),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x14FFFFFF) : const Color(0x0F0F172A),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0x22FFFFFF) : const Color(0x140F172A),
                    ),
                  ),
                  child: Icon(
                    Icons.auto_awesome_outlined,
                    size: 26,
                    color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'No skill activity recorded yet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Text(
                    'Attach skills to tasks, sessions, and projects or earn XP to see your strongest capabilities develop here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: subtitleColor,
                      height: 1.4,
                    ),
                  ),
                ),
                if (widget.onRetry != null) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
      },
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER FORMATTERS
// ─────────────────────────────────────────────────────────────────────────────

String _formatNumber(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 100000) {
    return '${(value / 1000).toStringAsFixed(1)}k';
  }
  final s = value.toString();
  final chars = s.split('');
  final buffer = StringBuffer();
  for (var i = 0; i < chars.length; i++) {
    if (i > 0 && (chars.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(chars[i]);
  }
  return buffer.toString();
}

String _formatMinutes(int minutes) {
  if (minutes <= 0) return '0h';
  if (minutes < 60) return '${minutes}m';
  final hours = minutes / 60.0;
  return '${hours.toStringAsFixed(1)}h';
}

// ─────────────────────────────────────────────────────────────────────────────
// SKILL ROW ITEM WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _SkillRowItem extends StatefulWidget {
  final AnalyticsSkillMetric skill;
  final int rankNumber;
  final bool isSelected;
  final double relativeProgress;
  final bool isDark;
  final VoidCallback onTap;

  const _SkillRowItem({
    required this.skill,
    required this.rankNumber,
    required this.isSelected,
    required this.relativeProgress,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_SkillRowItem> createState() => _SkillRowItemState();
}

class _SkillRowItemState extends State<_SkillRowItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final skill = widget.skill;
    final isSelected = widget.isSelected;
    final isDark = widget.isDark;
    final rankColor = _getSkillRankColor(skill.rank, isDark);

    final bgColor = isSelected
        ? (isDark ? const Color(0x22FFFFFF) : const Color(0x180F172A))
        : (_isHovered
            ? (isDark ? const Color(0x14FFFFFF) : const Color(0x0C0F172A))
            : (isDark ? const Color(0x0AFFFFFF) : const Color(0x060F172A)));

    final borderColor = isSelected
        ? (isDark ? KratosTheme.acidLime.withValues(alpha: 0.65) : KratosTheme.lightAcidLime)
        : (_isHovered
            ? (isDark ? const Color(0x2EFFFFFF) : const Color(0x260F172A))
            : (isDark ? const Color(0x16FFFFFF) : const Color(0x120F172A)));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 1.2 : 0.8,
            ),
            boxShadow: isSelected && isDark
                ? [
                    BoxShadow(
                      color: KratosTheme.acidLime.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Numeric Rank Badge (1, 2, 3...)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: widget.rankNumber <= 3
                          ? rankColor.withValues(alpha: isDark ? 0.20 : 0.15)
                          : (isDark ? const Color(0x18FFFFFF) : const Color(0x0F0F172A)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.rankNumber <= 3
                            ? rankColor.withValues(alpha: isDark ? 0.60 : 0.40)
                            : (isDark ? const Color(0x22FFFFFF) : const Color(0x140F172A)),
                        width: 0.8,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.rankNumber}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: widget.rankNumber <= 3
                              ? rankColor
                              : (isDark ? Colors.white70 : KratosTheme.lightTextSecondary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Skill Name & KRATOS Rank Badge
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            skill.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _MasteryRankBadge(rank: skill.rank, isDark: isDark),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // XP Value & Delta %
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_formatNumber(skill.periodXp)} XP',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildInlineDelta(skill.xpDelta, isDark),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Proportional Progress Bar Indicator
              Stack(
                children: [
                  Container(
                    height: 3.5,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F0F172A),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: widget.relativeProgress,
                    child: Container(
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: rankColor,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: isDark && isSelected
                            ? [
                                BoxShadow(
                                  color: rankColor.withValues(alpha: 0.6),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineDelta(MetricDelta delta, bool isDark) {
    final isPos = delta.isPositive;
    final isNeg = delta.isNegative;
    final isZero = !isPos && !isNeg;

    final color = isPos
        ? (isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime)
        : (isNeg
            ? (isDark ? const Color(0xFFFF5252) : const Color(0xFFDC2626))
            : (isDark ? Colors.white38 : KratosTheme.lightTextMuted));

    final text = isZero ? '0%' : delta.formattedPercent;

    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MASTERY RANK BADGE (D, C, B, A, S)
// ─────────────────────────────────────────────────────────────────────────────

class _MasteryRankBadge extends StatelessWidget {
  final SkillRank rank;
  final bool isDark;
  final bool isLarge;

  const _MasteryRankBadge({
    required this.rank,
    required this.isDark,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getSkillRankColor(rank, isDark);
    final letter = rank.name.toUpperCase();

    if (isLarge) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.20 : 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.60 : 0.40),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'RANK',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: color.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              letter,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.50 : 0.35),
          width: 0.8,
        ),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1.1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RANK COLOR MAPPING FUNCTION (D, C, B, A, S)
// ─────────────────────────────────────────────────────────────────────────────

Color _getSkillRankColor(SkillRank rank, bool isDark) {
  return switch (rank) {
    SkillRank.d => const Color(0xFF64748B), // Neutral Slate
    SkillRank.c => isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7), // Cool Cyan / Sky
    SkillRank.b => isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706), // Warm Amber / Gold
    SkillRank.a => isDark ? const Color(0xFFEEFF08) : const Color(0xFF658F00), // Acid Lime
    SkillRank.s => isDark ? const Color(0xFF00F5FF) : const Color(0xFF0E7490), // Radiant Cyan / Lime
  };
}
