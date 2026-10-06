import 'package:flutter/material.dart';
import '../../app/kratos_theme.dart';
import '../../app/kratos_theme_controller.dart';
import '../../app/kratos_visuals.dart';
import '../../data/drift/app_database.dart';
import '../goals/presentation/widgets/goal_card.dart';

/// Wave 04 Storybook / Widget Previews Showcase.
/// Renders every existing Goal variant and nested representation:
/// 1. Main Goal (Active, 45% progress, depth 0)
/// 2. Sub-Goal (Depth 1, In-progress, linked tasks, child count)
/// 3. Deep Recursive Sub-Goal (Depth 2, 75% progress)
/// 4. Completed Goal (Depth 0, 100% progress, emerald completion badge)
/// 5. Paused Goal (Amber accent, warning indicators)
/// 6. Stopped Goal (Crimson accent)
/// 7. Empty State (Zero intent detected, Manus empty card)
class Wave04GoalsStorybookScreen extends StatelessWidget {
  const Wave04GoalsStorybookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const testHlc = '2026-10-05T00:00:00.000000000Z_0001_dev';

    // 1. Root Active Goal
    final rootActiveGoal = Goal(
      id: 'root-1',
      ownerId: 'usr-1',
      rootId: 'root-1',
      title: 'Build Autonomous Operating System (KRATOS)',
      description: 'Architecting an offline-first high agency life progression machine.',
      status: 'active',
      depth: 0,
      path: 'root-1',
      progress: 0.45,
      xpTarget: 2500,
      versionHlc: testHlc,
      createdAt: now.subtract(const Duration(days: 14)),
      updatedAt: now,
    );

    // 2. Sub-Goal Depth 1
    final subGoalD1 = Goal(
      id: 'sub-1',
      ownerId: 'usr-1',
      parentId: 'root-1',
      rootId: 'root-1',
      title: 'Implement Liquid Glass Visual Design System',
      description: 'Manus spec tokens, Space Grotesk, IBM Plex Mono, and specular highlights.',
      status: 'active',
      depth: 1,
      path: 'root-1/sub-1',
      progress: 0.65,
      xpTarget: 800,
      versionHlc: testHlc,
      createdAt: now.subtract(const Duration(days: 7)),
      updatedAt: now,
    );

    // 3. Recursive Sub-Goal Depth 2
    final subGoalD2 = Goal(
      id: 'sub-2',
      ownerId: 'usr-1',
      parentId: 'sub-1',
      rootId: 'root-1',
      title: 'Tune Web Animation Curves & 0 Overflow Constraints',
      description: 'Eliminate render overflows across desktop and mobile viewports.',
      status: 'active',
      depth: 2,
      path: 'root-1/sub-1/sub-2',
      progress: 0.85,
      xpTarget: 350,
      versionHlc: testHlc,
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now,
    );

    // 4. Completed Goal
    final completedGoal = Goal(
      id: 'goal-comp',
      ownerId: 'usr-1',
      rootId: 'goal-comp',
      title: 'Phase 1: Local SQLite & Drift Database Schema',
      description: 'Complete CRDT tables, HLC tracking, outbox sync, and DAO indices.',
      status: 'completed',
      depth: 0,
      path: 'goal-comp',
      progress: 1.0,
      xpTarget: 1200,
      versionHlc: testHlc,
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now,
    );

    // 5. Paused Goal
    final pausedGoal = Goal(
      id: 'goal-paused',
      ownerId: 'usr-1',
      parentId: 'root-1',
      rootId: 'root-1',
      title: 'Deploy Secondary Edge Worker Cluster',
      description: 'Paused pending Cloudflare DNS authorization.',
      status: 'paused',
      depth: 1,
      path: 'root-1/goal-paused',
      progress: 0.20,
      xpTarget: 500,
      versionHlc: testHlc,
      createdAt: now.subtract(const Duration(days: 10)),
      updatedAt: now,
    );

