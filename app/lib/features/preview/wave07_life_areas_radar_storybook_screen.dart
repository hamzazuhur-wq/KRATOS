import 'package:flutter/material.dart';

import '../../app/kratos_theme.dart';
import '../../app/kratos_theme_controller.dart';
import '../analytics/domain/analytics_models.dart';
import '../analytics/presentation/widgets/analytics_life_areas_overview_card.dart';

/// Wave 07 / Life Areas Overview Storybook Screen.
///
/// Features interactive preview coverage:
/// 1. Dark Mode & Light Mode
/// 2. 5 Life Areas (Master Reference Baseline)
/// 3. Day 2 Updated Data (Animate oldValues -> newValues)
/// 4. Selected State (Knowledge highlighted)
/// 5. Large Count (9 Life Areas with deliberate Top 7 Radar strategy)
/// 6. Few Areas (3 Life Areas)
/// 7. Empty State (0 Life Areas)
/// 8. Loading Skeleton State
/// 9. Error State with Retry
/// 10. Multi-viewport adaptation: Desktop (1440x900), Tablet (1024x768 / 768px), Mobile (430x932 / 390px)
class Wave07LifeAreasRadarStorybookScreen extends StatefulWidget {
  const Wave07LifeAreasRadarStorybookScreen({super.key});

  @override
  State<Wave07LifeAreasRadarStorybookScreen> createState() =>
      _Wave07LifeAreasRadarStorybookScreenState();
}

enum _RadarStorybookPreset {
  standardFive,
  updatedDayTwo,
  selectedKnowledge,
  largeCount,
  fewAreas,
  emptyState,
  loadingSkeleton,
  errorState,
}

enum _ViewportPreset { desktop, tablet, mobile }

