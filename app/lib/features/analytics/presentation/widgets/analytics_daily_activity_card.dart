import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/kratos_skeleton.dart';
import '../../../../app/kratos_theme.dart';
import '../../../../app/kratos_visuals.dart';
import '../../domain/analytics_models.dart';

/// KRATOS Analytics — Wave 09: This Week / Daily Activity Analytics Card.
///
/// Production implementation displaying daily performance data:
/// - Real persisted data from Drift SQLite / Supabase XP ledger & tasks tables
/// - Daily XP earned & daily tasks completed
/// - Grouped dual-bar visualization with custom painter & exact numeric labels
/// - Best Day card with deterministic metric (highest XP -> highest tasks -> earliest date)
/// - Total XP, Tasks Completed, and Average XP/Day summary with comparison deltas
/// - 7 daily performance cards with consistency icons and proportional progress bars
/// - Fully respects global and local Analytics Date Range and Life Area filters
/// - High-contrast Liquid Glass UI in both Dark Volcanic & Light Architectural Frost
class AnalyticsDailyActivityCard extends StatefulWidget {
  final AnalyticsSnapshot? snapshot;
  final bool isLoading;
  final String periodSubtitle;
  final VoidCallback? onRetry;
  final List<({String id, String name})>? lifeAreas;
  final String? selectedLifeAreaId;
  final ValueChanged<String?>? onLifeAreaChanged;
  final AnalyticsPeriod? selectedPeriod;
  final ValueChanged<AnalyticsPeriod>? onPeriodChanged;

  const AnalyticsDailyActivityCard({
    super.key,
    required this.snapshot,
    this.isLoading = false,
    this.periodSubtitle = 'vs previous week',
    this.onRetry,
    this.lifeAreas,
    this.selectedLifeAreaId,
    this.onLifeAreaChanged,
    this.selectedPeriod,
    this.onPeriodChanged,
  });

  @override
  State<AnalyticsDailyActivityCard> createState() =>
      _AnalyticsDailyActivityCardState();
}

/// Convenience alias to match "This Week" spec nomenclature.
typedef AnalyticsThisWeekCard = AnalyticsDailyActivityCard;

