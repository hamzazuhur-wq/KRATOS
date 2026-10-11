import 'package:flutter/material.dart';

import '../../../../../app/kratos_theme.dart';
import '../../../../../app/kratos_visuals.dart';
import '../../../domain/analytics_models.dart';
import 'focus_time_formatters.dart';

/// Insights Card matching the master visual reference:
/// - Lightbulb icon + "Insights" + "Smart insights from your data." + "View All →"
/// - 3 Insight Cards in a row (or stacked on mobile):
///    1. Peak Focus Time (10:00 AM – 12:00 PM, "Your most productive hours.")
///    2. Most Focused Day (Tuesday, "2h 32m average")
///    3. Focus Trend (↑ 24%, "vs last week")
/// - Interactive "View All →" that displays all derived patterns in an elegant modal.
class FocusTimeInsightsCard extends StatelessWidget {
  final FocusTimeSnapshot snapshot;
  final String periodSubtitle;
  final VoidCallback? onViewAllTap;

  const FocusTimeInsightsCard({
    super.key,
    required this.snapshot,
    this.periodSubtitle = 'vs last week',
    this.onViewAllTap,
  });

  IconData _iconForIdentifier(String? id) {
    switch (id) {
      case 'bolt':
        return Icons.bolt_rounded;
      case 'calendar':
        return Icons.calendar_today_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'brain':
        return Icons.psychology_rounded;
      case 'target':
        return Icons.track_changes_rounded;
      case 'calendar_sync':
        return Icons.event_repeat_rounded;
      case 'timer':
        return Icons.hourglass_bottom_rounded;
      default:
        return Icons.lightbulb_outline_rounded;
    }
  }

  void _handleViewAll(BuildContext context) {
    if (onViewAllTap != null) {
      onViewAllTap!();
      return;
    }
    _showAllInsightsModal(context);
  }