    // 6. Stopped Goal
    final stoppedGoal = Goal(
      id: 'goal-stopped',
      ownerId: 'usr-1',
      parentId: 'root-1',
      rootId: 'root-1',
      title: 'Deprecated Legacy REST Sync Adapter',
      description: 'Replaced by bidirectional transactional outbox pattern.',
      status: 'stopped',
      depth: 1,
      path: 'root-1/goal-stopped',
      progress: 0.10,
      xpTarget: 150,
      versionHlc: testHlc,
      createdAt: now.subtract(const Duration(days: 40)),
      updatedAt: now,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
    final limeColor = isDark ? const Color(0xFFEEFF08) : KratosTheme.lightAcidLime;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: limeColor.withValues(alpha: isDark ? 0.12 : 0.10),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: limeColor.withValues(alpha: isDark ? 0.35 : 0.40),
                ),
              ),
              child: Text(
                'WAVE 04',
                style: TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  color: limeColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'GOALS & NESTED FLOW STORYBOOK',
              style: TextStyle(
                fontFamily: 'IBM Plex Mono',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: limeColor,
              size: 20,
            ),
            onPressed: () => KratosThemeController.instance.toggle(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              _buildSectionTitle('1. ROOT / MAIN GOAL (DEPTH 0)'),
              const SizedBox(height: 10),
              GoalCard(
                goal: rootActiveGoal,
                lifeAreaName: 'SYSTEM ARCHITECTURE',
                categoryName: 'CORE INFRASTRUCTURE',
                childGoalsCount: 3,
                linkedTasksCount: 8,
                onTap: () {},
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('2. SUB-GOAL (DEPTH 1 & RECURSIVE HIERARCHY)'),
              const SizedBox(height: 10),
              GoalCard(
                goal: subGoalD1,
                lifeAreaName: 'DESIGN SYSTEM',
                categoryName: 'FRONTEND',
                childGoalsCount: 1,
                linkedTasksCount: 4,
                onTap: () {},
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('3. DEEPLY NESTED SUB-GOAL (DEPTH 2)'),
              const SizedBox(height: 10),
              GoalCard(
                goal: subGoalD2,
                lifeAreaName: 'QUALITY ASSURANCE',
                categoryName: 'TESTING',
                childGoalsCount: 0,
                linkedTasksCount: 2,
                onTap: () {},
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('4. COMPLETED GOAL (100% PROGRESS // EMERALD BADGE)'),
              const SizedBox(height: 10),
              GoalCard(
                goal: completedGoal,
                lifeAreaName: 'DATABASE',
                categoryName: 'STORAGE',
                childGoalsCount: 0,
                linkedTasksCount: 12,
                onTap: () {},
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('5. PAUSED & STOPPED GOAL STATES'),
              const SizedBox(height: 10),
              GoalCard(
                goal: pausedGoal,
                lifeAreaName: 'DEVOPS',
                categoryName: 'DEPLOYMENT',
                childGoalsCount: 0,
                linkedTasksCount: 1,
                onTap: () {},
              ),
              const SizedBox(height: 10),
              GoalCard(
                goal: stoppedGoal,
                lifeAreaName: 'NETWORKING',
                categoryName: 'INTEGRATION',
                childGoalsCount: 0,
                linkedTasksCount: 0,
                onTap: () {},
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('6. ZERO INTENT / EMPTY STATE'),
              const SizedBox(height: 10),
              Center(
                child: KratosGlassCard(
                  variant: KratosSurfaceVariant.normal,
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.all(28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: limeColor.withValues(alpha: isDark ? 0.08 : 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: limeColor.withValues(alpha: isDark ? 0.25 : 0.35),
                            ),
                          ),
                          child: Icon(
                            Icons.flag_outlined,
                            color: limeColor,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ZERO INTENT DETECTED',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: isDark ? const Color(0xFF686D65) : KratosTheme.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'No Matching Goals Found',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Adjust filters or create a new goal node to begin tracking your strategic progression.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: isDark ? const Color(0xFF979C92) : KratosTheme.lightTextMuted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final limeColor = isDark ? const Color(0xFFEEFF08) : KratosTheme.lightAcidLime;
        final titleColor = isDark ? const Color(0xFF686D65) : KratosTheme.lightTextSecondary;

        return Row(
          children: [
            Container(
              width: 4,
              height: 14,
              decoration: BoxDecoration(
                color: limeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'IBM Plex Mono',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: titleColor,
                letterSpacing: 1.2,
              ),
            ),
          ],
        );
      },
    );
  }
}
