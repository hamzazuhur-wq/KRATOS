import 'package:flutter/material.dart';

import '../../app/kratos_theme.dart';
import '../../app/kratos_theme_controller.dart';
import '../analytics/domain/analytics_models.dart';
import '../analytics/presentation/widgets/analytics_top_skills_card.dart';

/// Wave 08: Top Skills Storybook Screen.
///
/// Provides exhaustive interactive QA coverage across:
/// 1. Dark Mode & Light Mode (Liquid Glass vs Light Architectural Ceramic)
/// 2. Baseline Top 6 Skills (Systems Architecture, Deep Work, Data Analysis, Technical Writing, Problem Decomposition, Agile Execution)
/// 3. Selected Skill Detail Switching (interactive clicking + preset selection)
/// 4. Top-N Expandable Behavior (> 6 skills up to 12 skills)
/// 5. Few Skills (2-3 skills)
/// 6. Single Skill (1 skill edge case)
/// 7. Empty State (0 skills with guidance copy)
/// 8. Loading Skeleton Shimmer State
/// 9. Error State with Retry callback
/// 10. Long Skill Names & Category overflow resilience
/// 11. Large XP Numbers (> 1,000,000 XP formatting)
/// 12. Negative, Zero, and High Growth Deltas
/// 13. Multi-viewport adaptation: Desktop (1440x900), Tablet (1024x768), Mobile (430x932, 390x844)
class Wave08TopSkillsStorybookScreen extends StatefulWidget {
  const Wave08TopSkillsStorybookScreen({super.key});

  @override
  State<Wave08TopSkillsStorybookScreen> createState() =>
      _Wave08TopSkillsStorybookScreenState();
}

enum _TopSkillsPreset {
  standardBaseline,
  selectedDetail,
  largeCount,
  fewSkills,
  singleSkill,
  emptyState,
  loadingSkeleton,
  errorState,
  longNames,
  largeNumbers,
  growthVariations,
}

enum _ViewportPreset { desktop, tablet, mobile }

