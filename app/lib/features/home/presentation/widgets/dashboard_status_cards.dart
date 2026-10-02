import 'package:flutter/material.dart';

import '../../../../app/kratos_theme.dart';
import '../../../../app/kratos_visuals.dart';
import '../../../../app/kratos_motion.dart';
import '../../../../app/number_pop_in.dart';
import '../../../../data/drift/app_database.dart';
import '../../../notifications/data/notifications_dao.dart';
import '../../../notifications/domain/notification_models.dart';
import '../../../notifications/presentation/notifications_screen.dart';
import '../../../projects/presentation/projects_screen.dart';
import '../../../streaks/domain/streak_models.dart';
import '../../../streaks/presentation/streak_screen.dart';
import '../../domain/home_models.dart';

class DashboardStatusCards extends StatelessWidget {
  final AppDatabase database;
  final String ownerId;
  final HomeWorkSummary summary;
  final StreakInfo streakInfo;
  final void Function(int tabIndex)? onNavigateTab;

  const DashboardStatusCards({
    super.key,
    required this.database,
    required this.ownerId,
    required this.summary,
    required this.streakInfo,
    this.onNavigateTab,
  });

  void _openStreaks(BuildContext context) {
    Navigator.of(context).push(
      KratosPageRoute(
        page: StreakScreen(
          database: database,
          userId: ownerId,
          streakInfo: streakInfo,
        ),
      ),
    );
  }

  void _openProjects(BuildContext context) {
    Navigator.of(context).push(
      KratosPageRoute(
        page: ProjectsScreen(database: database, ownerId: ownerId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        final cards = [
          _StatusCard(
            icon: Icons.checklist,
            label: 'TASKS',
            value: '${summary.activeTasks}',
            detail: '${summary.completedTasks} completed • ${summary.dueTodayTasks} due',
            color: const Color(0xFFC6F135),
            onTap: () => onNavigateTab?.call(1),
          ),
          _StatusCard(
            icon: Icons.track_changes,
            label: 'GOALS',
            value: '${summary.activeGoals}',
            detail: '${summary.completedGoals} completed',
            color: const Color(0xFF00E5FF),
            onTap: () => onNavigateTab?.call(2),
          ),
          _StatusCard(
            icon: Icons.folder_outlined,
            label: 'PROJECTS',
            value: '${summary.activeProjects}',
            detail: '${summary.completedProjects} completed',
            color: const Color(0xFFFF9500),
            onTap: () => _openProjects(context),
          ),
          _StatusCard(
            icon: Icons.local_fire_department,
            label: 'STREAK',
            value: '${streakInfo.currentStreak} DAYS',
            detail: 'Best ${streakInfo.longestStreak} • ${streakInfo.freezeTokensAvailable} freezes',
            color: const Color(0xFFFF5E00),
            onTap: () => _openStreaks(context),
          ),
        ];
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: wide ? 4 : 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 108,
          ),
          itemBuilder: (_, index) => cards[index],
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color color;
  final VoidCallback onTap;

  const _StatusCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white54 : KratosTheme.lightTextSecondary;
    final valueColor = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final detailColor = isDark ? Colors.white54 : KratosTheme.lightTextSecondary;

    return KratosGlassCard(
      dashboardGlass: true,
      accentColor: color,
      borderRadius: BorderRadius.circular(16),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 16),
                    const SizedBox(width: 7),
                    Text(
                      label,
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                KratosNumberPopIn(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: detailColor, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardNotificationsCard extends StatelessWidget {
  final AppDatabase database;
  final String ownerId;

  const DashboardNotificationsCard({super.key, required this.database, required this.ownerId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dao = NotificationsDao(database);
    return StreamBuilder<List<NotificationRecord>>(
      stream: dao.watchNotifications(ownerId),
      builder: (context, snapshot) {
        final records = snapshot.data ?? const <NotificationRecord>[];
        final unread = records.where((record) => !record.isRead).length;
        final latest = records.isEmpty ? null : records.first;
        return KratosGlassCard(
          dashboardGlass: true,
          accentColor: const Color(0xFFFF2D55),
          borderRadius: BorderRadius.circular(18),
          padding: EdgeInsets.zero,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).push(KratosPageRoute(page: NotificationsScreen(database: database, ownerId: ownerId))),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined, color: Color(0xFFFF2D55), size: 19),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        '$unread unread notifications',
                        style: TextStyle(
                          color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        latest?.title ?? 'No important notifications yet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white54 : KratosTheme.lightTextSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ])),
                    Icon(
                      Icons.chevron_right,
                      color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
