import 'package:flutter/material.dart';

import '../../../../app/kratos_skeleton.dart';
import '../../../../app/kratos_theme.dart';
import '../../../../app/kratos_visuals.dart';
import '../../domain/analytics_models.dart';
import 'life_areas_overview/life_areas_progress_list.dart';
import 'life_areas_overview/life_areas_radar_chart.dart';
import 'life_areas_overview/life_areas_radar_models.dart';

/// KRATOS Analytics — Wave: Life Areas Overview (Radar / Spider Chart + Progress List).
///
/// Features:
/// - True dynamic native Flutter visualization driven by [AnalyticsSnapshot] and [AnalyticsLifeAreaMetric]
/// - Animated vertex interpolation when data changes (oldValues -> newValues lerp)
/// - Safe handling of Life Area count changes (fade/center morph)
/// - Deliberate large-count strategy: focuses top 7 active domains on radar while preserving full list
/// - Synchronized bidirectional interaction between Radar axes and Progress list items
/// - Centralized KRATOS Card System integration via [KratosGlassCard]
/// - Responsive composition for Desktop (>= 920px), Tablet (600-919px), and Mobile (< 600px)
/// - Acid Lime (#EEFF08) highlights on Deep Volcanic & Light Architectural Frost surfaces.
class AnalyticsLifeAreasOverviewCard extends StatefulWidget {
  final AnalyticsSnapshot? snapshot;
  final bool isLoading;
  final String periodSubtitle;
  final VoidCallback? onRetry;
  final String? initialFocusedLifeAreaId;

  const AnalyticsLifeAreasOverviewCard({
    super.key,
    required this.snapshot,
    this.isLoading = false,
    this.periodSubtitle = 'Last 30 Days',
    this.onRetry,
    this.initialFocusedLifeAreaId,
  });

  @override
  State<AnalyticsLifeAreasOverviewCard> createState() =>
      _AnalyticsLifeAreasOverviewCardState();
}

