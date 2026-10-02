import 'package:flutter/material.dart';

import '../../../../app/kratos_motion.dart';
import '../../../../app/kratos_theme.dart';
import '../../../../app/kratos_visuals.dart';
import '../../../../data/drift/app_database.dart';
import '../../../goals/presentation/goal_detail_screen.dart';
import '../due_today_screen.dart';
import '../../../projects/presentation/projects_screen.dart';
import '../../../tasks/presentation/tasks_screen.dart';
import '../../domain/home_models.dart';

/// Ending Today section with restrained red alert system and breathing glow.
/// Respects prefers-reduced-motion.
class EndingTodaySection extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final List<HomeEndingTodayItem> items;
  final void Function(int tabIndex)? onNavigateTab;

  const EndingTodaySection({
    super.key,
    required this.database,
    required this.ownerId,
    required this.items,
    this.onNavigateTab,
  });

  @override
  State<EndingTodaySection> createState() => _EndingTodaySectionState();
}

class _EndingTodaySectionState extends State<EndingTodaySection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _pulseAnimation = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reducedMotion || widget.items.isEmpty) {
      _pulseController.stop();
    } else if (!_pulseController.isAnimating && !_pulseController.isCompleted) {
      _pulseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _openDueToday() {
    Navigator.of(context).push(
      KratosMaterialPageRoute(
        builder: (_) =>
            DueTodayScreen(database: widget.database, ownerId: widget.ownerId),
      ),
    );
  }

  void _handleItemTap(BuildContext context, HomeEndingTodayItem item) {
    switch (item.type) {
      case EndingTodayType.task:
        if (widget.onNavigateTab != null) {
          widget.onNavigateTab!(1); // Tasks tab
        } else {
          Navigator.of(context).push(
            KratosMaterialPageRoute(
              builder: (_) => TasksScreen(
                database: widget.database,
                ownerId: widget.ownerId,
              ),
            ),
          );
        }
      case EndingTodayType.goal:
        Navigator.of(context).push(
          KratosMaterialPageRoute(
            builder: (_) => GoalDetailScreen(
              database: widget.database,
              ownerId: widget.ownerId,
              goalId: item.id,
            ),
          ),
        );
      case EndingTodayType.project:
        Navigator.of(context).push(
          KratosMaterialPageRoute(
            builder: (_) => ProjectsScreen(
              database: widget.database,
              ownerId: widget.ownerId,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final secondaryTextColor = isDark ? Colors.white54 : KratosTheme.lightTextSecondary;
    final lime = isDark ? const Color(0xFFC6F135) : KratosTheme.lightAcidLime;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFFF3B30),
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'ENDING TODAY',
              style: TextStyle(
                color: primaryTextColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _openDueToday,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                'View all',
                style: TextStyle(
                  color: lime,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (widget.items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0x14000000),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No items ending today • All caught up',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )
        else
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, _) {
              final alpha = reducedMotion ? 0.55 : _pulseAnimation.value;
              const alertRed = Color(0xFFFF3B30);

              return Column(
                children: widget.items.map((item) {
                  final subtitle = item.lifeAreaName != null
                      ? '${item.typeLabel} • ${item.lifeAreaName}'
                      : item.typeLabel;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: KratosGlassCard(
                      dashboardGlass: true,
                      accentColor: alertRed.withValues(alpha: alpha),
                      borderRadius: BorderRadius.circular(18),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _handleItemTap(context, item),
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 15,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: alertRed.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getIconForType(item.type),
                                    color: alertRed,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: primaryTextColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        subtitle,
                                        style: TextStyle(
                                          color: secondaryTextColor,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: alertRed.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: alertRed.withValues(alpha: 0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Text(
                                    'DUE TODAY',
                                    style: TextStyle(
                                      color: alertRed,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  IconData _getIconForType(EndingTodayType type) {
    switch (type) {
      case EndingTodayType.task:
        return Icons.checklist;
      case EndingTodayType.goal:
        return Icons.track_changes;
      case EndingTodayType.project:
        return Icons.folder_outlined;
    }
  }
}