class _Wave08TopSkillsStorybookScreenState
    extends State<Wave08TopSkillsStorybookScreen> {
  _TopSkillsPreset _preset = _TopSkillsPreset.standardBaseline;
  _ViewportPreset _viewport = _ViewportPreset.desktop;
  String? _selectedSkillId;
  String? _selectedLifeAreaId;

  @override
  void initState() {
    super.initState();
    final p = Uri.base.queryParameters['preset'];
    if (p == 'selected') {
      _preset = _TopSkillsPreset.selectedDetail;
      _selectedSkillId = 'skill-2';
    } else if (p == 'large' || p == 'twelve') {
      _preset = _TopSkillsPreset.largeCount;
    } else if (p == 'few') {
      _preset = _TopSkillsPreset.fewSkills;
    } else if (p == 'single') {
      _preset = _TopSkillsPreset.singleSkill;
    } else if (p == 'empty') {
      _preset = _TopSkillsPreset.emptyState;
    } else if (p == 'skeleton' || p == 'loading') {
      _preset = _TopSkillsPreset.loadingSkeleton;
    } else if (p == 'error') {
      _preset = _TopSkillsPreset.errorState;
    } else if (p == 'long_names') {
      _preset = _TopSkillsPreset.longNames;
    } else if (p == 'large_numbers') {
      _preset = _TopSkillsPreset.largeNumbers;
    } else if (p == 'growth') {
      _preset = _TopSkillsPreset.growthVariations;
    }
  }

  static const _mockLifeAreas = <({String id, String name})>[
    (id: 'la_prof', name: 'Professional'),
    (id: 'la_mind', name: 'Mindset'),
    (id: 'la_learn', name: 'Learning'),
    (id: 'la_health', name: 'Health & Sport'),
  ];

  static List<AnalyticsPoint> _generateTrendSeries({
    required int baseXp,
    required int days,
    required double volatility,
  }) {
    final now = DateTime.now();
    final list = <AnalyticsPoint>[];
    for (var i = 0; i < days; i++) {
      final d = now.subtract(Duration(days: days - 1 - i));
      final factor = 0.6 + (i * 0.08) + ((i % 3) * volatility * 0.15);
      final xp = ((baseXp / days) * factor).round();
      list.add(AnalyticsPoint(date: d, xp: xp));
    }
    return list;
  }

  static final List<AnalyticsSkillMetric> _baselineSkills = [
    AnalyticsSkillMetric(
      id: 'skill-1',
      name: 'Systems Architecture',
      groupName: 'Software Engineering',
      lifeAreaId: 'la_prof',
      lifeAreaName: 'Professional',
      rank: SkillRank.s,
      periodXp: 3840,
      previousPeriodXp: 3100,
      xpDelta: MetricDelta.compute(current: 3840, previous: 3100),
      allTimeXp: 18450,
      contributionPct: 29.8,
      activityCount: 42,
      completedTasksCount: 28,
      sessionsCount: 14,
      focusMinutes: 620,
      xpOverTime: _generateTrendSeries(baseXp: 3840, days: 14, volatility: 0.8),
      previousXpOverTime: _generateTrendSeries(baseXp: 3100, days: 14, volatility: 0.5),
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
      xpDelta: MetricDelta.compute(current: 2620, previous: 2200),
      allTimeXp: 12800,
      contributionPct: 20.3,
      activityCount: 41,
      completedTasksCount: 19,
      sessionsCount: 22,
      focusMinutes: 840,
      xpOverTime: _generateTrendSeries(baseXp: 2620, days: 14, volatility: 0.9),
      previousXpOverTime: _generateTrendSeries(baseXp: 2200, days: 14, volatility: 0.6),
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
      xpDelta: MetricDelta.compute(current: 2150, previous: 1920),
      allTimeXp: 9600,
      contributionPct: 16.7,
      activityCount: 27,
      completedTasksCount: 16,
      sessionsCount: 11,
      focusMinutes: 480,
      xpOverTime: _generateTrendSeries(baseXp: 2150, days: 14, volatility: 0.7),
      previousXpOverTime: _generateTrendSeries(baseXp: 1920, days: 14, volatility: 0.5),
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
      xpDelta: MetricDelta.compute(current: 1640, previous: 1720),
      allTimeXp: 7200,
      contributionPct: 12.7,
      activityCount: 20,
      completedTasksCount: 12,
      sessionsCount: 8,
      focusMinutes: 360,
      xpOverTime: _generateTrendSeries(baseXp: 1640, days: 14, volatility: 0.6),
      previousXpOverTime: _generateTrendSeries(baseXp: 1720, days: 14, volatility: 0.7),
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
      xpDelta: MetricDelta.compute(current: 1280, previous: 1180),
      allTimeXp: 5400,
      contributionPct: 9.9,
      activityCount: 16,
      completedTasksCount: 10,
      sessionsCount: 6,
      focusMinutes: 270,
      xpOverTime: _generateTrendSeries(baseXp: 1280, days: 14, volatility: 0.5),
      previousXpOverTime: _generateTrendSeries(baseXp: 1180, days: 14, volatility: 0.4),
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
      xpDelta: MetricDelta.compute(current: 960, previous: 840),
      allTimeXp: 3900,
      contributionPct: 7.4,
      activityCount: 13,
      completedTasksCount: 8,
      sessionsCount: 5,
      focusMinutes: 210,
      xpOverTime: _generateTrendSeries(baseXp: 960, days: 14, volatility: 0.4),
      previousXpOverTime: _generateTrendSeries(baseXp: 840, days: 14, volatility: 0.5),
    ),
  ];

  List<AnalyticsSkillMetric> _buildCurrentSkills() {
    switch (_preset) {
      case _TopSkillsPreset.standardBaseline:
      case _TopSkillsPreset.selectedDetail:
        return _baselineSkills;

      case _TopSkillsPreset.fewSkills:
        return _baselineSkills.take(3).toList();

      case _TopSkillsPreset.singleSkill:
        return [_baselineSkills.first];

      case _TopSkillsPreset.emptyState:
        return const [];

      case _TopSkillsPreset.largeCount:
        final extra = <AnalyticsSkillMetric>[
          ..._baselineSkills,
          AnalyticsSkillMetric(
            id: 'skill-7',
            name: 'API Contract Design',
            groupName: 'Backend Engineering',
            lifeAreaId: 'la_prof',
            lifeAreaName: 'Professional',
            rank: SkillRank.c,
            periodXp: 820,
            previousPeriodXp: 700,
            xpDelta: MetricDelta.compute(current: 820, previous: 700),
            allTimeXp: 3100,
            contributionPct: 5.2,
            activityCount: 10,
            completedTasksCount: 7,
            sessionsCount: 3,
            focusMinutes: 180,
            xpOverTime: _generateTrendSeries(baseXp: 820, days: 14, volatility: 0.4),
            previousXpOverTime: _generateTrendSeries(baseXp: 700, days: 14, volatility: 0.4),
          ),
          AnalyticsSkillMetric(
            id: 'skill-8',
            name: 'State Management Tuning',
            groupName: 'Frontend Architecture',
            lifeAreaId: 'la_prof',
            lifeAreaName: 'Professional',
            rank: SkillRank.c,
            periodXp: 740,
            previousPeriodXp: 620,
            xpDelta: MetricDelta.compute(current: 740, previous: 620),
            allTimeXp: 2800,
            contributionPct: 4.7,
            activityCount: 9,
            completedTasksCount: 6,
            sessionsCount: 3,
            focusMinutes: 160,
            xpOverTime: _generateTrendSeries(baseXp: 740, days: 14, volatility: 0.3),
            previousXpOverTime: _generateTrendSeries(baseXp: 620, days: 14, volatility: 0.3),
          ),
          AnalyticsSkillMetric(
            id: 'skill-9',
            name: 'Public Speaking',
            groupName: 'Communication',
            lifeAreaId: 'la_prof',
            lifeAreaName: 'Professional',
            rank: SkillRank.d,
            periodXp: 510,
            previousPeriodXp: 400,
            xpDelta: MetricDelta.compute(current: 510, previous: 400),
            allTimeXp: 1900,
            contributionPct: 3.2,
            activityCount: 6,
            completedTasksCount: 4,
            sessionsCount: 2,
            focusMinutes: 110,
            xpOverTime: _generateTrendSeries(baseXp: 510, days: 14, volatility: 0.3),
            previousXpOverTime: _generateTrendSeries(baseXp: 400, days: 14, volatility: 0.2),
          ),
          AnalyticsSkillMetric(
            id: 'skill-10',
            name: 'Strength Training Mechanics',
            groupName: 'Physical Conditioning',
            lifeAreaId: 'la_health',
            lifeAreaName: 'Health & Sport',
            rank: SkillRank.d,
            periodXp: 440,
            previousPeriodXp: 480,
            xpDelta: MetricDelta.compute(current: 440, previous: 480),
            allTimeXp: 1650,
            contributionPct: 2.8,
            activityCount: 8,
            completedTasksCount: 5,
            sessionsCount: 3,
            focusMinutes: 140,
            xpOverTime: _generateTrendSeries(baseXp: 440, days: 14, volatility: 0.4),
            previousXpOverTime: _generateTrendSeries(baseXp: 480, days: 14, volatility: 0.4),
          ),
        ];
        return extra;

      case _TopSkillsPreset.longNames:
        return [
          AnalyticsSkillMetric(
            id: 'skill-long-1',
            name: 'Ultra-High-Throughput Distributed Microservice Orchestration & Fault Tolerance',
            groupName: 'Infrastructure Engineering & Cloud Native Systems Operations',
            lifeAreaId: 'la_prof',
            lifeAreaName: 'Professional Development',
            rank: SkillRank.s,
            periodXp: 5820,
            previousPeriodXp: 4200,
            xpDelta: MetricDelta.compute(current: 5820, previous: 4200),
            allTimeXp: 28400,
            contributionPct: 62.4,
            activityCount: 52,
            completedTasksCount: 38,
            sessionsCount: 14,
            focusMinutes: 980,
            xpOverTime: _generateTrendSeries(baseXp: 5820, days: 14, volatility: 0.9),
            previousXpOverTime: _generateTrendSeries(baseXp: 4200, days: 14, volatility: 0.7),
          ),
          AnalyticsSkillMetric(
            id: 'skill-long-2',
            name: 'Advanced Asynchronous Event Sourcing and Distributed Transaction Compensation',
            groupName: 'Transactional Systems Architecture & Design',
            lifeAreaId: 'la_prof',
            lifeAreaName: 'Professional Development',
            rank: SkillRank.a,
            periodXp: 3510,
            previousPeriodXp: 3600,
            xpDelta: MetricDelta.compute(current: 3510, previous: 3600),
            allTimeXp: 14200,
            contributionPct: 37.6,
            activityCount: 29,
            completedTasksCount: 21,
            sessionsCount: 8,
            focusMinutes: 520,
            xpOverTime: _generateTrendSeries(baseXp: 3510, days: 14, volatility: 0.8),
            previousXpOverTime: _generateTrendSeries(baseXp: 3600, days: 14, volatility: 0.8),
          ),
        ];

      case _TopSkillsPreset.largeNumbers:
        return [
          AnalyticsSkillMetric(
            id: 'skill-big-1',
            name: 'Global Enterprise Engineering',
            groupName: 'Core Competency',
            lifeAreaId: 'la_prof',
            lifeAreaName: 'Professional',
            rank: SkillRank.s,
            periodXp: 148200,
            previousPeriodXp: 112000,
            xpDelta: MetricDelta.compute(current: 148200, previous: 112000),
            allTimeXp: 1845000,
            contributionPct: 76.5,
            activityCount: 420,
            completedTasksCount: 280,
            sessionsCount: 140,
            focusMinutes: 9400,
            xpOverTime: _generateTrendSeries(baseXp: 148200, days: 14, volatility: 0.8),
            previousXpOverTime: _generateTrendSeries(baseXp: 112000, days: 14, volatility: 0.6),
          ),
          AnalyticsSkillMetric(
            id: 'skill-big-2',
            name: 'High-Dimensional Analytics',
            groupName: 'Intelligence',
            lifeAreaId: 'la_prof',
            lifeAreaName: 'Professional',
            rank: SkillRank.a,
            periodXp: 45600,
            previousPeriodXp: 39800,
            xpDelta: MetricDelta.compute(current: 45600, previous: 39800),
            allTimeXp: 450000,
            contributionPct: 23.5,
            activityCount: 145,
            completedTasksCount: 95,
            sessionsCount: 50,
            focusMinutes: 3200,
            xpOverTime: _generateTrendSeries(baseXp: 45600, days: 14, volatility: 0.7),
            previousXpOverTime: _generateTrendSeries(baseXp: 39800, days: 14, volatility: 0.5),
          ),
        ];

      case _TopSkillsPreset.growthVariations:
        return [
          AnalyticsSkillMetric(
            id: 'skill-g1',
            name: 'Hyper-Growth Capability',
            groupName: 'Explosive Momentum',
            lifeAreaId: 'la_prof',
            lifeAreaName: 'Professional',
            rank: SkillRank.s,
            periodXp: 4200,
            previousPeriodXp: 1400,
            xpDelta: MetricDelta.compute(current: 4200, previous: 1400), // +200.0%
            allTimeXp: 12500,
            contributionPct: 45.0,
            activityCount: 38,
            completedTasksCount: 25,
            sessionsCount: 13,
            focusMinutes: 720,
            xpOverTime: _generateTrendSeries(baseXp: 4200, days: 14, volatility: 0.9),
            previousXpOverTime: _generateTrendSeries(baseXp: 1400, days: 14, volatility: 0.5),
          ),
          AnalyticsSkillMetric(
            id: 'skill-g2',
            name: 'Plateaued Competency',
            groupName: 'Stable Maintenance',
            lifeAreaId: 'la_mind',
            lifeAreaName: 'Mindset',
            rank: SkillRank.b,
            periodXp: 2800,
            previousPeriodXp: 2800,
            xpDelta: MetricDelta.compute(current: 2800, previous: 2800), // 0.0%
            allTimeXp: 9800,
            contributionPct: 30.0,
            activityCount: 22,
            completedTasksCount: 15,
            sessionsCount: 7,
            focusMinutes: 440,
            xpOverTime: _generateTrendSeries(baseXp: 2800, days: 14, volatility: 0.6),
            previousXpOverTime: _generateTrendSeries(baseXp: 2800, days: 14, volatility: 0.6),
          ),
          AnalyticsSkillMetric(
            id: 'skill-g3',
            name: 'Decaying Capability',
            groupName: 'Cooling Off',
            lifeAreaId: 'la_learn',
            lifeAreaName: 'Learning',
            rank: SkillRank.c,
            periodXp: 1200,
            previousPeriodXp: 2400,
            xpDelta: MetricDelta.compute(current: 1200, previous: 2400), // -50.0%
            allTimeXp: 6400,
            contributionPct: 15.0,
            activityCount: 11,
            completedTasksCount: 8,
            sessionsCount: 3,
            focusMinutes: 190,
            xpOverTime: _generateTrendSeries(baseXp: 1200, days: 14, volatility: 0.4),
            previousXpOverTime: _generateTrendSeries(baseXp: 2400, days: 14, volatility: 0.8),
          ),
          AnalyticsSkillMetric(
            id: 'skill-g4',
            name: 'Brand-New Unlocked Skill',
            groupName: 'Fresh Inception',
            lifeAreaId: 'la_health',
            lifeAreaName: 'Health & Sport',
            rank: SkillRank.d,
            periodXp: 800,
            previousPeriodXp: 0,
            xpDelta: MetricDelta.compute(current: 800, previous: 0), // Inf/100%
            allTimeXp: 800,
            contributionPct: 10.0,
            activityCount: 7,
            completedTasksCount: 5,
            sessionsCount: 2,
            focusMinutes: 120,
            xpOverTime: _generateTrendSeries(baseXp: 800, days: 14, volatility: 0.5),
            previousXpOverTime: const [],
          ),
        ];

      default:
        return _baselineSkills;
    }
  }

  AnalyticsSnapshot _createSnapshot(List<AnalyticsSkillMetric> skills) {
    var filtered = skills;
    if (_selectedLifeAreaId != null) {
      filtered = skills.where((s) => s.lifeAreaId == _selectedLifeAreaId).toList();
    }

    return AnalyticsSnapshot(
      range: AnalyticsDateRange.forPeriod(AnalyticsPeriod.thirtyDays),
      lifeAreaId: _selectedLifeAreaId,
      totalXp: 12400,
      previousTotalXp: 10800,
      xpDelta: MetricDelta.compute(current: 12400, previous: 10800),
      positiveXp: 12400,
      negativeXp: 0,
      xpVelocityDelta: MetricDelta.compute(current: 413, previous: 360),
      completionRateDelta: MetricDelta.compute(current: 78, previous: 72),
      consistencyDelta: MetricDelta.compute(current: 85, previous: 80),
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
      topSkills: filtered,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final skills = _buildCurrentSkills();
    final snapshot = _preset == _TopSkillsPreset.errorState ? null : _createSnapshot(skills);
    final isLoading = _preset == _TopSkillsPreset.loadingSkeleton;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020302) : const Color(0xFFF7F6F2),
      body: SafeArea(
        child: Column(
          children: [
            // Storybook Toolbar
            _buildStorybookToolbar(isDark),

            // Main Content Area with Viewport Sizing
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: switch (_viewport) {
                        _ViewportPreset.desktop => 1200,
                        _ViewportPreset.tablet => 840,
                        _ViewportPreset.mobile => 440,
                      },
                    ),
                    child: AnalyticsTopSkillsCard(
                      snapshot: snapshot,
                      isLoading: isLoading,
                      periodSubtitle: 'Last 30 Days vs Prior 30 Days',
                      initialSelectedSkillId: _selectedSkillId,
                      lifeAreas: _mockLifeAreas,
                      selectedLifeAreaId: _selectedLifeAreaId,
                      onLifeAreaChanged: (areaId) {
                        setState(() => _selectedLifeAreaId = areaId);
                      },
                      onSkillSelected: (id) {
                        setState(() => _selectedSkillId = id);
                      },
                      onRetry: () {
                        setState(() => _preset = _TopSkillsPreset.standardBaseline);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorybookToolbar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D100E) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0x1FFFFFFF) : const Color(0x1F0F172A),
          ),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Left: Title + Preset Dropdown
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'WAVE 08: TOP SKILLS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime,
                ),
              ),
              const SizedBox(width: 14),
              DropdownButton<_TopSkillsPreset>(
                value: _preset,
                dropdownColor: isDark ? const Color(0xFF141815) : Colors.white,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
                ),
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                    value: _TopSkillsPreset.standardBaseline,
                    child: Text('1. Baseline Top 6 Skills'),
                  ),
                  DropdownMenuItem(
                    value: _TopSkillsPreset.selectedDetail,
                    child: Text('2. Selected Skill Detail'),
                  ),
                  DropdownMenuItem(
                    value: _TopSkillsPreset.largeCount,
                    child: Text('3. Large Count (10+ Skills)'),
                  ),
                  DropdownMenuItem(
                    value: _TopSkillsPreset.fewSkills,
                    child: Text('4. Few Skills (3 items)'),
                  ),
                  DropdownMenuItem(
                    value: _TopSkillsPreset.singleSkill,
                    child: Text('5. Single Skill (1 item)'),
                  ),
                  DropdownMenuItem(
                    value: _TopSkillsPreset.emptyState,
                    child: Text('6. Empty State (0 skills)'),
                  ),
                  DropdownMenuItem(
                    value: _TopSkillsPreset.loadingSkeleton,
                    child: Text('7. Loading Skeleton Shimmer'),
                  ),
                  DropdownMenuItem(
                    value: _TopSkillsPreset.errorState,
                    child: Text('8. Error State with Retry'),
                  ),
                  DropdownMenuItem(
                    value: _TopSkillsPreset.longNames,
                    child: Text('9. Long Names Truncation'),
                  ),
                  DropdownMenuItem(
                    value: _TopSkillsPreset.largeNumbers,
                    child: Text('10. Large XP Numbers (1M+)'),
                  ),
                  DropdownMenuItem(
                    value: _TopSkillsPreset.growthVariations,
                    child: Text('11. Growth Deltas (+ / - / 0)'),
                  ),
                ],
                onChanged: (p) {
                  if (p != null) setState(() => _preset = p);
                },
              ),
            ],
          ),

          // Right: Viewport & Theme Toggles
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Viewport Buttons
              SegmentedButton<_ViewportPreset>(
                segments: const [
                  ButtonSegment(
                    value: _ViewportPreset.desktop,
                    icon: Icon(Icons.desktop_windows, size: 14),
                    label: Text('Desktop', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: _ViewportPreset.tablet,
                    icon: Icon(Icons.tablet, size: 14),
                    label: Text('Tablet', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: _ViewportPreset.mobile,
                    icon: Icon(Icons.phone_android, size: 14),
                    label: Text('Mobile', style: TextStyle(fontSize: 11)),
                  ),
                ],
                selected: {_viewport},
                onSelectionChanged: (set) {
                  setState(() => _viewport = set.first);
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 12),
              // Theme Toggle
              IconButton(
                tooltip: 'Toggle Dark / Light Theme',
                icon: Icon(
                  isDark ? Icons.light_mode : Icons.dark_mode,
                  size: 18,
                  color: isDark ? KratosTheme.acidLime : KratosTheme.lightTextPrimary,
                ),
                onPressed: () {
                  final nextMode = isDark ? ThemeMode.light : ThemeMode.dark;
                  KratosThemeController.instance.setThemeMode(nextMode);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
