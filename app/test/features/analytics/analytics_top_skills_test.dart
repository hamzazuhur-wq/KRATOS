import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kratos_app/app/kratos_theme.dart';
import 'package:kratos_app/features/analytics/domain/analytics_models.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/analytics_top_skills_card.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/top_skills/skill_trend_chart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleSkills = [
    AnalyticsSkillMetric(
      id: 'skill-1',
      name: 'Systems Architecture',
      groupName: 'Software Engineering',
      lifeAreaId: 'la_prof',
      lifeAreaName: 'Professional',
      rank: SkillRank.s,
      periodXp: 3840,
      previousPeriodXp: 3100,
      xpDelta: const MetricDelta(current: 3840, previous: 3100, changePct: 23.9, isPositive: true),
      allTimeXp: 18450,
      contributionPct: 35.0,
      activityCount: 42,
      completedTasksCount: 28,
      sessionsCount: 14,
      focusMinutes: 620,
      xpOverTime: [
        AnalyticsPoint(date: DateTime(2026, 9, 1), xp: 120),
        AnalyticsPoint(date: DateTime(2026, 9, 2), xp: 240),
        AnalyticsPoint(date: DateTime(2026, 9, 3), xp: 350),
      ],
      previousXpOverTime: [
        AnalyticsPoint(date: DateTime(2026, 8, 1), xp: 100),
        AnalyticsPoint(date: DateTime(2026, 8, 2), xp: 150),
        AnalyticsPoint(date: DateTime(2026, 8, 3), xp: 200),
      ],
    ),
    AnalyticsSkillMetric(
      id: 'skill-2',
      name: 'Deep Work & Focus',
      groupName: 'Cognitive Mastery',
      lifeAreaId: 'la_mind',
      lifeAreaName: 'Mindset',
      rank: SkillRank.a,
      periodXp: 2620,
      previousPeriodXp: 2200,
      xpDelta: const MetricDelta(current: 2620, previous: 2200, changePct: 19.1, isPositive: true),
      allTimeXp: 12800,
      contributionPct: 24.0,
      activityCount: 41,
      completedTasksCount: 19,
      sessionsCount: 22,
      focusMinutes: 840,
      xpOverTime: [
        AnalyticsPoint(date: DateTime(2026, 9, 1), xp: 90),
        AnalyticsPoint(date: DateTime(2026, 9, 2), xp: 180),
      ],
    ),
    AnalyticsSkillMetric(
      id: 'skill-3',
      name: 'Data Analysis',
      groupName: 'Analytics & Strategy',
      lifeAreaId: 'la_prof',
      lifeAreaName: 'Professional',
      rank: SkillRank.a,
      periodXp: 2150,
      previousPeriodXp: 1920,
      xpDelta: const MetricDelta(current: 2150, previous: 1920, changePct: 12.0, isPositive: true),
      allTimeXp: 9600,
      contributionPct: 19.5,
      activityCount: 27,
      completedTasksCount: 16,
      sessionsCount: 11,
      focusMinutes: 480,
    ),
    AnalyticsSkillMetric(
      id: 'skill-4',
      name: 'Technical Writing',
      groupName: 'Communication',
      lifeAreaId: 'la_learn',
      lifeAreaName: 'Learning',
      rank: SkillRank.b,
      periodXp: 1640,
      previousPeriodXp: 1720,
      xpDelta: const MetricDelta(current: 1640, previous: 1720, changePct: -4.7, isPositive: false),
      allTimeXp: 7200,
      contributionPct: 15.0,
      activityCount: 20,
      completedTasksCount: 12,
      sessionsCount: 8,
      focusMinutes: 360,
    ),
    AnalyticsSkillMetric(
      id: 'skill-5',
      name: 'Problem Decomposition',
      groupName: 'Strategic Thinking',
      lifeAreaId: 'la_mind',
      lifeAreaName: 'Mindset',
      rank: SkillRank.b,
      periodXp: 1280,
      previousPeriodXp: 1180,
      xpDelta: const MetricDelta(current: 1280, previous: 1180, changePct: 8.5, isPositive: true),
      allTimeXp: 5400,
      contributionPct: 11.6,
      activityCount: 16,
      completedTasksCount: 10,
      sessionsCount: 6,
      focusMinutes: 270,
    ),
    AnalyticsSkillMetric(
      id: 'skill-6',
      name: 'Agile Execution',
      groupName: 'Project Delivery',
      lifeAreaId: 'la_prof',
      lifeAreaName: 'Professional',
      rank: SkillRank.c,
      periodXp: 960,
      previousPeriodXp: 840,
      xpDelta: const MetricDelta(current: 960, previous: 840, changePct: 14.3, isPositive: true),
      allTimeXp: 3900,
      contributionPct: 8.7,
      activityCount: 13,
      completedTasksCount: 8,
      sessionsCount: 5,
      focusMinutes: 210,
    ),
    AnalyticsSkillMetric(
      id: 'skill-7',
      name: 'Public Speaking',
      groupName: 'Communication',
      lifeAreaId: 'la_prof',
      lifeAreaName: 'Professional',
      rank: SkillRank.d,
      periodXp: 520,
      previousPeriodXp: 520,
      xpDelta: const MetricDelta(current: 520, previous: 520, changePct: 0.0, isPositive: false),
      allTimeXp: 1800,
      contributionPct: 4.7,
      activityCount: 8,
      completedTasksCount: 5,
      sessionsCount: 3,
      focusMinutes: 140,
    ),
  ];

  AnalyticsSnapshot buildSnapshot(List<AnalyticsSkillMetric> skills) {
    return AnalyticsSnapshot(
      range: AnalyticsDateRange.forPeriod(AnalyticsPeriod.thirtyDays),
      lifeAreaId: null,
      totalXp: 15000,
      previousTotalXp: 13000,
      xpDelta: const MetricDelta(current: 15000, previous: 13000, changePct: 15.4, isPositive: true),
      positiveXp: 15000,
      negativeXp: 0,
      xpVelocityDelta: const MetricDelta(current: 500, previous: 433, changePct: 15.5, isPositive: true),
      completionRateDelta: const MetricDelta(current: 80, previous: 75, changePct: 6.7, isPositive: true),
      consistencyDelta: const MetricDelta(current: 85, previous: 80, changePct: 6.25, isPositive: true),
      activeGoals: 3,
      completedGoals: 2,
      activeProjects: 2,
      completedProjects: 1,
      activeTasks: 10,
      completedTasks: 20,
      activitiesStarted: 15,
      sessionsCompleted: 10,
      actualMinutes: 400,
      currentStreak: 5,
      longestStreak: 12,
      xpOverTime: const [],
      xpBySource: const {},
      lifeAreas: const [],
      topSkills: skills,
    );
  }

  Widget createTestWidget({
    AnalyticsSnapshot? snapshot,
    bool isLoading = false,
    String? selectedId,
    ValueChanged<String>? onSkillSelected,
    ValueChanged<String?>? onLifeAreaChanged,
    List<({String id, String name})>? lifeAreas,
    String? selectedLifeAreaId,
    VoidCallback? onRetry,
  }) {
    return MaterialApp(
      theme: KratosTheme.darkTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AnalyticsTopSkillsCard(
              snapshot: snapshot,
              isLoading: isLoading,
              initialSelectedSkillId: selectedId,
              onSkillSelected: onSkillSelected,
              onLifeAreaChanged: onLifeAreaChanged,
              lifeAreas: lifeAreas,
              selectedLifeAreaId: selectedLifeAreaId,
              onRetry: onRetry,
            ),
          ),
        ),
      ),
    );
  }

  group('SkillRank Domain Tests', () {
    test('Mastery level mapping conforms strictly to D/C/B/A/S', () {
      expect(SkillRank.fromMasteryLevel(1), SkillRank.d);
      expect(SkillRank.fromMasteryLevel(2), SkillRank.c);
      expect(SkillRank.fromMasteryLevel(3), SkillRank.b);
      expect(SkillRank.fromMasteryLevel(4), SkillRank.a);
      expect(SkillRank.fromMasteryLevel(5), SkillRank.s);
      // Clamping bounds
      expect(SkillRank.fromMasteryLevel(0), SkillRank.d);
      expect(SkillRank.fromMasteryLevel(6), SkillRank.s);
    });

    test('Rank enum names are lowercase D/C/B/A/S', () {
      expect(SkillRank.d.name, 'd');
      expect(SkillRank.c.name, 'c');
      expect(SkillRank.b.name, 'b');
      expect(SkillRank.a.name, 'a');
      expect(SkillRank.s.name, 's');
    });
  });

  group('AnalyticsTopSkillsCard Widget Tests', () {
    testWidgets('Renders header title, subtitle, and tracked count', (tester) async {
      await tester.pumpWidget(createTestWidget(snapshot: buildSnapshot(sampleSkills)));
      await tester.pumpAndSettle();

      expect(find.text('Top Skills'), findsOneWidget);
      expect(
        find.text('Your most developed skills based on real activity and XP allocation.'),
        findsOneWidget,
      );
      expect(find.text('${sampleSkills.length} tracked'), findsOneWidget);
    });

    testWidgets('Renders top 6 skills by default and view-all button for 7th skill', (tester) async {
      await tester.pumpWidget(createTestWidget(snapshot: buildSnapshot(sampleSkills)));
      await tester.pumpAndSettle();

      expect(find.text('Systems Architecture'), findsWidgets);
      expect(find.text('Deep Work & Focus'), findsWidgets);
      expect(find.text('Data Analysis'), findsWidgets);
      expect(find.text('Technical Writing'), findsWidgets);
      expect(find.text('Problem Decomposition'), findsWidgets);
      expect(find.text('Agile Execution'), findsWidgets);
      // 7th skill is collapsed initially
      expect(find.text('View all 7 skills'), findsOneWidget);

      // Tap view all
      await tester.tap(find.text('View all 7 skills'));
      await tester.pumpAndSettle();

      expect(find.text('Public Speaking'), findsWidgets);
      expect(find.text('Show Top 6'), findsOneWidget);
    });

    testWidgets('Renders selected skill detail panel with correct metrics', (tester) async {
      await tester.pumpWidget(createTestWidget(snapshot: buildSnapshot(sampleSkills)));
      await tester.pumpAndSettle();

      // Top skill is Systems Architecture
      expect(find.text('PERIOD GAIN'), findsOneWidget);
      expect(find.text('3,840 XP'), findsWidgets);
      expect(find.text('18,450 XP'), findsOneWidget);
      expect(find.text('35.0%'), findsOneWidget);
      expect(find.text('28'), findsOneWidget); // tasks
      expect(find.text('10.3h'), findsOneWidget); // 620 mins / 60
      expect(find.byType(SkillTrendChart), findsOneWidget);
    });

    testWidgets('Interactively selects another skill row and updates detail panel', (tester) async {
      String? selectedSkillId;
      await tester.pumpWidget(
        createTestWidget(
          snapshot: buildSnapshot(sampleSkills),
          onSkillSelected: (id) => selectedSkillId = id,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Deep Work & Focus
      await tester.tap(find.text('Deep Work & Focus').first);
      await tester.pumpAndSettle();

      expect(selectedSkillId, 'skill-2');
      expect(find.text('2,620 XP'), findsWidgets);
      expect(find.text('12,800 XP'), findsOneWidget);
      expect(find.text('24.0%'), findsOneWidget);
    });

    testWidgets('Renders empty state when no skills exist', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        createTestWidget(
          snapshot: buildSnapshot([]),
          onRetry: () => retried = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No skill activity recorded yet'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);

      await tester.tap(find.text('Refresh'));
      expect(retried, isTrue);
    });

    testWidgets('Renders loading skeleton state when isLoading is true', (tester) async {
      await tester.pumpWidget(createTestWidget(isLoading: true));
      await tester.pump();

      expect(find.text('Top Skills'), findsNothing);
    });

    testWidgets('Formats large XP numbers cleanly with M and k notation', (tester) async {
      final largeSkill = AnalyticsSkillMetric(
        id: 'big-1',
        name: 'Scale Mastery',
        rank: SkillRank.s,
        periodXp: 1250000,
        allTimeXp: 3500000,
      );

      await tester.pumpWidget(createTestWidget(snapshot: buildSnapshot([largeSkill])));
      await tester.pumpAndSettle();

      expect(find.text('1.3M XP'), findsWidgets);
    });
  });
}