  void _showAllInsightsModal(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryTextColor = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final secondaryTextColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : KratosTheme.lightTextSecondary;
    final limeAccent = isDark ? KratosTheme.acidLime : KratosTheme.classicAcidLime;
    final cardBg = isDark ? const Color(0xFF131518) : Colors.white;
    final tileBg = isDark ? const Color(0x12FFFFFF) : const Color(0x080F172A);
    final borderColor = isDark ? const Color(0x26FFFFFF) : const Color(0x1F0F172A);

    final allInsights = snapshot.derivedInsights;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            maxWidth: 680,
          ),
          margin: EdgeInsets.only(
            top: 40,
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x33FFFFFF) : const Color(0x220F172A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0x2EEFFF08)
                            : const Color(0x2284CC16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.lightbulb_outline_rounded,
                          color: limeAccent,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'All Focus Insights',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          Text(
                            'Objectively derived patterns from your actual session activity.',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: secondaryTextColor),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // List of insights
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  shrinkWrap: true,
                  itemCount: allInsights.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (ctx, index) {
                    final item = allInsights[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: tileBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0x2EEFFF08)
                                  : const Color(0x2284CC16),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Icon(
                                _iconForIdentifier(item.iconIdentifier),
                                color: limeAccent,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: secondaryTextColor,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '#${index + 1}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: limeAccent,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.valueFormatted,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: primaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryTextColor = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final secondaryTextColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : KratosTheme.lightTextSecondary;
    final limeAccent = isDark ? KratosTheme.acidLime : KratosTheme.classicAcidLime;

    final tileBg = isDark ? const Color(0x12FFFFFF) : const Color(0x080F172A);
    final borderColor = isDark ? const Color(0x26FFFFFF) : const Color(0x1F0F172A);

    // Dynamic metrics from snapshot
    final previewInsights = snapshot.previewInsights;
    final hasPreviews = previewInsights.isNotEmpty;

    // Fallback metrics if preview list is empty
    final peakTimeStr = FocusTimeFormatters.formatHourWindow(snapshot.peakWindowStartHour);
    final bestDayStr = snapshot.mostFocusedWeekday != null
        ? FocusTimeFormatters.weekdayFull(snapshot.mostFocusedWeekday!)
        : 'None';
    final bestDayAvgStr = snapshot.mostFocusedWeekdayAvgMs > 0
        ? '${FocusTimeFormatters.formatDurationHhMm(snapshot.mostFocusedWeekdayAvgMs)} average'
        : 'No average focus recorded';
    final trendStr = FocusTimeFormatters.formatTrend(snapshot.trendPercent);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 750;

        return KratosGlassCard(
          padding: EdgeInsets.all(isMobile ? 18 : 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row: Lightbulb Icon + Title + Subtitle + View All Button ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0x2EEFFF08)
                          : const Color(0x2284CC16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.lightbulb_outline_rounded,
                        color: limeAccent,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Insights',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: primaryTextColor,
                          ),
                        ),
                        Text(
                          'Smart insights from your data.',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: InkWell(
                      key: const ValueKey('focus_time_insights_view_all_button'),
                      onTap: () => _handleViewAll(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View All',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: limeAccent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 14, color: limeAccent),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── 3 Insight Tiles (Dynamic from previewInsights, fallback to baseline) ──
              if (hasPreviews) ...[
                if (isMobile)
                  Column(
                    children: [
                      for (var i = 0; i < previewInsights.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        _buildInsightTile(
                          icon: _iconForIdentifier(previewInsights[i].iconIdentifier),
                          title: previewInsights[i].title,
                          highlight: previewInsights[i].valueFormatted,
                          description: previewInsights[i].subtitle,
                          isDark: isDark,
                          tileBg: tileBg,
                          borderColor: borderColor,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                          limeAccent: limeAccent,
                        ),
                      ],
                    ],
                  )
                else
                  Row(
                    children: [
                      for (var i = 0; i < previewInsights.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(
                          child: _buildInsightTile(
                            icon: _iconForIdentifier(previewInsights[i].iconIdentifier),
                            title: previewInsights[i].title,
                            highlight: previewInsights[i].valueFormatted,
                            description: previewInsights[i].subtitle,
                            isDark: isDark,
                            tileBg: tileBg,
                            borderColor: borderColor,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            limeAccent: limeAccent,
                          ),
                        ),
                      ],
                    ],
                  ),
              ] else ...[
                // Fallback 3 static tiles
                if (isMobile)
                  Column(
                    children: [
                      _buildInsightTile(
                        icon: Icons.bolt_rounded,
                        title: 'Peak Focus Time',
                        highlight: peakTimeStr,
                        description: 'Your most productive hours.',
                        isDark: isDark,
                        tileBg: tileBg,
                        borderColor: borderColor,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        limeAccent: limeAccent,
                      ),
                      const SizedBox(height: 10),
                      _buildInsightTile(
                        icon: Icons.calendar_today_rounded,
                        title: 'Most Focused Day',
                        highlight: bestDayStr,
                        description: bestDayAvgStr,
                        isDark: isDark,
                        tileBg: tileBg,
                        borderColor: borderColor,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        limeAccent: limeAccent,
                      ),
                      const SizedBox(height: 10),
                      _buildInsightTile(
                        icon: Icons.trending_up_rounded,
                        title: 'Focus Trend',
                        highlight: trendStr,
                        description: periodSubtitle,
                        isDark: isDark,
                        tileBg: tileBg,
                        borderColor: borderColor,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        limeAccent: limeAccent,
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _buildInsightTile(
                          icon: Icons.bolt_rounded,
                          title: 'Peak Focus Time',
                          highlight: peakTimeStr,
                          description: 'Your most productive hours.',
                          isDark: isDark,
                          tileBg: tileBg,
                          borderColor: borderColor,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                          limeAccent: limeAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInsightTile(
                          icon: Icons.calendar_today_rounded,
                          title: 'Most Focused Day',
                          highlight: bestDayStr,
                          description: bestDayAvgStr,
                          isDark: isDark,
                          tileBg: tileBg,
                          borderColor: borderColor,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                          limeAccent: limeAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInsightTile(
                          icon: Icons.trending_up_rounded,
                          title: 'Focus Trend',
                          highlight: trendStr,
                          description: periodSubtitle,
                          isDark: isDark,
                          tileBg: tileBg,
                          borderColor: borderColor,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                          limeAccent: limeAccent,
                        ),
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

  Widget _buildInsightTile({
    required IconData icon,
    required String title,
    required String highlight,
    required String description,
    required bool isDark,
    required Color tileBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color limeAccent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0x2EEFFF08)
                      : const Color(0x2284CC16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Icon(icon, color: limeAccent, size: 16),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            highlight,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: primaryTextColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            description,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              color: secondaryTextColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
