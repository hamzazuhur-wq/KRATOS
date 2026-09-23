// Wave 18: AppShell — Main Navigation & Shell Architecture.
// Unites all KRATOS modules into a futuristic Liquid Glass navigation experience.

import 'package:flutter/material.dart';
import '../../domain/ids.dart';
import '../features/activities/presentation/activities_screen.dart';
import '../features/attachments/presentation/evidence_hub_screen.dart';
import '../features/notes/presentation/ai_notes_screen.dart';
import '../features/progression/presentation/progression_settings_screen.dart';
import '../features/projects/presentation/projects_screen.dart';
import '../features/sessions/presentation/session_timer_screen.dart';
import '../features/skills/presentation/skills_registry_screen.dart';
import '../features/streaks/domain/streak_models.dart';
import '../features/streaks/presentation/streak_badge_widget.dart';
import '../features/sync/domain/sync_models.dart';
import '../features/sync/presentation/sync_status_badge.dart';
import '../features/tasks/presentation/tasks_placeholder_screen.dart';
import '../features/tools/presentation/tools_registry_screen.dart';
import '../features/xp/presentation/xp_dashboard_screen.dart';

class AppShell extends StatefulWidget {
  final VoidCallback? onSignOut;

  const AppShell({super.key, this.onSignOut});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  // Mock header telemetry for seamless UI demonstration
  final _mockStreak = StreakInfo.create(
    userId: const Id('usr_seed_dev_01'),
    lifeAreaId: const Id('la_health'),
    currentStreak: 12,
    longestStreak: 28,
    freezeTokensAvailable: 2,
  );

  final List<Widget> _tabs = [
    const XpDashboardScreen(),
    const ProjectsScreen(),
    const SessionTimerScreen(contextLabel: 'Deep Work Block', estimatedXp: 150),
    const SkillsRegistryScreen(),
    const AiNotesScreen(),
    const ProgressionSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.bolt, color: Color(0xFFC6F135), size: 24),
            const SizedBox(width: 8),
            const Text(
              'KRATOS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            StreakBadgeWidget(streakInfo: _mockStreak),
            const SizedBox(width: 10),
            const SyncStatusBadge(state: SyncConnectionState.online),
          ],
        ),
        actions: [
          if (widget.onSignOut != null)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white38, size: 20),
              tooltip: 'Sign Out',
              onPressed: widget.onSignOut,
            ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141414).withValues(alpha: 0.95),
          border: const Border(
            top: BorderSide(color: Colors.white12, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFC6F135),
          unselectedItemColor: Colors.white38,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'XP',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.task_alt_outlined),
              activeIcon: Icon(Icons.task_alt),
              label: 'Projects',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.timer_outlined),
              activeIcon: Icon(Icons.timer),
              label: 'Focus',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.psychology_outlined),
              activeIcon: Icon(Icons.psychology),
              label: 'Skills',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.note_alt_outlined),
              activeIcon: Icon(Icons.note_alt),
              label: 'Notes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tune_outlined),
              activeIcon: Icon(Icons.tune),
              label: 'Tiers',
            ),
          ],
        ),
      ),
    );
  }
}
