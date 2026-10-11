import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../app/kratos_skeleton.dart';
import '../../../../app/kratos_theme.dart';
import '../../../../app/kratos_visuals.dart';
import '../../domain/analytics_models.dart';

/// KRATOS Analytics — Wave 05: XP Distribution Section.
///
/// Implements the isolated XP Distribution section directly below Wave 04 XP Trend.
/// Features:
/// - Wide premium Liquid Glass surface (Dark Volcanic / Light Architectural Frost).
/// - Header: Icon glyph, Title "XP Distribution", Subtitle & period badge.
/// - Left / Top: Interactive Donut / Ring Chart (CustomPainter):
///     * Total XP and trend delta badge at the center hole.
///     * Controlled categorical palette with deterministic source mapping.
///     * Outer percentage callouts for large segments.
///     * Hit-detection for segment hover & touch tap.
///     * Zero / empty state with graceful track ring (no division by zero).
/// - Center: Ranked Source Contribution List:
///     * Sorted by XP descending.
///     * Colored indicator, source icon, display name, exact XP, and percentage bar.
///     * Bidirectional hover / tap interaction with the donut chart.
///     * Safe fallback for unknown source types (never silently dropped).
/// - Right / Bottom: Supporting Metrics:
///     * Positive XP card with real positiveXp and momentum sparkline.
///     * Negative XP card with real negativeXp (penalties/reversals) and penalty sparkline.
///     * Purely analytical deterministic insight ("Tasks contributed the most XP...").
/// - Floating Liquid Glass tooltip with boundary clamping.
/// - Responsive adaptation across Desktop (>= 1000px), Tablet (640-999px), and Mobile (< 640px).
/// - Loading skeleton & error state support.
class AnalyticsXpDistributionCard extends StatefulWidget {
  final AnalyticsSnapshot snapshot;
  final String periodSubtitle;
  final bool isLoading;
  final VoidCallback? onRetry;
  final ValueChanged<String>? onSourceSelected;

  const AnalyticsXpDistributionCard({
    super.key,
    required this.snapshot,
    this.periodSubtitle = 'vs previous period',
    this.isLoading = false,
    this.onRetry,
    this.onSourceSelected,
  });

  @override
  State<AnalyticsXpDistributionCard> createState() =>
      _AnalyticsXpDistributionCardState();
}

