import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../app/kratos_theme.dart';
import '../../domain/analytics_models.dart';

/// KRATOS Analytics — Consistency Floating Detail Window.
///
/// Pops up floating directly over the Analytics screen without navigating away
/// or replacing the page. The permanent KRATOS background remains clearly visible.
///
/// Displays real consistency and streak metrics derived from the currently active
/// filter context (Date Range, Life Area, and Source).
class ConsistencyFloatingDetail extends StatelessWidget {
  final AnalyticsSnapshot snapshot;
  final String periodLabel;
  final String periodSubtitle;
  final String lifeAreaName;
  final String sourceName;
  final VoidCallback onClose;

  const ConsistencyFloatingDetail({
    super.key,
    required this.snapshot,
    required this.periodLabel,
    required this.periodSubtitle,
    required this.lifeAreaName,
    required this.sourceName,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    final dialogWidth = math.min(480.0, screenWidth - 32.0);
    final maxHeight = screenHeight * 0.85;

    final panelBg = isDark
        ? const Color(0xF2121714)
        : const Color(0xF8FFFFFF);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : const Color(0x220F172A);

    final titleColor = isDark
        ? Colors.white
        : KratosTheme.lightTextPrimary;

    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : KratosTheme.lightTextSecondary;

    final limeAccent = isDark
        ? KratosTheme.acidLime
        : KratosTheme.lightAcidLime;

    final isPositive = snapshot.consistencyDelta.isPositive;
    final pctString =
        '${isPositive ? '+' : ''}${snapshot.consistencyDelta.changePct.abs().toStringAsFixed(1)}%';

    final totalDays = math.max(1, snapshot.range.dayCount);
    final activeDays = snapshot.activeDaysCount > 0
        ? snapshot.activeDaysCount
        : (snapshot.currentStreak > 0 ? snapshot.currentStreak : 0);
    final consistencyPercent = snapshot.consistencyDelta.current;

    return Stack(
      children: [
        // ── 1. Translucent Backdrop (Dismiss on tap) ─────────────────────────
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.28),
            ),
          ),
        ),

        // ── 2. Floating Liquid Glass Window ──────────────────────────────────
        Center(
          child: Container(
            width: dialogWidth,
            constraints: BoxConstraints(maxHeight: maxHeight),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: panelBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.25),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header Row ──────────────────────────────────────────
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: limeAccent.withValues(alpha: isDark ? 0.20 : 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: limeAccent.withValues(alpha: isDark ? 0.35 : 0.45),
                              width: 0.8,
                            ),
                          ),
                          child: Icon(
                            Icons.local_fire_department_outlined,
                            size: 18,
                            color: limeAccent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Consistency & Streak Detail',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: subtitleColor,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: onClose,
                          tooltip: 'Close',
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Filter Context Chips Row ────────────────────────────
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _ContextChip(
                          icon: Icons.calendar_today_outlined,
                          label: periodLabel,
                          isDark: isDark,
                        ),
                        _ContextChip(
                          icon: Icons.track_changes_outlined,
                          label: lifeAreaName,
                          isDark: isDark,
                        ),
                        _ContextChip(
                          icon: Icons.tune_rounded,
                          label: sourceName,
                          isDark: isDark,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Primary Hero Highlight ──────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: limeAccent.withValues(alpha: isDark ? 0.08 : 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: limeAccent.withValues(alpha: isDark ? 0.25 : 0.30),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$activeDays Days Active',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPositive
                                        ? Icons.arrow_upward_rounded
                                        : Icons.arrow_downward_rounded,
                                    size: 13,
                                    color: isPositive
                                        ? limeAccent
                                        : const Color(0xFFFF5252),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    pctString,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isPositive
                                          ? limeAccent
                                          : const Color(0xFFFF5252),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Active on $activeDays of $totalDays days in selected range (${consistencyPercent.toStringAsFixed(1)}% consistency) $periodSubtitle',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── 2x2 Key Metric Tiles ────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _DetailMetricTile(
                            title: 'Active Days',
                            value: '$activeDays / $totalDays',
                            subtitle: 'in selected range',
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DetailMetricTile(
                            title: 'Current Streak',
                            value: '${snapshot.currentStreak} days',
                            subtitle: 'active consecutive',
                            isDark: isDark,
                            accentValue: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _DetailMetricTile(
                            title: 'Longest Streak',
                            value: '${snapshot.longestStreak} days',
                            subtitle: 'personal record',
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DetailMetricTile(
                            title: 'Previous Period',
                            value: '${snapshot.consistencyDelta.previous.toStringAsFixed(1)}%',
                            subtitle: 'equivalent consistency',
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ── Weekly Activity Distribution ────────────────────────
                    Text(
                      'Activity by Day of Week',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _WeekdayActivityBarChart(
                      activityByDay: snapshot.activityByDayOfWeek,
                      limeColor: limeAccent,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 20),

                    // ── Close Action Button ─────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onClose,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: titleColor,
                          side: BorderSide(color: borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Dismiss',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContextChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _ContextChip({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0x120F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0x1F0F172A),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: isDark
                ? Colors.white.withValues(alpha: 0.60)
                : KratosTheme.lightTextSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.85)
                  : KratosTheme.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final bool isDark;
  final bool accentValue;

  const _DetailMetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.isDark,
    this.accentValue = false,
  });

  @override
  Widget build(BuildContext context) {
    final limeAccent = isDark
        ? KratosTheme.acidLime
        : KratosTheme.lightAcidLime;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0x0A0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.09)
              : const Color(0x140F172A),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.55)
                  : KratosTheme.lightTextMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: accentValue
                  ? limeAccent
                  : (isDark ? Colors.white : KratosTheme.lightTextPrimary),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.45)
                  : KratosTheme.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayActivityBarChart extends StatelessWidget {
  final Map<int, int> activityByDay;
  final Color limeColor;
  final bool isDark;

  const _WeekdayActivityBarChart({
    required this.activityByDay,
    required this.limeColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const daysLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final maxActivity = math.max(
      1,
      [for (var i = 1; i <= 7; i++) activityByDay[i] ?? 0].reduce(math.max),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : const Color(0x080F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0x120F172A),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 1; i <= 7; i++) ...[
            _DayBarItem(
              label: daysLabels[i - 1],
              count: activityByDay[i] ?? 0,
              ratio: ((activityByDay[i] ?? 0) / maxActivity).clamp(0.12, 1.0),
              limeColor: limeColor,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }
}

class _DayBarItem extends StatelessWidget {
  final String label;
  final int count;
  final double ratio;
  final Color limeColor;
  final bool isDark;

  const _DayBarItem({
    required this.label,
    required this.count,
    required this.ratio,
    required this.limeColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 38,
          width: 14,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: math.max(6.0, 38.0 * ratio),
              width: 8,
              decoration: BoxDecoration(
                color: count > 0
                    ? limeColor.withValues(alpha: 0.40 + 0.60 * ratio)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : const Color(0x1A0F172A)),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark
                ? Colors.white.withValues(alpha: 0.65)
                : KratosTheme.lightTextSecondary,
          ),
        ),
      ],
    );
  }
}
