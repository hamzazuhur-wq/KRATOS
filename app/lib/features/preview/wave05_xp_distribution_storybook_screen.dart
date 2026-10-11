import 'package:flutter/material.dart';

import '../../app/kratos_theme.dart';
import '../../app/kratos_theme_controller.dart';
import '../analytics/domain/analytics_models.dart';
import '../analytics/presentation/widgets/analytics_xp_distribution_card.dart';

/// Wave 05: Dedicated XP Distribution Widget Preview & Storybook.
///
/// Supports all 12 required preview states:
/// 1. Dark — populated
/// 2. Light — populated
/// 3. Dark — many sources (8+ sources)
/// 4. Light — many sources
/// 5. Empty (0 XP)
/// 6. Loading (skeleton)
/// 7. Error (with retry)
/// 8. Negative XP (penalties present)
/// 9. Mobile viewport preview (390px)
/// 10. Tablet viewport preview (768px)
/// 11. Desktop viewport preview (full width)
/// 12. Source hover/tap simulation
class Wave05XpDistributionStorybookScreen extends StatefulWidget {
  const Wave05XpDistributionStorybookScreen({super.key});

  @override
  State<Wave05XpDistributionStorybookScreen> createState() =>
      _Wave05XpDistributionStorybookScreenState();
}

enum _PreviewStatePreset {
  populated,
  manySources,
  empty,
  loading,
  error,
  negativeXp,
}

enum _ViewportPreset {
  desktop,
  tablet,
  mobile,
}

