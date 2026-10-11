import 'package:flutter/material.dart';

import '../../../domain/analytics_models.dart';
import 'focus_time_active_session_card.dart';
import 'focus_time_activity_pattern_card.dart';
import 'focus_time_by_day_card.dart';
import 'focus_time_by_hour_card.dart';
import 'focus_time_hero_card.dart';
import 'focus_time_insights_card.dart';

/// Complete Focus Time Analytics Section matching master visual reference:
///
/// 1. Optional Active Focus Session monitor/starter
/// 2. Hero Header Card (12h 45m, trend, 3 badges, 78% Goal Progress gauge)
/// 3. Activity Pattern Card (segmented Daily/Weekly/Monthly bar chart + tooltip)
/// 4. Side-by-side (or responsive stacked):
///    - Focus by Day (7-day bar chart with duration labels)
///    - Focus by Hour (7x24 heatmap with Mon-Sun rows & 6am/12pm/6pm/12am axis)
/// 5. Insights Card (Peak Focus Time, Most Focused Day, Focus Trend)
class AnalyticsFocusTimeSection extends StatelessWidget {
  final FocusTimeSnapshot snapshot;
  final bool isLoading;
  final String periodLabel;
  final String periodSubtitle;
  final VoidCallback? onDateRangeTap;
  final VoidCallback? onStartFocusTap;
  final VoidCallback? onViewAllInsightsTap;
  final AnalyticsSnapshot? fullSnapshot;

  const AnalyticsFocusTimeSection({
    super.key,
    required this.snapshot,
    this.isLoading = false,
    this.periodLabel = 'This Week',
    this.periodSubtitle = 'vs last week',
    this.onDateRangeTap,
    this.onStartFocusTap,
    this.onViewAllInsightsTap,
    this.fullSnapshot,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 850;
        final sectionSpacing = width < 600 ? 16.0 : 20.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 0. Active Session Banner / Quick Start Strip ──
            FocusTimeActiveSessionCard(
              onStartFocusTap: onStartFocusTap,
            ),

            SizedBox(height: sectionSpacing),

            // ── 1. Focus Time Hero Card ──
            FocusTimeHeroCard(
              snapshot: snapshot,
              periodLabel: periodLabel,
              periodSubtitle: periodSubtitle,
              onDateRangeTap: onDateRangeTap,
            ),

            SizedBox(height: sectionSpacing),

            // ── 2. Activity Pattern Card ──
            FocusTimeActivityPatternCard(
              snapshot: snapshot,
            ),

            SizedBox(height: sectionSpacing),

            // ── 3. Focus by Day & Focus by Hour (Side-by-side or stacked) ──
            if (isCompact) ...[
              FocusTimeByDayCard(snapshot: snapshot),
              SizedBox(height: sectionSpacing),
              FocusTimeByHourCard(snapshot: snapshot),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: FocusTimeByDayCard(snapshot: snapshot),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 1,
                    child: FocusTimeByHourCard(snapshot: snapshot),
                  ),
                ],
              ),
            ],

            SizedBox(height: sectionSpacing),

            // ── 4. Insights Card (Master Visual Reference Match) ──
            FocusTimeInsightsCard(
              snapshot: snapshot,
              periodSubtitle: periodSubtitle,
              onViewAllTap: onViewAllInsightsTap,
            ),
          ],
        );
      },
    );
  }
}
