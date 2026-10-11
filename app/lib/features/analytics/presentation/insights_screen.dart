import 'package:flutter/material.dart';

import '../../../app/kratos_theme.dart';
import '../../../data/drift/app_database.dart';
import '../data/analytics_mock_data.dart';
import '../data/drift_analytics_repository.dart';
import '../domain/analytics_models.dart';
import 'widgets/focus_time/focus_time_activity_pattern_card.dart';
import 'widgets/focus_time/focus_time_by_day_card.dart';
import 'widgets/focus_time/focus_time_by_hour_card.dart';
import 'widgets/focus_time/focus_time_hero_card.dart';
import 'widgets/focus_time/focus_time_insights_card.dart';

/// Dedicated Full Insights Screen for KRATOS Analytics matching master visual reference:
///
/// 1. Focus Time summary (Hero Card with 78% Goal Progress circular gauge)
/// 2. Activity Pattern Card (segmented Daily/Weekly/Monthly interactive bar chart)
/// 3. Focus by Day (7 vertical bars with duration labels directly above)
/// 4. Focus by Hour (7x24 heatmap grid in KRATOS lime intensity scale)
/// 5. Insights Card (Derived focus insights + interactive View All modal)
class InsightsScreen extends StatefulWidget {
  final AnalyticsSnapshot? snapshot;
  final String? ownerId;
  final AppDatabase? database;
  final AnalyticsPeriod? selectedPeriod;
  final String? periodSubtitle;

  const InsightsScreen({
    super.key,
    this.snapshot,
    this.ownerId,
    this.database,
    this.selectedPeriod,
    this.periodSubtitle,
  });

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  AnalyticsSnapshot? _snapshot;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.snapshot != null) {
      _snapshot = widget.snapshot;
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final period = widget.selectedPeriod ?? AnalyticsPeriod.thirtyDays;
    final range = AnalyticsDateRange.forPeriod(period);

    if (widget.database != null && widget.ownerId != null) {
      try {
        final repo = DriftAnalyticsRepository(widget.database!);
        final snap = await repo.load(
          ownerId: widget.ownerId!,
          range: range,
        );
        if (mounted) {
          setState(() {
            _snapshot = snap;
            _isLoading = false;
          });
        }
        return;
      } catch (_) {
        // Fallback to mock snapshot on error
      }
    }

    if (mounted) {
      setState(() {
        _snapshot = AnalyticsMockData.snapshot(range: range);
        _isLoading = false;
      });
    }
  }

  String _periodLabel(AnalyticsPeriod? period) {
    switch (period) {
      case AnalyticsPeriod.sevenDays:
      case AnalyticsPeriod.week:
        return 'This Week';
      case AnalyticsPeriod.thirtyDays:
      case AnalyticsPeriod.month:
        return 'This Month';
      case AnalyticsPeriod.ninetyDays:
        return 'Last 90 Days';
      case AnalyticsPeriod.year:
      case AnalyticsPeriod.oneYear:
        return 'This Year';
      case AnalyticsPeriod.today:
        return 'Today';
      case AnalyticsPeriod.custom:
      case null:
        return 'This Week';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF0D0F12) : const Color(0xFFF6F7F9);
    final cardBg = isDark ? const Color(0xFF131518) : Colors.white;
    final borderColor = isDark ? const Color(0xFF22262B) : const Color(0xFFE2E8F0);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final limeAccent = isDark ? KratosTheme.acidLime : const Color(0xFF84CC16);

    final snapshot = _snapshot;
    final focusTime = snapshot?.safeFocusTime ??
        FocusTimeSnapshot.empty(
          AnalyticsDateRange.forPeriod(
            widget.selectedPeriod ?? AnalyticsPeriod.thirtyDays,
          ),
        );
    final comparisonLabel = widget.periodSubtitle ??
        snapshot?.range.period?.comparisonLabel ??
        'vs last week';
    final periodLabel = _periodLabel(widget.selectedPeriod ?? snapshot?.range.period);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Navigation Bar / Header ──────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
              ),
              child: LayoutBuilder(
                builder: (context, headerConstraints) {
                  final isCompact = headerConstraints.maxWidth < 600;
                  return Row(
                    children: [
                      // Back button with hand cursor and hover feedback
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: InkWell(
                          key: const ValueKey('insights_back_button'),
                          onTap: () => Navigator.of(context).maybePop(),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0x1AFFFFFF)
                                  : const Color(0x0F0F172A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor, width: 1.0),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 16,
                                color: primaryTextColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Lightbulb Badge (shown if not ultra-compact)
                      if (!isCompact) ...[
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
                      ],

                      // Title + Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
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
                              'Activity patterns and derived focus metrics.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: secondaryTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Period / Comparison Chip
                      Flexible(
                        flex: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0x1FFFFFFF)
                                : const Color(0x0A0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor, width: 1.0),
                          ),
                          child: Text(
                            comparisonLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: secondaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ── Main Content Area: 5 Canonical Reference Sections ────────────
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(limeAccent),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final isCompact = width < 850;
                        final horizontalPadding = width < 600 ? 16.0 : 24.0;
                        final sectionSpacing = width < 600 ? 16.0 : 20.0;

                        return SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 24,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1100),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // ── 1. Focus Time Hero Card ──
                                  FocusTimeHeroCard(
                                    snapshot: focusTime,
                                    periodLabel: periodLabel,
                                    periodSubtitle: comparisonLabel,
                                  ),

                                  SizedBox(height: sectionSpacing),

                                  // ── 2. Activity Pattern Card ──
                                  FocusTimeActivityPatternCard(
                                    snapshot: focusTime,
                                  ),

                                  SizedBox(height: sectionSpacing),

                                  // ── 3. Focus by Day & Focus by Hour ──
                                  if (isCompact) ...[
                                    FocusTimeByDayCard(snapshot: focusTime),
                                    SizedBox(height: sectionSpacing),
                                    FocusTimeByHourCard(snapshot: focusTime),
                                  ] else ...[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: FocusTimeByDayCard(snapshot: focusTime),
                                        ),
                                        const SizedBox(width: 18),
                                        Expanded(
                                          flex: 1,
                                          child: FocusTimeByHourCard(snapshot: focusTime),
                                        ),
                                      ],
                                    ),
                                  ],

                                  SizedBox(height: sectionSpacing),

                                  // ── 4. Insights Card ──
                                  FocusTimeInsightsCard(
                                    snapshot: focusTime,
                                    periodSubtitle: comparisonLabel,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
