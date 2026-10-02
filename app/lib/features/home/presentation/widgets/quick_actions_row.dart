import 'package:flutter/material.dart';

import '../../../../app/kratos_theme.dart';
import '../../../../app/kratos_visuals.dart';
import '../../../../app/kratos_motion.dart';
import '../../../../data/drift/app_database.dart';
import '../../../activities/presentation/create_activity_dialog.dart';
import '../../../goals/presentation/dialogs/create_goal_dialog.dart';
import '../../../tasks/presentation/create_task_dialog.dart';
import '../dialogs/quick_capture_dialog.dart';

/// Quick Action cards for Home Command Center.
/// Actions:
/// 1. New Task
/// 2. New Goal
/// 3. New Activity
/// 4. Capture
/// (DO NOT include New Project)
class QuickActionsRow extends StatelessWidget {
  final AppDatabase database;
  final String ownerId;
  final VoidCallback? onActionCompleted;

  const QuickActionsRow({
    super.key,
    required this.database,
    required this.ownerId,
    this.onActionCompleted,
  });

  void _openNewTask(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => CreateTaskDialog(
        database: database,
        ownerId: ownerId,
        onCreated: onActionCompleted,
      ),
    );
  }

  void _openNewGoal(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => CreateGoalDialog(
        database: database,
        ownerId: ownerId,
        onGoalCreated: (_) => onActionCompleted?.call(),
      ),
    );
  }

  void _openNewActivity(BuildContext context) {
    CreateActivityDialog.show(
      context,
      database: database,
      ownerId: ownerId,
    ).then((_) => onActionCompleted?.call());
  }

  void _openCapture(BuildContext context) {
    QuickCaptureDialog.show(context, database: database, ownerId: ownerId);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;

        if (isWide) {
          return Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.add_task,
                  label: 'New Task',
                  onTap: () => _openNewTask(context),
                  accentColor: const Color(0xFFC6F135),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.track_changes,
                  label: 'New Goal',
                  onTap: () => _openNewGoal(context),
                  accentColor: const Color(0xFF00E5FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.repeat,
                  label: 'New Activity',
                  onTap: () => _openNewActivity(context),
                  accentColor: const Color(0xFFFF9500),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.bolt,
                  label: 'Capture',
                  onTap: () => _openCapture(context),
                  accentColor: const Color(0xFFFF2D55),
                ),
              ),
            ],
          );
        }

        // Mobile 2x2 grid
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.add_task,
                    label: 'New Task',
                    onTap: () => _openNewTask(context),
                    accentColor: const Color(0xFFC6F135),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.track_changes,
                    label: 'New Goal',
                    onTap: () => _openNewGoal(context),
                    accentColor: const Color(0xFF00E5FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.repeat,
                    label: 'New Activity',
                    onTap: () => _openNewActivity(context),
                    accentColor: const Color(0xFFFF9500),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.bolt,
                    label: 'Capture',
                    onTap: () => _openCapture(context),
                    accentColor: const Color(0xFFFF2D55),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accentColor;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return KratosPressable(
      onTap: onTap,
      child: KratosGlassCard(
        dashboardGlass: true,
        accentColor: accentColor,
        borderRadius: BorderRadius.circular(16),
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
