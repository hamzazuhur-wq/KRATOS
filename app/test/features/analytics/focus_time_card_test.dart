import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/app/kratos_theme.dart';
import 'package:kratos_app/features/analytics/data/analytics_mock_data.dart';
import 'package:kratos_app/features/analytics/domain/analytics_models.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/focus_time/analytics_focus_time_section.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/focus_time/focus_time_activity_pattern_card.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/focus_time/focus_time_by_day_card.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/focus_time/focus_time_by_hour_card.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/focus_time/focus_time_hero_card.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/focus_time/focus_time_insights_card.dart';

void main() {
  group('Focus Time UI Widget Tests', () {
    late FocusTimeSnapshot sampleSnapshot;

    setUp(() {
      final range = AnalyticsDateRange.forPeriod(AnalyticsPeriod.sevenDays);
      final mockSnapshot = AnalyticsMockData.snapshot(range: range);
      sampleSnapshot = mockSnapshot.safeFocusTime;
    });

    Widget wrapWidget(Widget child, {bool isDark = true, double width = 1000}) {
      return MaterialApp(
        theme: isDark ? KratosTheme.darkTheme : KratosTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      );
    }

    testWidgets('FocusTimeHeroCard renders metrics, badges, and Goal Progress in Dark Mode',
        (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          FocusTimeHeroCard(
            snapshot: sampleSnapshot,
            periodLabel: 'This Week',
            periodSubtitle: 'vs last week',
          ),
          isDark: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Focus Time'), findsOneWidget);
      expect(find.text('Turn your attention into progress.'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('Sessions'), findsOneWidget);
      expect(find.text('Avg. Session'), findsOneWidget);
      expect(find.text('Longest'), findsOneWidget);
      expect(find.text('Goal Progress'), findsOneWidget);
    });

    testWidgets('FocusTimeHeroCard renders cleanly in Light Mode without overflow',
        (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          FocusTimeHeroCard(
            snapshot: sampleSnapshot,
            periodLabel: 'This Week',
            periodSubtitle: 'vs last week',
          ),
          isDark: false,
          width: 400, // Mobile width
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Focus Time'), findsOneWidget);
      expect(find.text('Goal Progress'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('FocusTimeActivityPatternCard renders segments and switches view',
        (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          FocusTimeActivityPatternCard(snapshot: sampleSnapshot),
          isDark: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Activity Pattern'), findsOneWidget);
      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);

      // Tap 'Weekly'
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('FocusTimeByDayCard renders 7 weekday labels and duration tags',
        (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          FocusTimeByDayCard(snapshot: sampleSnapshot),
          isDark: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Focus by Day'), findsOneWidget);
      expect(find.text('Total focus time'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
    });

    testWidgets('FocusTimeByHourCard renders 7x24 heatmap and axis markers',
        (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          FocusTimeByHourCard(snapshot: sampleSnapshot),
          isDark: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Focus by Hour'), findsOneWidget);
      expect(find.text('6am'), findsOneWidget);
      expect(find.text('12pm'), findsOneWidget);
      expect(find.text('6pm'), findsOneWidget);
      expect(find.text('12am'), findsOneWidget);
    });

    testWidgets('FocusTimeInsightsCard renders peak time, best day, and trend',
        (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          FocusTimeInsightsCard(
            snapshot: sampleSnapshot,
            periodSubtitle: 'vs last week',
          ),
          isDark: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Smart insights from your data.'), findsOneWidget);
      expect(find.text('Peak Focus Time'), findsOneWidget);
      expect(find.text('Most Focused Day'), findsOneWidget);
      expect(find.text('Focus Trend'), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);
    });

    testWidgets('AnalyticsFocusTimeSection mounts all subcomponents responsively',
        (tester) async {
      // Desktop breakpoint
      await tester.pumpWidget(
        wrapWidget(
          AnalyticsFocusTimeSection(
            snapshot: sampleSnapshot,
            periodLabel: 'This Week',
            periodSubtitle: 'vs last week',
          ),
          isDark: true,
          width: 1200,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Focus Time'), findsOneWidget);
      expect(find.text('Activity Pattern'), findsOneWidget);
      expect(find.text('Focus by Day'), findsOneWidget);
      expect(find.text('Focus by Hour'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);

      // Mobile breakpoint
      await tester.pumpWidget(
        wrapWidget(
          AnalyticsFocusTimeSection(
            snapshot: sampleSnapshot,
            periodLabel: 'This Week',
            periodSubtitle: 'vs last week',
          ),
          isDark: false,
          width: 390,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Focus Time'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