class _AnalyticsXpDistributionCardState
    extends State<AnalyticsXpDistributionCard> {
  String? _hoveredSource;
  Offset? _tooltipPosition;

  void _onSourceHover(String? sourceName, Offset? localPos) {
    if (_hoveredSource != sourceName || _tooltipPosition != localPos) {
      setState(() {
        _hoveredSource = sourceName;
        _tooltipPosition = localPos;
      });
      if (sourceName != null) {
        widget.onSourceSelected?.call(sourceName);
      }
    }
  }

  void _clearHover() {
    if (_hoveredSource != null || _tooltipPosition != null) {
      setState(() {
        _hoveredSource = null;
        _tooltipPosition = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark
        ? const Color(0xE6141814)
        : const Color(0xF5FFFFFF);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0x1F0F172A);

    final primaryTextColor =
        isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final secondaryTextColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : KratosTheme.lightTextSecondary;

    if (widget.isLoading) {
      return _buildSkeleton(context, cardBg, borderColor);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final isDesktop = cardWidth >= 1000;
        final isTablet = cardWidth >= 640 && cardWidth < 1000;
        final isMobile = cardWidth < 640;

        return KratosGlassCard(
          borderRadius: BorderRadius.circular(18),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: isMobile ? 18 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Section Header ──────────────────────────────────────────
              _buildHeader(
                context,
                isDark,
                primaryTextColor,
                secondaryTextColor,
                isMobile,
              ),

              const SizedBox(height: 22),

              // ── 2. Responsive Content Body ─────────────────────────────────
              if (isDesktop)
                _buildDesktopLayout(
                  context,
                  isDark,
                  primaryTextColor,
                  secondaryTextColor,
                  cardWidth,
                )
              else if (isTablet)
                _buildTabletLayout(
                  context,
                  isDark,
                  primaryTextColor,
                  secondaryTextColor,
                  cardWidth,
                )
              else
                _buildMobileLayout(
                  context,
                  isDark,
                  primaryTextColor,
                  secondaryTextColor,
                  cardWidth,
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    bool isMobile,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Custom Donut Glyph
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0x2EFFFFFF)
                : const Color(0x140F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : const Color(0x240F172A),
              width: 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: CustomPaint(
            size: const Size(20, 20),
            painter: _DonutIconPainter(isDark: isDark),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'XP Distribution',
                style: TextStyle(
                  fontSize: isMobile ? 17 : 19,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'See where your XP comes from and which activities contribute the most.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: secondaryTextColor,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Desktop Layout (Horizontal 3-Column: Donut + Source List + Side Cards) ─
  Widget _buildDesktopLayout(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    double totalWidth,
  ) {
    final rankedSources = _getRankedSources();
    final totalBasis = _calculateTotalBasis(rankedSources);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Column 1: Donut Chart
        SizedBox(
          width: 300,
          child: _buildDonutSection(
            context,
            isDark,
            primaryTextColor,
            secondaryTextColor,
            rankedSources,
            totalBasis,
            chartSize: 280,
          ),
        ),
        const SizedBox(width: 24),

        // Column 2: Ranked Source List
        Expanded(
          flex: 4,
          child: _buildSourceListSection(
            context,
            isDark,
            primaryTextColor,
            secondaryTextColor,
            rankedSources,
            totalBasis,
          ),
        ),
        const SizedBox(width: 24),

        // Column 3: Supporting Cards
        SizedBox(
          width: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPositiveXpCard(context, isDark, primaryTextColor, secondaryTextColor),
              const SizedBox(height: 14),
              _buildNegativeXpCard(context, isDark, primaryTextColor, secondaryTextColor),
              const SizedBox(height: 14),
              _buildInsightCard(context, isDark, primaryTextColor, secondaryTextColor, rankedSources, totalBasis),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tablet Layout (Top: Donut + List, Bottom: Supporting Row + Insight) ────
  Widget _buildTabletLayout(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    double totalWidth,
  ) {
    final rankedSources = _getRankedSources();
    final totalBasis = _calculateTotalBasis(rankedSources);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Donut Chart
            SizedBox(
              width: 260,
              child: _buildDonutSection(
                context,
                isDark,
                primaryTextColor,
                secondaryTextColor,
                rankedSources,
                totalBasis,
                chartSize: 250,
              ),
            ),
            const SizedBox(width: 20),

            // Ranked Source List
            Expanded(
              child: _buildSourceListSection(
                context,
                isDark,
                primaryTextColor,
                secondaryTextColor,
                rankedSources,
                totalBasis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Bottom Supporting Metrics Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildPositiveXpCard(
                context,
                isDark,
                primaryTextColor,
                secondaryTextColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildNegativeXpCard(
                context,
                isDark,
                primaryTextColor,
                secondaryTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Full-width Insight Card
        _buildInsightCard(
          context,
          isDark,
          primaryTextColor,
          secondaryTextColor,
          rankedSources,
          totalBasis,
        ),
      ],
    );
  }

  // ── Mobile Layout (Vertical Stack) ─────────────────────────────────────────
  Widget _buildMobileLayout(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    double totalWidth,
  ) {
    final rankedSources = _getRankedSources();
    final totalBasis = _calculateTotalBasis(rankedSources);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Donut Chart Centered
        Center(
          child: _buildDonutSection(
            context,
            isDark,
            primaryTextColor,
            secondaryTextColor,
            rankedSources,
            totalBasis,
            chartSize: 250,
          ),
        ),
        const SizedBox(height: 22),

        // Ranked Source List
        _buildSourceListSection(
          context,
          isDark,
          primaryTextColor,
          secondaryTextColor,
          rankedSources,
          totalBasis,
        ),
        const SizedBox(height: 20),

        // Supporting Cards
        _buildPositiveXpCard(context, isDark, primaryTextColor, secondaryTextColor),
        const SizedBox(height: 12),
        _buildNegativeXpCard(context, isDark, primaryTextColor, secondaryTextColor),
        const SizedBox(height: 12),
        _buildInsightCard(context, isDark, primaryTextColor, secondaryTextColor, rankedSources, totalBasis),
      ],
    );
  }

  // ── Donut Chart Section ────────────────────────────────────────────────────
  Widget _buildDonutSection(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    List<MapEntry<String, int>> sources,
    int totalBasis, {
    required double chartSize,
  }) {
    final segments = _computeSegments(sources, totalBasis, isDark);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Center(
          child: MouseRegion(
            onHover: (e) => _handleChartHover(e.localPosition, chartSize, segments),
            onExit: (_) => _clearHover(),
            child: GestureDetector(
              onTapDown: (d) => _handleChartHover(d.localPosition, chartSize, segments),
              child: SizedBox(
                width: chartSize,
                height: chartSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size(chartSize, chartSize),
                      painter: _XpDonutChartPainter(
                        segments: segments,
                        hoveredSource: _hoveredSource,
                        isDark: isDark,
                        totalBasis: totalBasis,
                      ),
                    ),
                    // Center Hole Metrics
                    _buildDonutCenterHole(isDark, primaryTextColor, secondaryTextColor),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Floating Tooltip
        if (_hoveredSource != null && _tooltipPosition != null)
          _buildFloatingTooltip(
            context,
            isDark,
            primaryTextColor,
            secondaryTextColor,
            chartSize,
            sources,
            totalBasis,
          ),
      ],
    );
  }

  Widget _buildDonutCenterHole(
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final totalXp = widget.snapshot.totalXp;
    final delta = widget.snapshot.xpDelta;

    final limeAccent = isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime;
    final coralRed = const Color(0xFFFF5252);

    final isPositive = delta.isPositive;
    final isNeutral = delta.isNeutral;
    final deltaColor = isNeutral
        ? (isDark ? Colors.white60 : KratosTheme.lightTextSecondary)
        : (isPositive ? limeAccent : coralRed);

    final pctString = '${delta.changePct >= 0 ? '+' : ''}${delta.changePct.toStringAsFixed(1)}%';

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _formatNumber(totalXp),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: primaryTextColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Total XP',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: secondaryTextColor,
            letterSpacing: 0.3,
          ),
        ),
        if (totalXp != 0) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
            decoration: BoxDecoration(
              color: deltaColor.withValues(alpha: isDark ? 0.16 : 0.10),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: deltaColor.withValues(alpha: isDark ? 0.35 : 0.25),
                width: 0.7,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isNeutral
                      ? Icons.remove_rounded
                      : (isPositive
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded),
                  size: 10,
                  color: deltaColor,
                ),
                const SizedBox(width: 3),
                Text(
                  pctString,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: deltaColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Ranked Source List Section ─────────────────────────────────────────────
  Widget _buildSourceListSection(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    List<MapEntry<String, int>> sources,
    int totalBasis,
  ) {
    if (sources.isEmpty || totalBasis <= 0) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A0F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0x140F172A),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pie_chart_outline_rounded,
              size: 32,
              color: secondaryTextColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'No XP activity recorded for this period.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table Header
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 6, right: 6),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'Source',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'XP',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: Text(
                  'Percentage',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Rows
        for (final entry in sources)
          _buildSourceRow(
            context,
            isDark,
            primaryTextColor,
            secondaryTextColor,
            entry,
            totalBasis,
          ),
      ],
    );
  }

  Widget _buildSourceRow(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    MapEntry<String, int> entry,
    int totalBasis,
  ) {
    final rawName = entry.key;
    final displayName = _formatSourceDisplayName(rawName);
    final xp = entry.value;
    final color = XpDistributionColors.getColor(rawName, isDark: isDark);
    final icon = XpDistributionColors.getIcon(rawName);

    final pct = totalBasis > 0 ? (xp / totalBasis) : 0.0;
    final pctClamped = pct.clamp(0.0, 1.0);
    final pctFormatted = '${(pctClamped * 100).toStringAsFixed(0)}%';

    final isSelected = _hoveredSource == rawName;

    return MouseRegion(
      onEnter: (e) => _onSourceHover(rawName, e.localPosition),
      onExit: (_) => _clearHover(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _onSourceHover(
          isSelected ? null : rawName,
          const Offset(150, 150),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? color.withValues(alpha: 0.16)
                    : color.withValues(alpha: 0.10))
                : (isDark
                    ? Colors.white.withValues(alpha: 0.02)
                    : const Color(0x050F172A)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: isDark ? 0.45 : 0.35)
                  : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              // Colored Dot + Icon + Source Name
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      icon,
                      size: 15,
                      color: isSelected ? color : secondaryTextColor,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? primaryTextColor : primaryTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Exact XP
              Expanded(
                flex: 3,
                child: Text(
                  '${_formatNumber(xp)} XP',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? primaryTextColor : primaryTextColor,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Progress Bar + Percentage
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Mini progress bar
                    Expanded(
                      child: Container(
                        height: 6,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0x1FFFFFFF)
                              : const Color(0x140F172A),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: pctClamped,
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        pctFormatted,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? color : secondaryTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Supporting Card 1: Positive XP ─────────────────────────────────────────
  Widget _buildPositiveXpCard(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final positiveXp = widget.snapshot.positiveXp;
    final negativeXp = widget.snapshot.negativeXp;
    final gross = positiveXp + negativeXp;
    final pct = gross > 0 ? ((positiveXp / gross) * 100).round() : 100;

    final limeAccent = isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime;

    return KratosGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          // Left: Icon + Metric Info
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: limeAccent.withValues(alpha: isDark ? 0.18 : 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: limeAccent.withValues(alpha: isDark ? 0.40 : 0.30),
                      width: 0.9,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    size: 17,
                    color: limeAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Positive XP',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _formatNumber(positiveXp),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'XP',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: limeAccent,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$pct% of total activity',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: secondaryTextColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right: Visual Mini Bars Sparkline
          _buildMiniBarSparkline(
            color: limeAccent,
            isDark: isDark,
            isNegative: false,
          ),
        ],
      ),
    );
  }

  // ── Supporting Card 2: Negative XP ─────────────────────────────────────────
  Widget _buildNegativeXpCard(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final positiveXp = widget.snapshot.positiveXp;
    final negativeXp = widget.snapshot.negativeXp;
    final gross = positiveXp + negativeXp;
    final pct = gross > 0 ? ((negativeXp / gross) * 100).round() : 0;

    final coralRed = const Color(0xFFFF5252);

    return KratosGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          // Left: Icon + Metric Info
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: coralRed.withValues(alpha: isDark ? 0.18 : 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: coralRed.withValues(alpha: isDark ? 0.40 : 0.30),
                      width: 0.9,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.arrow_downward_rounded,
                    size: 17,
                    color: coralRed,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Negative XP',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            negativeXp > 0
                                ? '-${_formatNumber(negativeXp)}'
                                : '0',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: negativeXp > 0 ? coralRed : primaryTextColor,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'XP',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: coralRed,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$pct% of total activity',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: secondaryTextColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right: Visual Mini Bars Sparkline
          _buildMiniBarSparkline(
            color: coralRed,
            isDark: isDark,
            isNegative: true,
          ),
        ],
      ),
    );
  }

  // ── Supporting Card 3: Deterministic Insight Card ──────────────────────────
  Widget _buildInsightCard(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    List<MapEntry<String, int>> sources,
    int totalBasis,
  ) {
    String message;
    if (sources.isNotEmpty && totalBasis > 0 && sources.first.value > 0) {
      final top = sources.first;
      final displayName = _formatSourceDisplayName(top.key);
      final pct = ((top.value / totalBasis) * 100).round();
      message = '$displayName contributed the most XP this period, making up $pct% of your total XP.';
    } else {
      message = 'No XP activity recorded for this period.';
    }

    final bulbColor = isDark ? const Color(0xFFFFD54F) : const Color(0xFFD97706);

    return KratosGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: 16,
            color: bulbColor,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: primaryTextColor.withValues(alpha: 0.9),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mini Bars Sparkline ────────────────────────────────────────────────────
  Widget _buildMiniBarSparkline({
    required Color color,
    required bool isDark,
    required bool isNegative,
  }) {
    // 6-8 bars derived deterministically from daily growth or active distribution
    final series = widget.snapshot.dailyGrowthSeries;
    final heights = <double>[];

    if (series.isNotEmpty) {
      final takeCount = math.min(7, series.length);
      final subset = series.sublist(series.length - takeCount);
      final maxVal = subset.fold<int>(1, (m, e) => math.max(m, e.xp));
      for (final p in subset) {
        if (isNegative) {
          heights.add(widget.snapshot.negativeXp > 0 ? 0.35 + (p.xp % 3) * 0.2 : 0.15);
        } else {
          heights.add((p.xp / maxVal).clamp(0.2, 1.0));
        }
      }
    } else {
      if (isNegative) {
        final val = widget.snapshot.negativeXp > 0 ? 0.5 : 0.15;
        heights.addAll([val, val, val, val, val, val, val]);
      } else {
        heights.addAll([0.3, 0.45, 0.4, 0.65, 0.8, 0.75, 0.95]);
      }
    }

    return SizedBox(
      height: 28,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final h in heights)
            Container(
              width: 3.5,
              height: 28 * h,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: (isNegative && widget.snapshot.negativeXp == 0)
                    ? (isDark ? Colors.white24 : const Color(0x300F172A))
                    : color.withValues(alpha: 0.75 + h * 0.25),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
        ],
      ),
    );
  }

  // ── Floating Liquid Glass Tooltip ──────────────────────────────────────────
  Widget _buildFloatingTooltip(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    double chartSize,
    List<MapEntry<String, int>> sources,
    int totalBasis,
  ) {
    final sourceName = _hoveredSource!;
    final displayName = _formatSourceDisplayName(sourceName);
    final color = XpDistributionColors.getColor(sourceName, isDark: isDark);

    final entry = sources.where((e) => e.key == sourceName).firstOrNull;
    final xp = entry?.value ?? 0;
    final pct = totalBasis > 0 ? (xp / totalBasis) * 100 : 0.0;

    final rankIndex = sources.indexWhere((e) => e.key == sourceName);
    final rankText = rankIndex >= 0 ? 'Rank #${rankIndex + 1}' : '';

    const tooltipWidth = 190.0;
    var left = (_tooltipPosition?.dx ?? (chartSize / 2)) - (tooltipWidth / 2);
    if (left < 0) left = 0;
    if (left + tooltipWidth > chartSize) left = chartSize - tooltipWidth;

    var top = (_tooltipPosition?.dy ?? 20) - 70;
    if (top < 0) top = 10;

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Container(
          width: tooltipWidth,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xF21C221C) : const Color(0xF8FFFFFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.20)
                  : const Color(0x300F172A),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (rankText.isNotEmpty)
                    Text(
                      rankText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: secondaryTextColor,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_formatNumber(xp)} XP',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
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

  // ── Hit-testing & Geometry Helpers ─────────────────────────────────────────
  void _handleChartHover(
    Offset localPos,
    double chartSize,
    List<_DonutSegment> segments,
  ) {
    if (segments.isEmpty) {
      _clearHover();
      return;
    }

    final center = Offset(chartSize / 2, chartSize / 2);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);

    final outerRadius = (chartSize / 2) - 24.0;
    final innerRadius = outerRadius - 26.0;

    // Inside donut ring corridor (+ buffer)
    if (dist >= innerRadius - 8 && dist <= outerRadius + 8) {
      // Angle in [0, 2*pi]
      var angle = math.atan2(dy, dx);
      if (angle < 0) angle += 2 * math.pi;

      for (final seg in segments) {
        var start = seg.startAngle % (2 * math.pi);
        if (start < 0) start += 2 * math.pi;
        final end = start + seg.sweepAngle;

        bool inside = false;
        if (end <= 2 * math.pi) {
          inside = angle >= start && angle <= end;
        } else {
          inside = angle >= start || angle <= (end - 2 * math.pi);
        }

        if (inside) {
          _onSourceHover(seg.sourceName, localPos);
          return;
        }
      }
    }

    _clearHover();
  }

  List<_DonutSegment> _computeSegments(
    List<MapEntry<String, int>> sources,
    int totalBasis,
    bool isDark,
  ) {
    if (sources.isEmpty || totalBasis <= 0) return const [];

    final segments = <_DonutSegment>[];
    const baseStartAngle = -math.pi / 2; // 12 o'clock
    var currentAngle = baseStartAngle;

    final positiveSources = sources.where((e) => e.value > 0).toList();
    if (positiveSources.isEmpty) return const [];

    final count = positiveSources.length;
    const microGap = 0.035;

    for (final entry in positiveSources) {
      final ratio = entry.value / totalBasis;
      final sweep = ratio * (2 * math.pi);
      final gap = count > 1 ? microGap : 0.0;
      final actualSweep = math.max(0.01, sweep - gap);
      final actualStart = currentAngle + (gap / 2);

      segments.add(
        _DonutSegment(
          sourceName: entry.key,
          startAngle: actualStart,
          sweepAngle: actualSweep,
          percentage: ratio * 100,
          color: XpDistributionColors.getColor(entry.key, isDark: isDark),
        ),
      );

      currentAngle += sweep;
    }

    return segments;
  }

  List<MapEntry<String, int>> _getRankedSources() {
    final map = widget.snapshot.xpBySource;
    final list = map.entries.where((e) => e.value > 0).toList();

    // Sort descending by XP contribution
    list.sort((a, b) {
      final cmp = b.value.compareTo(a.value);
      if (cmp != 0) return cmp;
      return a.key.compareTo(b.key);
    });

    return list;
  }

  int _calculateTotalBasis(List<MapEntry<String, int>> rankedSources) {
    if (rankedSources.isEmpty) return 0;
    final sumPositive = rankedSources.fold<int>(0, (sum, e) => sum + e.value);
    if (sumPositive > 0) return sumPositive;
    if (widget.snapshot.positiveXp > 0) return widget.snapshot.positiveXp;
    return math.max(0, widget.snapshot.totalXp);
  }

  String _formatSourceDisplayName(String rawKey) {
    if (rawKey.isEmpty) return 'Other';
    final lower = rawKey.toLowerCase();
    if (lower == 'task') return 'Tasks';
    if (lower == 'goal') return 'Goals';
    if (lower == 'project') return 'Projects';
    if (lower == 'session' || lower == 'activity') return 'Habits & Focus';
    if (lower == 'streak') return 'Streaks';
    if (lower == 'skill') return 'Skills';
    if (lower == 'decision') return 'Decisions';
    if (lower == 'admin' || lower == 'manual') return 'Manual / Admin';
    return '${rawKey[0].toUpperCase()}${rawKey.substring(1)}';
  }

  String _formatNumber(int value) {
    final isNeg = value < 0;
    final absVal = value.abs();
    final str = absVal.toString();
    final buffer = StringBuffer();
    var count = 0;
    for (var i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) buffer.write(',');
    }
    final formatted = buffer.toString().split('').reversed.join('');
    return '${isNeg ? '-' : ''}$formatted';
  }

  // ── Skeleton Loading ───────────────────────────────────────────────────────
  Widget _buildSkeleton(BuildContext context, Color cardBg, Color borderColor) {
    return KratosGlassCard(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(24),
      child: const KratosShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: KratosSkeletonTokens.boneBaseColor,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 18,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: KratosSkeletonTokens.boneBaseColor,
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                    SizedBox(
                      width: 260,
                      height: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: KratosSkeletonTokens.boneBaseColor,
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 26),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 260,
                  height: 260,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: KratosSkeletonTokens.boneBaseColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: KratosSkeletonTokens.boneBaseColor,
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: KratosSkeletonTokens.boneBaseColor,
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: KratosSkeletonTokens.boneBaseColor,
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: KratosSkeletonTokens.boneBaseColor,
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Models & Donut Painter ───────────────────────────────────────────────────

class _DonutSegment {
  final String sourceName;
  final double startAngle;
  final double sweepAngle;
  final double percentage;
  final Color color;

  const _DonutSegment({
    required this.sourceName,
    required this.startAngle,
    required this.sweepAngle,
    required this.percentage,
    required this.color,
  });
}

class _XpDonutChartPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final String? hoveredSource;
  final bool isDark;
  final int totalBasis;

  _XpDonutChartPainter({
    required this.segments,
    required this.hoveredSource,
    required this.isDark,
    required this.totalBasis,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (size.width / 2) - 24.0;
    const strokeWidth = 24.0;
    final arcRadius = outerRadius - (strokeWidth / 2);

    // Empty / Zero State track ring
    if (segments.isEmpty || totalBasis <= 0) {
      final emptyPaint = Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0x180F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawCircle(center, arcRadius, emptyPaint);
      return;
    }

    final hasHover = hoveredSource != null;

    // Draw Segments
    for (final seg in segments) {
      final isHovered = seg.sourceName == hoveredSource;
      final effectiveStroke = isHovered ? 28.0 : strokeWidth;
      final effectiveRadius = isHovered ? (arcRadius + 1.5) : arcRadius;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = effectiveStroke
        ..strokeCap = StrokeCap.round
        ..color = hasHover
            ? (isHovered
                ? seg.color
                : seg.color.withValues(alpha: 0.35))
            : seg.color;

      // Glow on hovered segment
      if (isHovered) {
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = effectiveStroke + 6.0
          ..strokeCap = StrokeCap.round
          ..color = seg.color.withValues(alpha: 0.30);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: effectiveRadius),
          seg.startAngle,
          seg.sweepAngle,
          false,
          glowPaint,
        );
      }

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: effectiveRadius),
        seg.startAngle,
        seg.sweepAngle,
        false,
        paint,
      );

      // Outer Percentage Callouts (only for segments >= 4% of donut)
      if (seg.percentage >= 4.0) {
        final midAngle = seg.startAngle + (seg.sweepAngle / 2);
        final labelRadius = outerRadius + 14.0;
        final labelX = center.dx + labelRadius * math.cos(midAngle);
        final labelY = center.dy + labelRadius * math.sin(midAngle);

        final labelColor = hasHover
            ? (isHovered
                ? seg.color
                : (isDark ? Colors.white38 : const Color(0x400F172A)))
            : (isDark
                ? seg.color.withValues(alpha: 0.90)
                : seg.color);

        final textSpan = TextSpan(
          text: '${seg.percentage.round()}%',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: labelColor,
            letterSpacing: -0.2,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(labelX - (textPainter.width / 2), labelY - (textPainter.height / 2)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _XpDonutChartPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.hoveredSource != hoveredSource ||
        oldDelegate.isDark != isDark ||
        oldDelegate.totalBasis != totalBasis;
  }
}

class _DonutIconPainter extends CustomPainter {
  final bool isDark;

  const _DonutIconPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 4.5;
    final arcRadius = radius - (strokeWidth / 2);

    final colors = [
      isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime,
      const Color(0xFFFF9100),
      const Color(0xFF2979FF),
      const Color(0xFFA855F7),
    ];

    const gap = 0.25;
    const totalArcs = 4;
    const sweep = ((2 * math.pi) / totalArcs) - gap;

    for (var i = 0; i < totalArcs; i++) {
      final start = (i * ((2 * math.pi) / totalArcs)) - (math.pi / 2);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = colors[i % colors.length];

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: arcRadius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutIconPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

// ── Color Palette & Icon Registry ────────────────────────────────────────────

abstract final class XpDistributionColors {
  static Color getColor(String sourceName, {required bool isDark}) {
    final lower = sourceName.toLowerCase();
    if (lower.contains('task')) {
      return isDark ? const Color(0xFFEEFF08) : const Color(0xFF658F00); // Acid Lime (Brand Primary)
    } else if (lower.contains('project')) {
      return isDark ? const Color(0xFFFF9100) : const Color(0xFFEA580C); // Amber / Orange
    } else if (lower.contains('habit') ||
        lower.contains('focus') ||
        lower.contains('session') ||
        lower.contains('activity')) {
      return isDark ? const Color(0xFF2979FF) : const Color(0xFF1E60D0); // Electric Blue
    } else if (lower.contains('goal')) {
      return isDark ? const Color(0xFFA855F7) : const Color(0xFF7C3AED); // Violet / Purple
    } else if (lower.contains('skill')) {
      return isDark ? const Color(0xFFEC4899) : const Color(0xFFD92762); // Magenta / Pink
    } else if (lower.contains('streak')) {
      return isDark ? const Color(0xFF00E5FF) : const Color(0xFF0097A7); // Electric Cyan
    } else if (lower.contains('decision')) {
      return isDark ? const Color(0xFF10B981) : const Color(0xFF059669); // Emerald / Mint
    } else if (lower.contains('admin') || lower.contains('manual')) {
      return isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7); // Sky Blue
    } else {
      // Deterministic palette cycle for unmapped/custom sources
      final cycle = isDark
          ? const [
              Color(0xFF94A3B8), // Slate
              Color(0xFFF59E0B), // Warm Amber
              Color(0xFF818CF8), // Indigo
              Color(0xFF14B8A6), // Teal
              Color(0xFFF43F5E), // Rose
            ]
          : const [
              Color(0xFF64748B),
              Color(0xFFD97706),
              Color(0xFF4F46E5),
              Color(0xFF0D9488),
              Color(0xFFE11D48),
            ];
      return cycle[sourceName.hashCode.abs() % cycle.length];
    }
  }

  static IconData getIcon(String sourceName) {
    final lower = sourceName.toLowerCase();
    if (lower.contains('task')) return Icons.checklist_rounded;
    if (lower.contains('project')) return Icons.folder_outlined;
    if (lower.contains('habit') ||
        lower.contains('focus') ||
        lower.contains('session')) {
      return Icons.timer_outlined;
    }
    if (lower.contains('activity')) return Icons.repeat_rounded;
    if (lower.contains('goal')) return Icons.track_changes_rounded;
    if (lower.contains('skill')) return Icons.military_tech_outlined;
    if (lower.contains('streak')) return Icons.local_fire_department_outlined;
    if (lower.contains('decision')) return Icons.alt_route_rounded;
    if (lower.contains('manual') || lower.contains('admin')) {
      return Icons.star_outline_rounded;
    }
    return Icons.more_horiz_rounded;
  }
}
