import 'package:flutter/material.dart';

import '../../../../app/kratos_motion.dart';
import '../../../../app/kratos_theme.dart';
import '../../../../app/kratos_visuals.dart';
import '../../domain/analytics_models.dart';
import '../insights_screen.dart';

/// KRATOS Analytics — Complete Insights Section.
///
/// Strictly displays data-backed Positive Trends derived from real KRATOS data:
/// Raw KRATOS Data → Analytics Repository → Analytics Snapshot → Positive Trend Detector → UI.
///
/// Adheres strictly to Master Product Decision:
/// - NO AI/LLM recommendations
/// - NO "Opportunities"
/// - NO motivational advice
/// - NO fake data
/// - Purely answers: "What is objectively improving in my data?"
class AnalyticsInsightsCard extends StatefulWidget {
  final AnalyticsSnapshot snapshot;
  final String? periodSubtitle;
  final VoidCallback? onViewAllTap;

  const AnalyticsInsightsCard({
    super.key,
    required this.snapshot,
    this.periodSubtitle,
    this.onViewAllTap,
  });

  @override
  State<AnalyticsInsightsCard> createState() => _AnalyticsInsightsCardState();
}

class _AnalyticsInsightsCardState extends State<AnalyticsInsightsCard> {
  bool _isNavigating = false;

  void _handleViewAll() {
    if (_isNavigating) return;
    if (widget.onViewAllTap != null) {
      widget.onViewAllTap!();
      return;
    }
    _isNavigating = true;
    Navigator.of(context).push(
      KratosPageRoute(
        page: InsightsScreen(
          snapshot: widget.snapshot,
          periodSubtitle: widget.periodSubtitle,
        ),
        settings: const RouteSettings(name: '/insights'),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    });
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

    // Retrieve verified positive trends directly from snapshot (top 3 for preview)
    final allTrends = widget.snapshot.safePositiveTrends;
    final displayedTrends = allTrends.take(3).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isMobile = availableWidth < 680;
        final isTablet = availableWidth >= 680 && availableWidth < 960;

        return KratosGlassCard(
          padding: EdgeInsets.all(isMobile ? 18 : 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Header: Lightbulb Icon + Title + Subtitle + Action ────────
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
                        const SizedBox(height: 1),
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
                  if (allTrends.isNotEmpty)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: InkWell(
                        key: const ValueKey('insights_view_all_button'),
                        onTap: _handleViewAll,
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
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: limeAccent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // ── 2. Content: Positive Trends Grid or Clean Empty State ────────
              if (allTrends.isEmpty)
                _buildEmptyState(
                  isDark: isDark,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  tileBg: tileBg,
                  borderColor: borderColor,
                )
              else if (isMobile)
                Column(
                  children: [
                    for (var i = 0; i < displayedTrends.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _buildPositiveTrendCard(
                        trend: displayedTrends[i],
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
              else if (isTablet)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final trend in displayedTrends)
                      SizedBox(
                        width: (availableWidth - 12 - (isMobile ? 36 : 44)) / 2,
                        child: _buildPositiveTrendCard(
                          trend: trend,
                          isDark: isDark,
                          tileBg: tileBg,
                          borderColor: borderColor,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                          limeAccent: limeAccent,
                        ),
                      ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < displayedTrends.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(
                        child: _buildPositiveTrendCard(
                          trend: displayedTrends[i],
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
            ],
          ),
        );
      },
    );
  }

  /// Individual Positive Trend Card matching the visual reference.
  Widget _buildPositiveTrendCard({
    required PositiveTrendInsight trend,
    required bool isDark,
    required Color tileBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color limeAccent,
  }) {
    final iconData = _resolveIcon(trend.iconIdentifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Box + Title Row
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0x1FEFFF08)
                      : const Color(0x1A84CC16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Icon(
                    iconData,
                    size: 16,
                    color: limeAccent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  trend.title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Primary Value + Trend Arrow Badge
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                trend.currentValueFormatted,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: primaryTextColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0x22EEFF08)
                      : const Color(0x1F84CC16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.north_rounded,
                      size: 11,
                      color: limeAccent,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      trend.deltaFormatted,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: limeAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Factual Description / Comparison Label
          Text(
            trend.factualDescription,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              color: secondaryTextColor,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Clean, non-motivational Empty State when data is insufficient.
  Widget _buildEmptyState({
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color tileBg,
    required Color borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.query_stats_rounded,
            size: 32,
            color: secondaryTextColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 10),
          Text(
            'No significant positive trends yet.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Keep using KRATOS and trends will appear as enough data accumulates.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _resolveIcon(String identifier) {
    return switch (identifier) {
      'timer' => Icons.timer_outlined,
      'bolt' => Icons.bolt_rounded,
      'speed' => Icons.speed_rounded,
      'check_circle' => Icons.check_circle_outline_rounded,
      'calendar' => Icons.calendar_today_rounded,
      'repeat' => Icons.repeat_rounded,
      'category' => Icons.category_outlined,
      _ => Icons.trending_up_rounded,
    };
  }
}