class _AnalyticsDailyActivityCardState
    extends State<AnalyticsDailyActivityCard> {
  int? _hoveredDayIndex;
  Offset? _hoverLocalPosition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryTextColor =
        isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final secondaryTextColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : KratosTheme.lightTextSecondary;
    final limeAccent =
        isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime;
    final oliveAccent =
        isDark ? const Color(0xFFA3B838) : const Color(0xFF7E8B24);

    if (widget.isLoading) {
      return _buildSkeletonCard(context, isDark);
    }

    final snapshot = widget.snapshot;
    if (snapshot == null || snapshot.dailyGrowthSeries.isEmpty) {
      return _buildEmptyCard(context, isDark);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final isMobile = cardWidth < 680;
        final isTablet = cardWidth >= 680 && cardWidth < 1040;

        final days = snapshot.dailyGrowthSeries;

        // ── Real Computations from Selected Range ──────────────────────
        final totalXp = days.fold<int>(0, (sum, d) => sum + d.xp);
        final totalTasks =
            days.fold<int>(0, (sum, d) => sum + d.tasksCompleted);
        final daysCount = days.isNotEmpty ? days.length : 1;
        final avgXpPerDay = (totalXp / daysCount).round();

        // Previous period averages and deltas
        final prevDaysCount = daysCount;
        final prevAvgXpPerDay = (snapshot.previousTotalXp / prevDaysCount).round();
        final avgXpDelta = MetricDelta.compute(
          current: avgXpPerDay.toDouble(),
          previous: prevAvgXpPerDay.toDouble(),
        );

        final tasksDelta = MetricDelta.compute(
          current: totalTasks.toDouble(),
          previous: snapshot.previousCompletedTasks.toDouble(),
        );

        // Best Day calculation (deterministic: highest XP -> highest tasks -> earliest date)
        DailyAnalyticsPoint? bestDay;
        var maxDayXp = 0;
        var maxDayTasks = 0;
        for (final d in days) {
          if (d.xp > maxDayXp ||
              (d.xp == maxDayXp && d.tasksCompleted > maxDayTasks && d.xp > 0)) {
            maxDayXp = d.xp;
            maxDayTasks = d.tasksCompleted;
            bestDay = d;
          }
        }
        if (maxDayXp == 0 && days.every((d) => d.tasksCompleted == 0)) {
          bestDay = null;
        }

        // Section Title: Dynamic based on period
        final currentPeriod =
            widget.selectedPeriod ?? snapshot.range.period ?? AnalyticsPeriod.week;
        final isWeekView = currentPeriod == AnalyticsPeriod.week ||
            currentPeriod == AnalyticsPeriod.sevenDays;
        final sectionTitle = isWeekView ? 'This Week' : 'Daily Activity';
        final sectionSubtitle = isWeekView
            ? 'Your daily activity and XP progress. See how consistent you are across the week.'
            : 'Your daily activity and XP progress across the selected period.';

        return KratosGlassCard(
          padding: EdgeInsets.all(isMobile ? 16 : 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. HEADER ROW ──────────────────────────────────────
              _buildHeader(
                context,
                isDark: isDark,
                isMobile: isMobile,
                title: sectionTitle,
                subtitle: sectionSubtitle,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                limeAccent: limeAccent,
              ),

              SizedBox(height: isMobile ? 18 : 22),

              // ── 2. MAIN VISUALIZATION + SUMMARY ROW ────────────────
              if (isMobile || isTablet)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildChartCard(
                      context,
                      isDark: isDark,
                      isMobile: isMobile,
                      days: days,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      limeAccent: limeAccent,
                      oliveAccent: oliveAccent,
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryPanel(
                      context,
                      isDark: isDark,
                      isMobile: isMobile,
                      bestDay: bestDay,
                      totalXp: totalXp,
                      xpDelta: snapshot.xpDelta,
                      totalTasks: totalTasks,
                      tasksDelta: tasksDelta,
                      avgXpPerDay: avgXpPerDay,
                      avgXpDelta: avgXpDelta,
                      periodSubtitle: widget.periodSubtitle,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      limeAccent: limeAccent,
                      oliveAccent: oliveAccent,
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Daily Chart (Flex: 3)
                    Expanded(
                      flex: 3,
                      child: _buildChartCard(
                        context,
                        isDark: isDark,
                        isMobile: false,
                        days: days,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        limeAccent: limeAccent,
                        oliveAccent: oliveAccent,
                      ),
                    ),
                    const SizedBox(width: 18),
                    // Summary Cards (Flex: 2)
                    Expanded(
                      flex: 2,
                      child: _buildSummaryPanel(
                        context,
                        isDark: isDark,
                        isMobile: false,
                        bestDay: bestDay,
                        totalXp: totalXp,
                        xpDelta: snapshot.xpDelta,
                        totalTasks: totalTasks,
                        tasksDelta: tasksDelta,
                        avgXpPerDay: avgXpPerDay,
                        avgXpDelta: avgXpDelta,
                        periodSubtitle: widget.periodSubtitle,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        limeAccent: limeAccent,
                        oliveAccent: oliveAccent,
                      ),
                    ),
                  ],
                ),

              SizedBox(height: isMobile ? 18 : 22),

              // ── 3. DAILY CARDS ROW ─────────────────────────────────
              _buildDailyCardsRow(
                context,
                isDark: isDark,
                isMobile: isMobile,
                days: days,
                bestDayDate: bestDay?.date,
                maxDayXp: maxDayXp,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                limeAccent: limeAccent,
                oliveAccent: oliveAccent,
              ),
            ],
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HEADER
  // ───────────────────────────────────────────────────────────────────────────

  // ───────────────────────────────────────────────────────────────────────────
  // HEADER
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context, {
    required bool isDark,
    required bool isMobile,
    required String title,
    required String subtitle,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color limeAccent,
  }) {
    final iconBox = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? const Color(0x22EEFF08) : const Color(0x1F658F00),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: limeAccent.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Icon(
        Icons.calendar_month_rounded,
        size: 20,
        color: limeAccent,
      ),
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isMobile ? 18 : 21,
            fontWeight: FontWeight.w700,
            color: primaryTextColor,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: isMobile ? 12 : 12.5,
            color: secondaryTextColor,
            height: 1.3,
          ),
        ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        iconBox,
        const SizedBox(width: 12),
        Expanded(child: titleBlock),
        if (!isMobile) ...[
          const SizedBox(width: 12),
          _buildRangeBadge(isDark, secondaryTextColor),
        ],
      ],
    );
  }

  Widget _buildRangeBadge(bool isDark, Color textColor) {
    final range = widget.snapshot?.range;
    final startStr = range != null ? _formatShortDate(range.start) : '';
    final endStr = range != null
        ? _formatShortDate(range.end.subtract(const Duration(days: 1)))
        : '';
    final text = (startStr.isNotEmpty && endStr.isNotEmpty)
        ? '$startStr – $endStr'
        : 'Daily View';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0x0C0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0x140F172A),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.date_range_outlined,
            size: 13,
            color: textColor,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MAIN DAILY CHART
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildChartCard(
    BuildContext context, {
    required bool isDark,
    required bool isMobile,
    required List<DailyAnalyticsPoint> days,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color limeAccent,
    required Color oliveAccent,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0x33000000)
            : const Color(0x08000000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0x140F172A),
        ),
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart Legend Row (Responsive Wrap to avoid overflow on mobile)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Text(
                'XP',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: secondaryTextColor,
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildLegendItem(
                    color: limeAccent,
                    label: 'XP Earned',
                    textColor: secondaryTextColor,
                  ),
                  _buildLegendItem(
                    color: oliveAccent,
                    label: 'Tasks Completed',
                    textColor: secondaryTextColor,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Chart canvas with mouse tracking
          SizedBox(
            height: isMobile ? 240 : 270,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chartWidth = constraints.maxWidth;
                final chartHeight = constraints.maxHeight;

                return MouseRegion(
                  onHover: (event) {
                    final localPos = event.localPosition;
                    final dayIndex = _calculateHoveredIndex(
                      localPos.dx,
                      chartWidth,
                      days.length,
                    );
                    if (_hoveredDayIndex != dayIndex ||
                        _hoverLocalPosition != localPos) {
                      setState(() {
                        _hoveredDayIndex = dayIndex;
                        _hoverLocalPosition = localPos;
                      });
                    }
                  },
                  onExit: (_) {
                    if (_hoveredDayIndex != null) {
                      setState(() {
                        _hoveredDayIndex = null;
                        _hoverLocalPosition = null;
                      });
                    }
                  },
                  child: Stack(
                    children: [
                      RepaintBoundary(
                        child: CustomPaint(
                          size: Size(chartWidth, chartHeight),
                          painter: _DailyGroupedBarChartPainter(
                            days: days,
                            isDark: isDark,
                            limeColor: limeAccent,
                            oliveColor: oliveAccent,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            hoveredIndex: _hoveredDayIndex,
                          ),
                        ),
                      ),
                      if (_hoveredDayIndex != null &&
                          _hoveredDayIndex! >= 0 &&
                          _hoveredDayIndex! < days.length)
                        _buildFloatingTooltip(
                          days[_hoveredDayIndex!],
                          chartWidth,
                          chartHeight,
                          isDark,
                          primaryTextColor,
                          secondaryTextColor,
                          limeAccent,
                          oliveAccent,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  int? _calculateHoveredIndex(double dx, double width, int count) {
    if (count == 0) return null;
    const yAxisWidth = 42.0;
    final plotWidth = width - yAxisWidth;
    if (dx < yAxisWidth || dx > width) return null;
    final relX = dx - yAxisWidth;
    final colWidth = plotWidth / count;
    final index = (relX / colWidth).floor();
    return index.clamp(0, count - 1);
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required Color textColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingTooltip(
    DailyAnalyticsPoint point,
    double chartWidth,
    double chartHeight,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color limeAccent,
    Color oliveAccent,
  ) {
    const tooltipWidth = 160.0;
    const tooltipHeight = 78.0;

    double left = (_hoverLocalPosition?.dx ?? (chartWidth / 2)) - (tooltipWidth / 2);
    left = left.clamp(48.0, chartWidth - tooltipWidth - 8.0);

    double top = (_hoverLocalPosition?.dy ?? 40.0) - tooltipHeight - 12.0;
    if (top < 10) top = (_hoverLocalPosition?.dy ?? 40.0) + 16.0;

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Container(
          width: tooltipWidth,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xF2141814) : const Color(0xF7FFFFFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.16)
                  : const Color(0x240F172A),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_formatDayOfWeek(point.date)}, ${_formatShortDate(point.date)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: limeAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_formatNumber(point.xp)} XP Earned',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: oliveAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${point.tasksCompleted} Tasks Done',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
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

  // ───────────────────────────────────────────────────────────────────────────
  // SUMMARY PANEL (BEST DAY + 3 STAT CARDS)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildSummaryPanel(
    BuildContext context, {
    required bool isDark,
    required bool isMobile,
    required DailyAnalyticsPoint? bestDay,
    required int totalXp,
    required MetricDelta xpDelta,
    required int totalTasks,
    required MetricDelta tasksDelta,
    required int avgXpPerDay,
    required MetricDelta avgXpDelta,
    required String periodSubtitle,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color limeAccent,
    required Color oliveAccent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Best Day Card ───────────────────────────────────────────
        _buildBestDayCard(
          context,
          isDark: isDark,
          isMobile: isMobile,
          bestDay: bestDay,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
          limeAccent: limeAccent,
        ),

        const SizedBox(height: 12),

        // ── 3 Summary Stat Cards Row ────────────────────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            final panelWidth = constraints.maxWidth;
            final stackCards = isMobile || panelWidth < 460;
            final period = widget.selectedPeriod ??
                widget.snapshot?.range.period ??
                AnalyticsPeriod.sevenDays;
            final isWeekView = period == AnalyticsPeriod.week ||
                period == AnalyticsPeriod.sevenDays;
            final statSubtitle = isWeekView ? 'vs previous week' : 'vs prior period';

            final cardTotalXp = _buildStatCard(
              context,
              isDark: isDark,
              icon: Icons.bar_chart_rounded,
              iconColor: limeAccent,
              title: 'Total XP',
              value: _formatNumber(totalXp),
              delta: xpDelta,
              subtitle: statSubtitle,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
            );

            final cardTasks = _buildStatCard(
              context,
              isDark: isDark,
              icon: Icons.check_box_outlined,
              iconColor: oliveAccent,
              title: 'Tasks Completed',
              value: _formatNumber(totalTasks),
              delta: tasksDelta,
              subtitle: statSubtitle,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
            );

            final cardAvg = _buildStatCard(
              context,
              isDark: isDark,
              icon: Icons.bolt_rounded,
              iconColor: limeAccent,
              title: 'Avg. per Day',
              value: '${_formatNumber(avgXpPerDay)} XP',
              delta: avgXpDelta,
              subtitle: statSubtitle,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
            );

            if (stackCards) {
              return Column(
                children: [
                  cardTotalXp,
                  const SizedBox(height: 8),
                  cardTasks,
                  const SizedBox(height: 8),
                  cardAvg,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: cardTotalXp),
                const SizedBox(width: 8),
                Expanded(child: cardTasks),
                const SizedBox(width: 8),
                Expanded(child: cardAvg),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBestDayCard(
    BuildContext context, {
    required bool isDark,
    required bool isMobile,
    required DailyAnalyticsPoint? bestDay,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color limeAccent,
  }) {
    final hasActivity = bestDay != null && (bestDay.xp > 0 || bestDay.tasksCompleted > 0);
    final dayTitle = hasActivity ? _formatFullDayOfWeek(bestDay.date) : 'No Peak Day';
    final metricsText = hasActivity
        ? '${_formatNumber(bestDay.xp)} XP  •  ${bestDay.tasksCompleted} tasks'
        : '0 XP  •  0 tasks';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0x4D141814) : const Color(0xFFF8FAF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasActivity
              ? limeAccent.withValues(alpha: isDark ? 0.40 : 0.50)
              : (isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0x1F0F172A)),
          width: hasActivity ? 1.5 : 1,
        ),
        boxShadow: [
          if (hasActivity)
            BoxShadow(
              color: limeAccent.withValues(alpha: isDark ? 0.12 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 18,
        vertical: isMobile ? 14 : 16,
      ),
      child: Row(
        children: [
          // Glowing Trophy Container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0x29EEFF08) : const Color(0x24658F00),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: limeAccent.withValues(alpha: 0.50),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: limeAccent.withValues(alpha: isDark ? 0.20 : 0.12),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              color: limeAccent,
              size: 26,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Best Day',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dayTitle,
                  style: TextStyle(
                    fontSize: isMobile ? 19 : 22,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  metricsText,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required MetricDelta delta,
    required String subtitle,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final deltaText = delta.changePct == 0 && delta.previous == 0
        ? '0.0%'
        : delta.formattedPercent;

    final isPositive = delta.isPositive;
    final deltaColor = delta.isNeutral
        ? secondaryTextColor
        : (isPositive
            ? (isDark ? const Color(0xFFC6F135) : const Color(0xFF558B2F))
            : (isDark ? const Color(0xFFFF5252) : const Color(0xFFD32F2F)));

    final deltaIcon = delta.isNeutral
        ? null
        : (isPositive
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0x33141814) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0x140F172A),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (deltaIcon != null) ...[
                Icon(deltaIcon, size: 12, color: deltaColor),
                const SizedBox(width: 2),
              ],
              Text(
                deltaText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: deltaColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: secondaryTextColor.withValues(alpha: 0.8),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DAILY CARDS ROW (7 DAYS)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildDailyCardsRow(
    BuildContext context, {
    required bool isDark,
    required bool isMobile,
    required List<DailyAnalyticsPoint> days,
    required DateTime? bestDayDate,
    required int maxDayXp,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color limeAccent,
    required Color oliveAccent,
  }) {
    // Determine the days to display in bottom cards.
    // If more than 7 days in period, display the 7 most recent days or scroll.
    final displayDays = days.length <= 7 ? days : days.sublist(days.length - 7);

    final cardWidgets = [
      for (final day in displayDays)
        _buildSingleDailyCard(
          context,
          day: day,
          isDark: isDark,
          isBestDay: bestDayDate != null &&
              day.date.year == bestDayDate.year &&
              day.date.month == bestDayDate.month &&
              day.date.day == bestDayDate.day &&
              (day.xp > 0 || day.tasksCompleted > 0),
          maxDayXp: maxDayXp,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
          limeAccent: limeAccent,
          oliveAccent: oliveAccent,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        // On desktop with enough space, display evenly spaced cards
        if (availableWidth >= 880 && cardWidgets.length <= 7) {
          return Row(
            children: [
              for (var i = 0; i < cardWidgets.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: cardWidgets[i]),
              ],
            ],
          );
        }

        // On tablet/mobile or when more cards, render horizontal scrollable row
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (var i = 0; i < cardWidgets.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                SizedBox(width: 124, child: cardWidgets[i]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSingleDailyCard(
    BuildContext context, {
    required DailyAnalyticsPoint day,
    required bool isDark,
    required bool isBestDay,
    required int maxDayXp,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color limeAccent,
    required Color oliveAccent,
  }) {
    // Consistency Icon selection based on activity volume
    final IconData statusIcon;
    final Color statusIconColor;
    if (day.xp >= (maxDayXp * 0.70) && day.xp > 0) {
      statusIcon = Icons.wb_sunny_rounded;
      statusIconColor = isDark ? const Color(0xFFFFEE58) : const Color(0xFFFBC02D);
    } else if (day.xp >= (maxDayXp * 0.30) && day.xp > 0) {
      statusIcon = Icons.wb_cloudy_rounded;
      statusIconColor = isDark ? const Color(0xFFDCE775) : const Color(0xFFAFB42B);
    } else if (day.xp > 0 || day.tasksCompleted > 0) {
      statusIcon = Icons.cloud_outlined;
      statusIconColor = secondaryTextColor;
    } else {
      statusIcon = Icons.cloud_outlined;
      statusIconColor = secondaryTextColor.withValues(alpha: 0.5);
    }

    // Relative progress ratio
    final double progressRatio = maxDayXp > 0
        ? (day.xp / maxDayXp).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? (isBestDay ? const Color(0x3D141814) : const Color(0x2E141814))
            : (isBestDay ? const Color(0xFFF9FDF4) : const Color(0xFFFFFFFF)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBestDay
              ? limeAccent.withValues(alpha: 0.85)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0x140F172A)),
          width: isBestDay ? 1.5 : 1,
        ),
        boxShadow: [
          if (isBestDay)
            BoxShadow(
              color: limeAccent.withValues(alpha: isDark ? 0.18 : 0.12),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Day + Date + Weather/Consistency Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDayOfWeek(day.date),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                  Text(
                    _formatShortDate(day.date),
                    style: TextStyle(
                      fontSize: 11,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
              Icon(
                statusIcon,
                size: 20,
                color: statusIconColor,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // XP Row
          Row(
            children: [
              Icon(
                Icons.wb_sunny_outlined,
                size: 13,
                color: limeAccent,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${_formatNumber(day.xp)} XP',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Tasks Row
          Row(
            children: [
              Icon(
                Icons.check_box_outlined,
                size: 13,
                color: oliveAccent,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${day.tasksCompleted} tasks',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: secondaryTextColor,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 4,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : const Color(0x140F172A),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progressRatio,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        limeAccent.withValues(alpha: 0.70),
                        limeAccent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SKELETON & EMPTY STATES
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildSkeletonCard(BuildContext context, bool isDark) {
    return KratosGlassCard(
      padding: const EdgeInsets.all(22),
      child: KratosShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                KratosBone(width: 44, height: 44, borderRadius: BorderRadius.circular(12)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KratosBone(width: 140, height: 22, borderRadius: BorderRadius.circular(6)),
                      const SizedBox(height: 6),
                      KratosBone(width: 260, height: 14, borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            KratosBone(width: double.infinity, height: 240, borderRadius: BorderRadius.circular(16)),
            const SizedBox(height: 18),
            Row(
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: KratosBone(width: double.infinity, height: 110, borderRadius: BorderRadius.circular(14)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context, bool isDark) {
    final primaryTextColor = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final secondaryTextColor = isDark ? Colors.white70 : KratosTheme.lightTextSecondary;

    return KratosGlassCard(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 40,
                color: secondaryTextColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'No activity in this period',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Complete tasks, log focus sessions, or change your date filter to view activity.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: secondaryTextColor,
                ),
              ),
              if (widget.onRetry != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTER FOR GROUPED BAR CHART
// ─────────────────────────────────────────────────────────────────────────────

class _DailyGroupedBarChartPainter extends CustomPainter {
  final List<DailyAnalyticsPoint> days;
  final bool isDark;
  final Color limeColor;
  final Color oliveColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final int? hoveredIndex;

  _DailyGroupedBarChartPainter({
    required this.days,
    required this.isDark,
    required this.limeColor,
    required this.oliveColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;

    const yAxisWidth = 42.0;
    const xAxisHeight = 36.0;
    final plotLeft = yAxisWidth;
    final plotTop = 18.0;
    final plotRight = size.width;
    final plotBottom = size.height - xAxisHeight;
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;

    if (plotWidth <= 0 || plotHeight <= 0) return;

    // ── 1. Calculate Nice Y-Axis Ticks ────────────────────────────────────────
    final rawMaxXp = days.map((d) => d.xp).fold<int>(0, math.max);
    final rawMaxTasks = days.map((d) => d.tasksCompleted).fold<int>(0, math.max);

    // Compute nice ceiling for XP
    final maxYp = _computeNiceCeiling(rawMaxXp > 0 ? rawMaxXp : 400);
    // Tasks scale max (independent to prevent microscopic task bars)
    final maxTasksCeil = math.max(10, ((rawMaxTasks + 2) ~/ 5 + 1) * 5);

    // ── 2. Draw Horizontal Grid Lines & Y-Axis Labels ─────────────────────────
    const tickCount = 4;
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final yTextPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    for (var i = 0; i <= tickCount; i++) {
      final ratio = i / tickCount;
      final y = plotBottom - (ratio * plotHeight);
      final tickVal = (ratio * maxYp).round();

      // Horizontal grid line
      canvas.drawLine(
        Offset(plotLeft, y),
        Offset(plotRight, y),
        gridPaint,
      );

      // Y-axis label
      yTextPainter.text = TextSpan(
        text: '$tickVal',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: secondaryTextColor.withValues(alpha: 0.70),
        ),
      );
      yTextPainter.layout();
      yTextPainter.paint(
        canvas,
        Offset(plotLeft - yTextPainter.width - 6, y - (yTextPainter.height / 2)),
      );
    }

    // ── 3. Empty State Check ─────────────────────────────────────────────────
    if (rawMaxXp == 0 && rawMaxTasks == 0) {
      final emptyText = TextPainter(
        text: TextSpan(
          text: 'No activity recorded in this period',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: secondaryTextColor.withValues(alpha: 0.70),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      emptyText.paint(
        canvas,
        Offset(
          plotLeft + (plotWidth - emptyText.width) / 2,
          plotTop + (plotHeight - emptyText.height) / 2,
        ),
      );
    }

    // ── 4. Draw Bars & X-Axis Day Labels ─────────────────────────────────────
    final count = days.length;
    final columnWidth = plotWidth / count;
    final barGap = 3.0;

    final valTextPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (var i = 0; i < count; i++) {
      final day = days[i];
      final colCenter = plotLeft + (i + 0.5) * columnWidth;

      // Hover column highlight
      if (hoveredIndex == i) {
        final colRect = Rect.fromLTWH(
          plotLeft + i * columnWidth + 2,
          plotTop,
          columnWidth - 4,
          plotHeight,
        );
        final colPaint = Paint()
          ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(RRect.fromRectAndRadius(colRect, const Radius.circular(8)), colPaint);
      }

      // Responsive Bar Widths (proportional to column space to prevent overlap on 30-day series)
      final availableBarWidth = (columnWidth - barGap).clamp(4.0, 50.0);
      final xpBarWidth = (availableBarWidth * 0.52).clamp(2.0, 26.0);
      final tasksBarWidth = (availableBarWidth * 0.36).clamp(1.5, 18.0);
      final showValueLabels = count <= 10;
      final isHovered = hoveredIndex == i;

      // Heights
      final xpHeight = rawMaxXp > 0
          ? ((day.xp / maxYp) * plotHeight).clamp(0.0, plotHeight)
          : 0.0;
      final tasksHeight = rawMaxTasks > 0
          ? ((day.tasksCompleted / maxTasksCeil) * (plotHeight * 0.85)).clamp(0.0, plotHeight * 0.85)
          : 0.0;

      // XP Bar Position (Left of center)
      final xpLeft = colCenter - xpBarWidth - (barGap / 2);
      final xpTop = plotBottom - xpHeight;

      // Draw XP Bar
      if (day.xp > 0) {
        final xpRect = Rect.fromLTWH(xpLeft, xpTop, xpBarWidth, xpHeight);
        final xpGradient = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            limeColor,
            limeColor.withValues(alpha: isDark ? 0.40 : 0.60),
          ],
        );
        final xpPaint = Paint()
          ..shader = xpGradient.createShader(xpRect)
          ..style = PaintingStyle.fill;

        canvas.drawRRect(
          RRect.fromRectAndCorners(
            xpRect,
            topLeft: const Radius.circular(6),
            topRight: const Radius.circular(6),
          ),
          xpPaint,
        );

        // Numeric label above XP bar (shown on weekly views or when hovered)
        if (showValueLabels || isHovered) {
          valTextPainter.text = TextSpan(
            text: '${day.xp}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
            ),
          );
          valTextPainter.layout();
          valTextPainter.paint(
            canvas,
            Offset(
              xpLeft + (xpBarWidth - valTextPainter.width) / 2,
              xpTop - valTextPainter.height - 2,
            ),
          );
        }
      }

      // Tasks Bar Position (Right of center)
      final tasksLeft = colCenter + (barGap / 2);
      final tasksTop = plotBottom - tasksHeight;

      // Draw Tasks Bar
      if (day.tasksCompleted > 0) {
        final tasksRect = Rect.fromLTWH(tasksLeft, tasksTop, tasksBarWidth, tasksHeight);
        final tasksGradient = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            oliveColor,
            oliveColor.withValues(alpha: isDark ? 0.45 : 0.65),
          ],
        );
        final tasksPaint = Paint()
          ..shader = tasksGradient.createShader(tasksRect)
          ..style = PaintingStyle.fill;

        canvas.drawRRect(
          RRect.fromRectAndCorners(
            tasksRect,
            topLeft: const Radius.circular(5),
            topRight: const Radius.circular(5),
          ),
          tasksPaint,
        );

        // Numeric label above Tasks bar (shown on weekly views or when hovered)
        if (showValueLabels || isHovered) {
          valTextPainter.text = TextSpan(
            text: '${day.tasksCompleted}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: oliveColor,
            ),
          );
          valTextPainter.layout();
          valTextPainter.paint(
            canvas,
            Offset(
              tasksLeft + (tasksBarWidth - valTextPainter.width) / 2,
              tasksTop - valTextPainter.height - 2,
            ),
          );
        }
      }

      // X-Axis Day Labels (Decluttered on > 10 day views)
      final step = count > 14 ? (count / 6).ceil() : (count > 7 ? 2 : 1);
      if (i % step == 0 || i == count - 1 || isHovered) {
        valTextPainter.text = TextSpan(
          children: [
            if (count <= 14)
              TextSpan(
                text: '${_formatDayOfWeek(day.date)}\n',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isHovered ? limeColor : primaryTextColor,
                ),
              ),
            TextSpan(
              text: _formatShortDate(day.date),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isHovered ? primaryTextColor : secondaryTextColor,
              ),
            ),
          ],
        );
        valTextPainter.layout();
        valTextPainter.paint(
          canvas,
          Offset(colCenter - (valTextPainter.width / 2), plotBottom + 5),
        );
      }
    }
  }

  int _computeNiceCeiling(int value) {
    if (value <= 50) return 50;
    if (value <= 100) return 100;
    if (value <= 200) return 200;
    if (value <= 400) return 400;
    if (value <= 600) return 600;
    if (value <= 1000) return 1000;
    final magnitude = math.pow(10, (math.log(value) / math.ln10).floor()).toInt();
    return ((value / magnitude).ceil()) * magnitude;
  }

  @override
  bool shouldRepaint(covariant _DailyGroupedBarChartPainter oldDelegate) {
    return oldDelegate.days != days ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.isDark != isDark ||
        oldDelegate.limeColor != limeColor ||
        oldDelegate.oliveColor != oliveColor;
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _formatNumber(int val) {
  final s = val.abs().toString();
  final result = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) {
      result.write(',');
    }
    result.write(s[i]);
  }
  return '${val < 0 ? '-' : ''}$result';
}

String _formatShortDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[d.month - 1]} ${d.day}';
}

String _formatDayOfWeek(DateTime d) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days[d.weekday - 1];
}

String _formatFullDayOfWeek(DateTime d) {
  const days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  return days[d.weekday - 1];
}