class _Wave07LifeAreasRadarStorybookScreenState
    extends State<Wave07LifeAreasRadarStorybookScreen> {
  _RadarStorybookPreset _preset = _RadarStorybookPreset.standardFive;
  _ViewportPreset _viewport = _ViewportPreset.desktop;
  bool _toggleDayTwoManually = false;

  @override
  void initState() {
    super.initState();
    final p = Uri.base.queryParameters['preset'];
    if (p == 'day2' || p == 'updated') {
      _preset = _RadarStorybookPreset.updatedDayTwo;
    } else if (p == 'selected') {
      _preset = _RadarStorybookPreset.selectedKnowledge;
    } else if (p == 'large' || p == 'nine') {
      _preset = _RadarStorybookPreset.largeCount;
    } else if (p == 'empty') {
      _preset = _RadarStorybookPreset.emptyState;
    } else if (p == 'skeleton') {
      _preset = _RadarStorybookPreset.loadingSkeleton;
    }
  }

  // Day 1 Baseline (from user reference)
  static final List<AnalyticsLifeAreaMetric> _baselineFive = [
    const AnalyticsLifeAreaMetric(
      id: 'la_health',
      name: 'Health',
      xp: 6800,
      level: 4,
      tier: 'Crystal',
      currentStreak: 12,
      longestStreak: 24,
      progress: 0.68,
      activityCount: 34,
      completionCount: 28,
      trendPct: 8.5,
      color: '#EEFF08',
    ),
    const AnalyticsLifeAreaMetric(
      id: 'la_wealth',
      name: 'Wealth',
      xp: 4200,
      level: 3,
      tier: 'Gold',
      currentStreak: 8,
      longestStreak: 15,
      progress: 0.42,
      activityCount: 22,
      completionCount: 16,
      trendPct: -3.2,
      color: '#EEFF08',
    ),
    const AnalyticsLifeAreaMetric(
      id: 'la_relationships',
      name: 'Relationships',
      xp: 3200,
      level: 2,
      tier: 'Silver',
      currentStreak: 5,
      longestStreak: 10,
      progress: 0.32,
      activityCount: 18,
      completionCount: 12,
      trendPct: 2.1,
      color: '#EEFF08',
    ),
    const AnalyticsLifeAreaMetric(
      id: 'la_knowledge',
      name: 'Knowledge',
      xp: 7600,
      level: 5,
      tier: 'Diamond',
      currentStreak: 18,
      longestStreak: 30,
      progress: 0.76,
      activityCount: 45,
      completionCount: 38,
      trendPct: 12.4,
      color: '#EEFF08',
    ),
    const AnalyticsLifeAreaMetric(
      id: 'la_creativity',
      name: 'Creativity',
      xp: 5400,
      level: 3,
      tier: 'Gold',
      currentStreak: 9,
      longestStreak: 14,
      progress: 0.54,
      activityCount: 26,
      completionCount: 20,
      trendPct: 5.6,
      color: '#EEFF08',
    ),
  ];

  // Day 2 Updated Values (interpolates dynamically)
  static final List<AnalyticsLifeAreaMetric> _updatedDayTwoValues = [
    const AnalyticsLifeAreaMetric(
      id: 'la_health',
      name: 'Health',
      xp: 7200,
      level: 4,
      tier: 'Crystal',
      currentStreak: 13,
      longestStreak: 24,
      progress: 0.72,
      activityCount: 38,
      completionCount: 32,
      trendPct: 12.2,
      color: '#EEFF08',
    ),
    const AnalyticsLifeAreaMetric(
      id: 'la_wealth',
      name: 'Wealth',
      xp: 3500,
      level: 3,
      tier: 'Gold',
      currentStreak: 9,
      longestStreak: 15,
      progress: 0.35,
      activityCount: 20,
      completionCount: 14,
      trendPct: -5.4,
      color: '#EEFF08',
    ),
    const AnalyticsLifeAreaMetric(
      id: 'la_relationships',
      name: 'Relationships',
      xp: 4200,
      level: 3,
      tier: 'Gold',
      currentStreak: 6,
      longestStreak: 10,
      progress: 0.42,
      activityCount: 24,
      completionCount: 18,
      trendPct: 8.8,
      color: '#EEFF08',
    ),
    const AnalyticsLifeAreaMetric(
      id: 'la_knowledge',
      name: 'Knowledge',
      xp: 8600,
      level: 5,
      tier: 'Diamond',
      currentStreak: 19,
      longestStreak: 30,
      progress: 0.86,
      activityCount: 52,
      completionCount: 45,
      trendPct: 15.0,
      color: '#EEFF08',
    ),
    const AnalyticsLifeAreaMetric(
      id: 'la_creativity',
      name: 'Creativity',
      xp: 6400,
      level: 4,
      tier: 'Crystal',
      currentStreak: 10,
      longestStreak: 14,
      progress: 0.64,
      activityCount: 31,
      completionCount: 25,
      trendPct: 9.3,
      color: '#EEFF08',
    ),
  ];

  // Large Count: 9 Life Areas
  static final List<AnalyticsLifeAreaMetric> _largeCountAreas = [
    ..._baselineFive,
    const AnalyticsLifeAreaMetric(
      id: 'la_inner_peace',
      name: 'Inner Peace',
      xp: 4900,
      level: 3,
      tier: 'Gold',
      currentStreak: 7,
      longestStreak: 12,
      progress: 0.49,
      activityCount: 19,
      completionCount: 15,
      trendPct: 4.2,
      color: '#EEFF08',
    ),
    const AnalyticsLifeAreaMetric(
      id: 'la_productivity',
      name: 'Productivity',
      xp: 6200,
      level: 4,
      tier: 'Crystal',
      currentStreak: 11,
      longestStreak: 20,
      progress: 0.62,
      activityCount: 30,
      completionCount: 26,
      trendPct: 7.1,
      color: '#EEFF08',
    ),
    const AnalyticsLifeAreaMetric(
      id: 'la_social',
      name: 'Social Impact',
      xp: 2800,
      level: 2,
      tier: 'Silver',
      currentStreak: 4,
      longestStreak: 8,
      progress: 0.28,
      activityCount: 14,
      completionCount: 9,
      trendPct: -1.0,
      color: '#EEFF08',
    ),
    const AnalyticsLifeAreaMetric(
      id: 'la_mindfulness',
      name: 'Mindfulness',
      xp: 5100,
      level: 3,
      tier: 'Gold',
      currentStreak: 8,
      longestStreak: 16,
      progress: 0.51,
      activityCount: 25,
      completionCount: 21,
      trendPct: 6.0,
      color: '#EEFF08',
    ),
  ];

  AnalyticsSnapshot _createSnapshot(List<AnalyticsLifeAreaMetric> areas) {
    return AnalyticsSnapshot(
      range: AnalyticsDateRange.forPeriod(AnalyticsPeriod.thirtyDays),
      lifeAreaId: null,
      totalXp: areas.fold(0, (acc, a) => acc + a.xp),
      previousTotalXp: (areas.fold(0, (acc, a) => acc + a.xp) * 0.88).round(),
      xpDelta: const MetricDelta(
        current: 27200,
        previous: 24000,
        changePct: 13.3,
        isPositive: true,
      ),
      positiveXp: 27200,
      negativeXp: 0,
      xpVelocityDelta: const MetricDelta(
        current: 906,
        previous: 800,
        changePct: 13.25,
        isPositive: true,
      ),
      completionRateDelta: const MetricDelta(
        current: 82,
        previous: 76,
        changePct: 7.8,
        isPositive: true,
      ),
      consistencyDelta: const MetricDelta(
        current: 91,
        previous: 85,
        changePct: 7.0,
        isPositive: true,
      ),
      activeGoals: 8,
      completedGoals: 4,
      activeProjects: 5,
      completedProjects: 3,
      activeTasks: 14,
      completedTasks: 42,
      activitiesStarted: 35,
      sessionsCompleted: 28,
      actualMinutes: 1450,
      currentStreak: 14,
      longestStreak: 30,
      xpOverTime: const [],
      xpBySource: const {},
      lifeAreas: areas,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeController = KratosThemeController.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double? containerWidth;
    switch (_viewport) {
      case _ViewportPreset.desktop:
        containerWidth = null;
        break;
      case _ViewportPreset.tablet:
        containerWidth = 768;
        break;
      case _ViewportPreset.mobile:
        containerWidth = 390;
        break;
    }

    final activeAreas = switch (_preset) {
      _RadarStorybookPreset.standardFive =>
        _toggleDayTwoManually ? _updatedDayTwoValues : _baselineFive,
      _RadarStorybookPreset.updatedDayTwo => _updatedDayTwoValues,
      _RadarStorybookPreset.selectedKnowledge => _baselineFive,
      _RadarStorybookPreset.largeCount => _largeCountAreas,
      _RadarStorybookPreset.fewAreas => _baselineFive.take(3).toList(),
      _RadarStorybookPreset.emptyState => <AnalyticsLifeAreaMetric>[],
      _RadarStorybookPreset.loadingSkeleton => _baselineFive,
      _RadarStorybookPreset.errorState => <AnalyticsLifeAreaMetric>[],
    };

    final snapshot = _createSnapshot(activeAreas);
    final isLoading = _preset == _RadarStorybookPreset.loadingSkeleton;
    final initialFocus = _preset == _RadarStorybookPreset.selectedKnowledge
        ? 'la_knowledge'
        : null;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF020302)
          : const Color(0xFFF6F8F6),
      appBar: AppBar(
        title: const Text(
          'Wave 07 — Life Areas Radar Storybook',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: isDark ? const Color(0xFF090B09) : Colors.white,
        actions: [
          // Theme Switcher
          IconButton(
            tooltip: 'Toggle Theme',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: () {
              themeController.setThemeMode(
                isDark ? ThemeMode.light : ThemeMode.dark,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Controls Bar ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? const Color(0xFF0D100D) : const Color(0xFFF0F3F0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Preset Selector
                  DropdownButton<_RadarStorybookPreset>(
                    value: _preset,
                    onChanged: (p) {
                      if (p != null) setState(() => _preset = p);
                    },
                    items: const [
                      DropdownMenuItem(
                        value: _RadarStorybookPreset.standardFive,
                        child: Text('Baseline (5 Life Areas)'),
                      ),
                      DropdownMenuItem(
                        value: _RadarStorybookPreset.updatedDayTwo,
                        child: Text('Day 2 Updated Data (Animates)'),
                      ),
                      DropdownMenuItem(
                        value: _RadarStorybookPreset.selectedKnowledge,
                        child: Text('Selected State (Knowledge)'),
                      ),
                      DropdownMenuItem(
                        value: _RadarStorybookPreset.largeCount,
                        child: Text('Large Count (9 Areas - Top 7 Radar)'),
                      ),
                      DropdownMenuItem(
                        value: _RadarStorybookPreset.fewAreas,
                        child: Text('Few Areas (3 Areas)'),
                      ),
                      DropdownMenuItem(
                        value: _RadarStorybookPreset.emptyState,
                        child: Text('Empty State'),
                      ),
                      DropdownMenuItem(
                        value: _RadarStorybookPreset.loadingSkeleton,
                        child: Text('Loading Skeleton'),
                      ),
                    ],
                  ),

                  const SizedBox(width: 14),

                  // Viewport Selector
                  DropdownButton<_ViewportPreset>(
                    value: _viewport,
                    onChanged: (v) {
                      if (v != null) setState(() => _viewport = v);
                    },
                    items: const [
                      DropdownMenuItem(
                        value: _ViewportPreset.desktop,
                        child: Text('Desktop (1440x900)'),
                      ),
                      DropdownMenuItem(
                        value: _ViewportPreset.tablet,
                        child: Text('Tablet (768px)'),
                      ),
                      DropdownMenuItem(
                        value: _ViewportPreset.mobile,
                        child: Text('Mobile (390px)'),
                      ),
                    ],
                  ),

                  const SizedBox(width: 14),

                  // Animated Transition Trigger Button
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _toggleDayTwoManually = !_toggleDayTwoManually;
                      });
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: Text(
                      _toggleDayTwoManually
                          ? 'Reset to Day 1 Values'
                          : 'Trigger Day 2 Animated Transition',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KratosTheme.acidLime,
                      foregroundColor: Colors.black,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Preview Viewport ──────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: Container(
                  width: containerWidth,
                  decoration: containerWidth != null
                      ? BoxDecoration(
                          border: Border.all(
                            color: isDark ? Colors.white24 : Colors.black12,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        )
                      : null,
                  padding: containerWidth != null
                      ? const EdgeInsets.all(12)
                      : EdgeInsets.zero,
                  child: AnalyticsLifeAreasOverviewCard(
                    snapshot: snapshot,
                    isLoading: isLoading,
                    initialFocusedLifeAreaId: initialFocus,
                    periodSubtitle: 'Last 30 Days',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
