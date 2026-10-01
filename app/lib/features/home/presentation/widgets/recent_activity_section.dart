import 'package:flutter/material.dart';

import '../../../../app/kratos_motion.dart';

import '../../../../app/kratos_visuals.dart';
import '../../../../data/drift/app_database.dart';
import '../../../goals/presentation/goal_detail_screen.dart';
import '../../../projects/presentation/projects_screen.dart';
import '../../../tasks/presentation/tasks_screen.dart';
import '../../../notifications/presentation/notifications_screen.dart';
import '../../domain/home_models.dart';

/// Formats a past DateTime into relative human-readable strings like "12 minutes ago".
String formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inSeconds < 60) {
    return 'Just now';
  } else if (difference.inMinutes < 60) {
    final mins = difference.inMinutes;
    return '$mins ${mins == 1 ? "minute" : "minutes"} ago';
  } else if (difference.inHours < 24) {
    final hours = difference.inHours;
    return '$hours ${hours == 1 ? "hour" : "hours"} ago';
  } else if (difference.inDays == 1) {
    return 'Yesterday';
  } else if (difference.inDays < 7) {
    return '${difference.inDays} days ago';
  } else {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, "0")}-${dateTime.day.toString().padLeft(2, "0")}';
  }
}

class RecentActivitySection extends StatelessWidget {
  final AppDatabase database;
  final String ownerId;
  final List<HomeRecentItem> items;
  final void Function(int tabIndex)? onNavigateTab;

  const RecentActivitySection({
    super.key,
    required this.database,
    required this.ownerId,
    required this.items,
    this.onNavigateTab,
  });

  void _handleItemTap(BuildContext context, HomeRecentItem item) {
    switch (item.type) {
      case HomeRecentType.task:
        if (onNavigateTab != null) {
          onNavigateTab!(1); // Tasks tab
        } else {
          Navigator.of(context).push(
            KratosMaterialPageRoute(
              builder: (_) => TasksScreen(database: database, ownerId: ownerId),
            ),
          );
        }
      case HomeRecentType.goal:
        Navigator.of(context).push(
          KratosMaterialPageRoute(
            builder: (_) => GoalDetailScreen(
              database: database,
              ownerId: ownerId,
              goalId: item.id,
            ),
          ),
        );
      case HomeRecentType.project:
        Navigator.of(context).push(
          KratosMaterialPageRoute(
            builder: (_) =>
                ProjectsScreen(database: database, ownerId: ownerId),
          ),
        );
      case HomeRecentType.session:
        if (onNavigateTab != null) {
          onNavigateTab!(3); // Activities tab
        }
      case HomeRecentType.activityEvent:
        Navigator.of(context).push(
          KratosMaterialPageRoute(
            builder: (_) => NotificationsScreen(
              database: database,
              ownerId: ownerId,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show top 8 items across systems for a concise recent snapshot
    final displayItems = items.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        const Row(
          children: [
            Icon(Icons.history, color: Colors.white54, size: 16),
            SizedBox(width: 8),
            Text(
              'RECENT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (displayItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: const Row(
              children: [
                Icon(Icons.hourglass_empty, color: Colors.white38, size: 18),
                SizedBox(width: 12),
                Text(
                  'No recent actions logged yet',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          )
        else
          KratosGlassCard(
            dashboardGlass: true,
            borderRadius: BorderRadius.circular(20),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayItems.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: Colors.white10, height: 1, indent: 52),
              itemBuilder: (context, index) {
                final item = displayItems[index];
                final relativeTime = formatRelativeTime(item.timestamp);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleItemTap(context, item),
                    borderRadius: BorderRadius.vertical(
                      top: index == 0 ? const Radius.circular(20) : Radius.zero,
                      bottom: index == displayItems.length - 1
                          ? const Radius.circular(20)
                          : Radius.zero,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getIconColor(item)
                                  .withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getIcon(item),
                              color: _getIconColor(item),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            relativeTime,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  IconData _getIcon(HomeRecentItem item) {
    if (item.isCompleted) return Icons.check_circle;
    switch (item.type) {
      case HomeRecentType.task:
        return Icons.checklist;
      case HomeRecentType.goal:
        return Icons.track_changes;
      case HomeRecentType.project:
        return Icons.folder_outlined;
      case HomeRecentType.session:
        return Icons.timer_outlined;
      case HomeRecentType.activityEvent:
        return Icons.bolt;
    }
  }

  Color _getIconColor(HomeRecentItem item) {
    if (item.isCompleted) return const Color(0xFFC6F135);
    switch (item.type) {
      case HomeRecentType.task:
        return const Color(0xFFC6F135);
      case HomeRecentType.goal:
        return const Color(0xFF00E5FF);
      case HomeRecentType.project:
        return const Color(0xFFFF9500);
      case HomeRecentType.session:
        return const Color(0xFFFF2D55);
      case HomeRecentType.activityEvent:
        return const Color(0xFFB56CFF);
    }
  }
}
