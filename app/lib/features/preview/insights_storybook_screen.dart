import 'package:flutter/material.dart';

import '../../app/kratos_theme.dart';
import '../../app/kratos_theme_controller.dart';
import '../analytics/data/analytics_mock_data.dart';
import '../analytics/domain/analytics_models.dart';
import '../analytics/presentation/widgets/focus_time/focus_time_activity_pattern_card.dart';
import '../analytics/presentation/widgets/focus_time/focus_time_by_day_card.dart';
import '../analytics/presentation/widgets/focus_time/focus_time_by_hour_card.dart';
import '../analytics/presentation/widgets/focus_time/focus_time_hero_card.dart';
import '../analytics/presentation/widgets/focus_time/focus_time_insights_card.dart';

/// Interactive Storybook preview for KRATOS Insights matching master visual reference:
///
/// 1. Focus Time summary (Hero Card with 78% Goal Progress circular gauge)
/// 2. Activity Pattern Card (segmented Daily/Weekly/Monthly interactive bar chart)
/// 3. Focus by Day (7 vertical bars with duration labels directly above)
/// 4. Focus by Hour (7x24 heatmap grid in KRATOS lime intensity scale)
/// 5. Insights Card (Derived focus insights + interactive View All modal)
///
/// Supports:
/// - Light & Dark theme toggle
/// - Populated vs Empty state toggle
/// - Responsive breakpoint preview across Desktop, Tablet, and Mobile
class InsightsStorybookScreen extends StatefulWidget {
  const InsightsStorybookScreen({super.key});

  @override
  State<InsightsStorybookScreen> createState() => _InsightsStorybookScreenState();
}

class _InsightsStorybookScreenState extends State<InsightsStorybookScreen> {
  late bool _isDark;
  bool _isEmpty = false;
  final AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.sevenDays;

  @override
  void initState() {
    super.initState();
    final themeParam = Uri.base.queryParameters['theme'];
    if (themeParam == 'light') {
      _isDark = false;
      KratosThemeController.instance.setThemeMode(ThemeMode.light);
    } else if (themeParam == 'dark') {
      _isDark = true;
      KratosThemeController.instance.setThemeMode(ThemeMode.dark);
    } else {
      _isDark = KratosThemeController.instance.isDark;
    }

    final emptyParam = Uri.base.queryParameters['empty'];
    if (emptyParam == 'true') {
      _isEmpty = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeData = _isDark ? KratosTheme.darkTheme : KratosTheme.lightTheme;
    final range = AnalyticsDateRange.forPeriod(_selectedPeriod);

    final FocusTimeSnapshot focusTime;
    if (_isEmpty) {
      focusTime = FocusTimeSnapshot.empty(range);
    } else {
      final snap = AnalyticsMockData.snapshot(range: range);
      focusTime = snap.safeFocusTime;
    }

    final bg = _isDark ? const Color(0xFF0D0F12) : const Color(0xFFF6F7F9);
    final barBg = _isDark ? const Color(0xFF131518) : Colors.white;
    final borderColor = _isDark ? const Color(0xFF22262B) : const Color(0xFFE2E8F0);
    final primaryTextColor = _isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = _isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final limeAccent = _isDark ? KratosTheme.acidLime : const Color(0xFF84CC16);

    return Theme(
      data: themeData,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: barBg,
          elevation: 0,
          leading: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _isDark ? const Color(0x2EEFFF08) : const Color(0x2284CC16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  Icons.auto_graph_rounded,
                  color: limeAccent,
                  size: 18,
                ),
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KRATOS Insights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              Text(
                _isEmpty ? 'Empty State' : 'Populated Data · This Week',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: borderColor, height: 1.0),
          ),
          actions: [
            // Populated / Empty Toggle
            IconButton(
              icon: Icon(
                _isEmpty ? Icons.data_usage_rounded : Icons.clear_all_rounded,
                color: _isDark ? Colors.white70 : KratosTheme.lightTextSecondary,
              ),
              tooltip: _isEmpty ? 'Switch to Populated Data' : 'Switch to Empty State',
              onPressed: () => setState(() => _isEmpty = !_isEmpty),
            ),
            // Light / Dark Theme Toggle
            IconButton(
              icon: Icon(
                _isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: limeAccent,
              ),
              tooltip: _isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
              onPressed: () {
                final next = !_isDark;
                setState(() => _isDark = next);
                KratosThemeController.instance.setThemeMode(
                  next ? ThemeMode.dark : ThemeMode.light,
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: LayoutBuilder(
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
                        periodLabel: 'This Week',
                        periodSubtitle: 'vs last week',
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
                        periodSubtitle: 'vs last week',
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