class _Wave05XpDistributionStorybookScreenState
    extends State<Wave05XpDistributionStorybookScreen> {
  _PreviewStatePreset _statePreset = _PreviewStatePreset.populated;
  _ViewportPreset _viewportPreset = _ViewportPreset.desktop;
  String? _simulatedSourceSelection;
  bool _retryTriggered = false;

  AnalyticsSnapshot _buildSnapshotForPreset(_PreviewStatePreset preset) {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final range = AnalyticsDateRange(
      start: today.subtract(const Duration(days: 29)),
      end: today.add(const Duration(days: 1)),
      period: AnalyticsPeriod.thirtyDays,
    );

    switch (preset) {
      case _PreviewStatePreset.populated:
        return AnalyticsSnapshot(
          range: range,
          lifeAreaId: null,
          totalXp: 11584,
          previousTotalXp: 10197,
          xpDelta: const MetricDelta(
            current: 11584,
            previous: 10197,
            changePct: 13.6,
            isPositive: true,
          ),
          positiveXp: 11842,
          negativeXp: 258,
          xpVelocityDelta: const MetricDelta(
            current: 386.1,
            previous: 339.9,
            changePct: 13.6,
            isPositive: true,
          ),
          completionRateDelta: const MetricDelta(
            current: 82.4,
            previous: 76.2,
            changePct: 8.1,
            isPositive: true,
          ),
          consistencyDelta: const MetricDelta(
            current: 93.3,
            previous: 88.0,
            changePct: 6.0,
            isPositive: true,
          ),
          activeGoals: 6,
          completedGoals: 3,
          activeProjects: 4,
          completedProjects: 2,
          activeTasks: 18,
          completedTasks: 42,
          activitiesStarted: 35,
          sessionsCompleted: 28,
          actualMinutes: 1420,
          currentStreak: 14,
          longestStreak: 21,
          xpOverTime: const [],
          xpBySource: const {
            'Tasks': 3932,
            'Projects': 2542,
            'Habits & Focus': 1853,
            'Goals': 1389,
            'Activities': 926,
            'Manual': 694,
            'Other': 248,
          },
          lifeAreas: const [],
        );

      case _PreviewStatePreset.manySources:
        return AnalyticsSnapshot(
          range: range,
          lifeAreaId: null,
          totalXp: 18450,
          previousTotalXp: 15200,
          xpDelta: const MetricDelta(
            current: 18450,
            previous: 15200,
            changePct: 21.4,
            isPositive: true,
          ),
          positiveXp: 18600,
          negativeXp: 150,
          xpVelocityDelta: const MetricDelta(
            current: 615,
            previous: 506,
            changePct: 21.4,
            isPositive: true,
          ),
          completionRateDelta: const MetricDelta(
            current: 88.0,
            previous: 80.0,
            changePct: 10.0,
            isPositive: true,
          ),
          consistencyDelta: const MetricDelta(
            current: 95.0,
            previous: 90.0,
            changePct: 5.5,
            isPositive: true,
          ),
          activeGoals: 8,
          completedGoals: 5,
          activeProjects: 6,
          completedProjects: 4,
          activeTasks: 25,
          completedTasks: 60,
          activitiesStarted: 45,
          sessionsCompleted: 38,
          actualMinutes: 2100,
          currentStreak: 24,
          longestStreak: 30,
          xpOverTime: const [],
          xpBySource: const {
            'Tasks': 5200,
            'Projects': 3800,
            'Habits & Focus': 2600,
            'Goals': 2100,
            'Skills': 1750,
            'Streaks': 1200,
            'Decisions': 950,
            'Challenges': 550,
            'Other': 300,
          },
          lifeAreas: const [],
        );

      case _PreviewStatePreset.negativeXp:
        return AnalyticsSnapshot(
          range: range,
          lifeAreaId: null,
          totalXp: 4850,
          previousTotalXp: 6200,
          xpDelta: const MetricDelta(
            current: 4850,
            previous: 6200,
            changePct: -21.8,
            isPositive: false,
          ),
          positiveXp: 6100,
          negativeXp: 1250,
          xpVelocityDelta: const MetricDelta(
            current: 161.6,
            previous: 206.6,
            changePct: -21.8,
            isPositive: false,
          ),
          completionRateDelta: const MetricDelta(
            current: 64.0,
            previous: 78.0,
            changePct: -17.9,
            isPositive: false,
          ),
          consistencyDelta: const MetricDelta(
            current: 70.0,
            previous: 85.0,
            changePct: -17.6,
            isPositive: false,
          ),
          activeGoals: 4,
          completedGoals: 1,
          activeProjects: 3,
          completedProjects: 1,
          activeTasks: 14,
          completedTasks: 20,
          activitiesStarted: 15,
          sessionsCompleted: 12,
          actualMinutes: 650,
          currentStreak: 2,
          longestStreak: 18,
          xpOverTime: const [],
          xpBySource: const {
            'Tasks': 2400,
            'Projects': 1600,
            'Habits & Focus': 1200,
            'Goals': 900,
          },
          lifeAreas: const [],
        );

      case _PreviewStatePreset.empty:
      case _PreviewStatePreset.loading:
      case _PreviewStatePreset.error:
        return AnalyticsSnapshot(
          range: range,
          lifeAreaId: null,
          totalXp: 0,
          previousTotalXp: 0,
          xpDelta: const MetricDelta(
            current: 0,
            previous: 0,
            changePct: 0,
            isPositive: true,
            isNeutral: true,
          ),
          positiveXp: 0,
          negativeXp: 0,
          xpVelocityDelta: const MetricDelta(
            current: 0,
            previous: 0,
            changePct: 0,
            isPositive: true,
            isNeutral: true,
          ),
          completionRateDelta: const MetricDelta(
            current: 0,
            previous: 0,
            changePct: 0,
            isPositive: true,
            isNeutral: true,
          ),
          consistencyDelta: const MetricDelta(
            current: 0,
            previous: 0,
            changePct: 0,
            isPositive: true,
            isNeutral: true,
          ),
          activeGoals: 0,
          completedGoals: 0,
          activeProjects: 0,
          completedProjects: 0,
          activeTasks: 0,
          completedTasks: 0,
          activitiesStarted: 0,
          sessionsCompleted: 0,
          actualMinutes: 0,
          currentStreak: 0,
          longestStreak: 0,
          xpOverTime: const [],
          xpBySource: const {},
          lifeAreas: const [],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = KratosThemeController.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final snapshot = _buildSnapshotForPreset(_statePreset);

    double? containerWidth;
    switch (_viewportPreset) {
      case _ViewportPreset.desktop:
        containerWidth = null; // Full
        break;
      case _ViewportPreset.tablet:
        containerWidth = 768;
        break;
      case _ViewportPreset.mobile:
        containerWidth = 390;
        break;
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070907) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // ── Storybook Top Control Toolbar ────────────────────────────────
            _buildToolbar(context, isDark, themeController),

            // ── Interactive Viewport Canvas ──────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Center(
                  child: Container(
                    width: containerWidth,
                    decoration: containerWidth != null
                        ? BoxDecoration(
                            border: Border.all(
                              color: isDark ? Colors.white24 : Colors.black26,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          )
                        : null,
                    padding: containerWidth != null
                        ? const EdgeInsets.all(12)
                        : EdgeInsets.zero,
                    child: _statePreset == _PreviewStatePreset.error
                        ? _buildErrorPlaceholder(isDark)
                        : AnalyticsXpDistributionCard(
                            snapshot: snapshot,
                            periodSubtitle: 'vs previous 30 days',
                            isLoading: _statePreset == _PreviewStatePreset.loading,
                            onRetry: () => setState(() => _retryTriggered = true),
                            onSourceSelected: (src) {
                              setState(() => _simulatedSourceSelection = src);
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

  Widget _buildToolbar(
    BuildContext context,
    bool isDark,
    KratosThemeController themeController,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141814) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : const Color(0x1F0F172A),
          ),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'STORYBOOK: XP Distribution',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),

          // State Preset Selector
          DropdownButton<_PreviewStatePreset>(
            value: _statePreset,
            dropdownColor: isDark ? const Color(0xFF1B201B) : Colors.white,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(
                value: _PreviewStatePreset.populated,
                child: Text('Populated (Reference)'),
              ),
              DropdownMenuItem(
                value: _PreviewStatePreset.manySources,
                child: Text('Many Sources (8+)'),
              ),
              DropdownMenuItem(
                value: _PreviewStatePreset.negativeXp,
                child: Text('Negative XP (Penalties)'),
              ),
              DropdownMenuItem(
                value: _PreviewStatePreset.empty,
                child: Text('Empty State (0 XP)'),
              ),
              DropdownMenuItem(
                value: _PreviewStatePreset.loading,
                child: Text('Loading Skeleton'),
              ),
              DropdownMenuItem(
                value: _PreviewStatePreset.error,
                child: Text('Error State'),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _statePreset = val);
            },
          ),

          // Viewport Preset
          DropdownButton<_ViewportPreset>(
            value: _viewportPreset,
            dropdownColor: isDark ? const Color(0xFF1B201B) : Colors.white,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(
                value: _ViewportPreset.desktop,
                child: Text('Desktop (Full)'),
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
            onChanged: (val) {
              if (val != null) setState(() => _viewportPreset = val);
            },
          ),

          // Theme Mode Toggle
          IconButton(
            tooltip: 'Toggle Theme',
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 18,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            onPressed: () {
              themeController.setThemeMode(
                isDark ? ThemeMode.light : ThemeMode.dark,
              );
            },
          ),

          if (_simulatedSourceSelection != null)
            Text(
              'Selected: $_simulatedSourceSelection',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorPlaceholder(bool isDark) {
    return Container(
      width: double.infinity,
      height: 240,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xE6141814) : const Color(0xF5FFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFF5252).withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 38,
              color: Color(0xFFFF5252),
            ),
            const SizedBox(height: 10),
            Text(
              'Failed to load XP Distribution data',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _statePreset = _PreviewStatePreset.populated);
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(_retryTriggered ? 'Retrying...' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