class _AnalyticsLifeAreasOverviewCardState
    extends State<AnalyticsLifeAreasOverviewCard> {
  static const int maxRecommendedRadarAxes = 7;

  late String? _focusedLifeAreaId;
  String? _hoveredLifeAreaId;
  bool _showAllOnRadar = false;

  @override
  void initState() {
    super.initState();
    _focusedLifeAreaId = widget.initialFocusedLifeAreaId;
  }

  @override
  void didUpdateWidget(AnalyticsLifeAreasOverviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFocusedLifeAreaId != oldWidget.initialFocusedLifeAreaId) {
      _focusedLifeAreaId = widget.initialFocusedLifeAreaId;
    }
  }

  void _onLifeAreaSelected(String? id) {
    setState(() {
      _focusedLifeAreaId = id;
    });
  }

  void _onLifeAreaHovered(String? id) {
    if (_hoveredLifeAreaId != id) {
      setState(() {
        _hoveredLifeAreaId = id;
      });
    }
  }

  List<RadarLifeAreaEntry> _buildEntries() {
    final rawAreas = widget.snapshot?.lifeAreas ?? const [];
    return rawAreas
        .map((metric) => RadarLifeAreaEntry.fromMetric(metric))
        .toList();
  }

  List<RadarLifeAreaEntry> _filterRadarEntries(
    List<RadarLifeAreaEntry> allEntries,
  ) {
    if (allEntries.length <= maxRecommendedRadarAxes || _showAllOnRadar) {
      return allEntries;
    }

    // Top N strategy: keep focused area if selected, plus top areas by progress/XP
    final sorted = List<RadarLifeAreaEntry>.from(allEntries)
      ..sort((a, b) => b.normalizedProgress.compareTo(a.normalizedProgress));

    final subset = <RadarLifeAreaEntry>[];
    if (_focusedLifeAreaId != null) {
      final focused = allEntries.firstWhere(
        (e) => e.id == _focusedLifeAreaId,
        orElse: () => sorted.first,
      );
      subset.add(focused);
    }

    for (final entry in sorted) {
      if (subset.length >= maxRecommendedRadarAxes) break;
      if (!subset.any((e) => e.id == entry.id)) {
        subset.add(entry);
      }
    }

    return subset;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lime = isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime;
    final primary = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final secondary = isDark
        ? const Color(0xFFA7A7A7)
        : KratosTheme.lightTextSecondary;

    if (widget.isLoading) {
      return _buildSkeleton(context, isDark);
    }

    final allEntries = _buildEntries();
    if (allEntries.isEmpty) {
      return _buildEmptyState(context, isDark, primary, secondary);
    }

    final radarEntries = _filterRadarEntries(allEntries);
    final isLargeCount = allEntries.length > maxRecommendedRadarAxes;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = constraints.maxWidth;
        final isDesktop = cardW >= 920;
        final isMobile = cardW < 640;

        return KratosGlassCard(
          borderRadius: BorderRadius.circular(20),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: isMobile ? 18 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Card Header with Title & Local Controls ──────────────
              _buildHeader(
                context,
                allEntries: allEntries,
                isDark: isDark,
                isMobile: isMobile,
                primary: primary,
                secondary: secondary,
                lime: lime,
              ),

              if (isLargeCount) ...[
                const SizedBox(height: 12),
                _buildLargeCountNotice(
                  allCount: allEntries.length,
                  displayCount: radarEntries.length,
                  isDark: isDark,
                  lime: lime,
                  secondary: secondary,
                ),
              ],

              SizedBox(height: isMobile ? 16 : 22),

              // ── 2. Responsive Content Layout ─────────────────────────────
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Interactive Radar Chart & Floating Detail
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          LifeAreasRadarChart(
                            entries: radarEntries,
                            selectedId: _focusedLifeAreaId,
                            hoveredId: _hoveredLifeAreaId,
                            onSelected: _onLifeAreaSelected,
                            onHovered: _onLifeAreaHovered,
                            minHeight: 360,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailSummary(
                            allEntries: allEntries,
                            isDark: isDark,
                            primary: primary,
                            secondary: secondary,
                            lime: lime,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    // Right Column: Supporting Life Area Progress List
                    Expanded(
                      flex: 5,
                      child: LifeAreasProgressList(
                        entries: allEntries,
                        selectedId: _focusedLifeAreaId,
                        hoveredId: _hoveredLifeAreaId,
                        onSelected: _onLifeAreaSelected,
                        onHovered: _onLifeAreaHovered,
                      ),
                    ),
                  ],
                )
              else
                // Tablet & Mobile Stacked
                Column(
                  children: [
                    LifeAreasRadarChart(
                      entries: radarEntries,
                      selectedId: _focusedLifeAreaId,
                      hoveredId: _hoveredLifeAreaId,
                      onSelected: _onLifeAreaSelected,
                      onHovered: _onLifeAreaHovered,
                      minHeight: isMobile ? 290 : 340,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailSummary(
                      allEntries: allEntries,
                      isDark: isDark,
                      primary: primary,
                      secondary: secondary,
                      lime: lime,
                    ),
                    SizedBox(height: isMobile ? 18 : 24),
                    LifeAreasProgressList(
                      entries: allEntries,
                      selectedId: _focusedLifeAreaId,
                      hoveredId: _hoveredLifeAreaId,
                      onSelected: _onLifeAreaSelected,
                      onHovered: _onLifeAreaHovered,
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required List<RadarLifeAreaEntry> allEntries,
    required bool isDark,
    required bool isMobile,
    required Color primary,
    required Color secondary,
    required Color lime,
  }) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: lime.withValues(alpha: isDark ? 0.15 : 0.20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.hub_outlined, size: 15, color: lime),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Life Areas Overview',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.w700,
                  color: primary,
                  letterSpacing: -0.4,
                  fontFamily: 'Geist',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Your balanced growth across all life areas',
          style: TextStyle(
            fontSize: isMobile ? 12 : 13,
            color: secondary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );

    // Pill dropdowns on right
    final controls = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Life Area Focus Dropdown
        _buildDropdownPill<String?>(
          icon: Icons.layers_outlined,
          label: _focusedAreaName(allEntries),
          selectedValue: _focusedLifeAreaId,
          items: [
            const _DropdownItem(value: null, label: 'All Areas'),
            for (final entry in allEntries)
              _DropdownItem(value: entry.id, label: entry.name),
          ],
          onSelected: (val) => _onLifeAreaSelected(val),
          isDark: isDark,
          lime: lime,
        ),

        // Date Range Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141715) : const Color(0xFFF1F3F5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0x180F172A),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: isDark ? Colors.white70 : KratosTheme.lightTextSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                widget.periodSubtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, headerConstraints) {
        if (isMobile || headerConstraints.maxWidth < 780) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleBlock, const SizedBox(height: 12), controls],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            controls,
          ],
        );
      },
    );
  }

  String _focusedAreaName(List<RadarLifeAreaEntry> allEntries) {
    if (_focusedLifeAreaId == null) return 'All Areas';
    for (final e in allEntries) {
      if (e.id == _focusedLifeAreaId) return e.name;
    }
    return 'All Areas';
  }

  Widget _buildDropdownPill<T>({
    required IconData icon,
    required String label,
    required T selectedValue,
    required List<_DropdownItem<T>> items,
    required ValueChanged<T> onSelected,
    required bool isDark,
    required Color lime,
  }) {
    return PopupMenuButton<T>(
      initialValue: selectedValue,
      onSelected: onSelected,
      color: isDark ? const Color(0xFF161917) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0x200F172A),
        ),
      ),
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem<T>(
            value: item.value,
            child: Text(
              item.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: item.value == selectedValue
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: item.value == selectedValue
                    ? lime
                    : (isDark ? Colors.white : KratosTheme.lightTextPrimary),
              ),
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141715) : const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0x180F172A),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isDark ? Colors.white70 : KratosTheme.lightTextSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isDark ? Colors.white54 : KratosTheme.lightTextSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeCountNotice({
    required int allCount,
    required int displayCount,
    required bool isDark,
    required Color lime,
    required Color secondary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF151916).withValues(alpha: 0.8)
            : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0x140F172A),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _showAllOnRadar
                        ? 'Displaying all $allCount life areas on radar'
                        : 'Displaying top $displayCount of $allCount life areas on radar',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => setState(() => _showAllOnRadar = !_showAllOnRadar),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                _showAllOnRadar
                    ? 'Show Top $maxRecommendedRadarAxes'
                    : 'Show All Axes',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: lime,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSummary({
    required List<RadarLifeAreaEntry> allEntries,
    required bool isDark,
    required Color primary,
    required Color secondary,
    required Color lime,
  }) {
    final activeId = _focusedLifeAreaId ?? _hoveredLifeAreaId;
    if (activeId == null) {
      // General overview summary
      final avgProgress = allEntries.isNotEmpty
          ? (allEntries
                        .map((e) => e.normalizedProgress)
                        .reduce((a, b) => a + b) /
                    allEntries.length *
                    100)
                .round()
          : 0;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF101311).withValues(alpha: 0.6)
              : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0x100F172A),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.auto_graph_rounded, size: 16, color: lime),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Average Balance',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$avgProgress% Overall',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: lime,
                fontFamily: 'GeistMono',
              ),
            ),
          ],
        ),
      );
    }

    final targetEntry = allEntries.firstWhere(
      (e) => e.id == activeId,
      orElse: () => allEntries.first,
    );

    final trendPositive = targetEntry.trendPct >= 0;
    final trendText =
        '${trendPositive ? '+' : ''}${targetEntry.trendPct.toStringAsFixed(1)}% trend';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181D18) : const Color(0xFFEFF5EC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: lime.withValues(alpha: isDark ? 0.35 : 0.50),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(targetEntry.icon, size: 16, color: lime),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    targetEntry.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: lime.withValues(alpha: isDark ? 0.15 : 0.20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Level ${targetEntry.level}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: lime,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Text(
                '${targetEntry.displayPct}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: lime,
                  fontFamily: 'GeistMono',
                ),
              ),
              const SizedBox(width: 8),
              Text(
                trendText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context, bool isDark) {
    return KratosGlassCard(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(24),
      child: KratosShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 180,
              height: 22,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF181D18)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 260,
              height: 14,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF141814)
                    : const Color(0xFFEDF2F7),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 280,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF141814)
                          : const Color(0xFFEDF2F7),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    children: List.generate(
                      4,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF181D18)
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    Color primary,
    Color secondary,
  ) {
    return KratosGlassCard(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hub_outlined,
              size: 44,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            const SizedBox(height: 14),
            Text(
              'No Life Areas Overview Data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start logging tasks, activities, and goals to track your growth balance.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownItem<T> {
  final T value;
  final String label;

  const _DropdownItem({required this.value, required this.label});
}
