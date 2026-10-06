import 'package:flutter/material.dart';

import '../../../app/kratos_theme.dart';
import '../../../app/kratos_theme_controller.dart';
import '../../../app/kratos_visuals.dart';
import '../notifications/domain/notification_models.dart';
import '../notifications/domain/notification_service.dart';

/// Wave 11 Storybook / Widget Previews Showcase.
/// Renders every existing Notification / Timeline variant and state in KRATOS:
/// 1. Overdue Alert (Crimson rim & accent strip, Action Open Task)
/// 2. Due Today Alert (Acid Lime rim & accent, Action Open Goal)
/// 3. Paused > 7 Days Alert (Amber warning accent, Action Open Project)
/// 4. Level Up Alert (Cyan accent, Level progression milestone)
/// 5. Weekly Bonus / Milestone Alert (Purple accent, Freeze token unlock)
/// 6. Streak Extension Alert (Flame orange accent, Daily streak maintained)
/// 7. Read vs Unread Visual Distinction (Restrained surface & opacity hierarchy)
/// 8. Metrics Summary Strip (OVERDUE, DUE TODAY, PAUSED, EVENTS badges)
/// 9. System Notification Banner (Device push / permission request banner)
/// 10. Filter Chips (All, Overdue, Due Today, Paused, Events)
/// 11. Activity Timeline Nodes (Level up, Achievement, Goal completed, XP earned)
/// 12. Empty States (All Clear notification state & Timeline idle state)
class Wave11NotificationsStorybookScreen extends StatelessWidget {
  const Wave11NotificationsStorybookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final overdueAlert = KratosNotification(
      id: 'alert-overdue-1',
      kind: NotificationKind.overdue,
      title: 'Task Overdue: Complete CRDT Integration Test Suite',
      body: 'Scheduled completion deadline was 18 hours ago. Target project: KRATOS Core.',
      targetType: 'task',
      targetId: 'task-101',
      severity: NotificationSeverity.urgent,
      timestamp: now.subtract(const Duration(hours: 18)),
      isRead: false,
    );

    final dueTodayAlert = KratosNotification(
      id: 'alert-today-1',
      kind: NotificationKind.endingToday,
      title: 'Goal Target Ending Today: Liquid Glass Polish',
      body: 'Verify specular depth and 0 layout overflow across Mobile & Desktop viewports.',
      targetType: 'goal',
      targetId: 'goal-202',
      severity: NotificationSeverity.warning,
      timestamp: now.subtract(const Duration(hours: 2)),
      isRead: false,
    );

    final pausedAlert = KratosNotification(
      id: 'alert-paused-1',
      kind: NotificationKind.stalePaused,
      title: 'Project Inactive: Cloudflare Edge Worker Cluster',
      body: 'Project has remained in paused status for 9 consecutive days without activity.',
      targetType: 'project',
      targetId: 'proj-303',
      severity: NotificationSeverity.info,
      timestamp: now.subtract(const Duration(days: 9)),
      isRead: false,
    );

    final levelAlert = KratosNotification(
      id: 'alert-level-1',
      kind: NotificationKind.levelPromoted,
      title: 'Progression Threshold Achieved: Level 14',
      body: 'Your total XP crossed 4,760 XP. New identity rank unlocked.',
      severity: NotificationSeverity.info,
      timestamp: now.subtract(const Duration(minutes: 45)),
      isRead: false,
    );

    final bonusAlert = KratosNotification(
      id: 'alert-bonus-1',
      kind: NotificationKind.weeklyBonusUnlocked,
      title: 'Weekly Alignment Bonus Unlocked',
      body: 'Consistent daily focus rewarded with +350 XP bonus points and 1 Freeze Token.',
      severity: NotificationSeverity.info,
      timestamp: now.subtract(const Duration(days: 1)),
      isRead: true, // Read state demo
    );

    final streakAlert = KratosNotification(
      id: 'alert-streak-1',
      kind: NotificationKind.streakReminder,
      title: 'Daily Streak Maintained: 12 Days Active',
      body: 'Continue momentum by logging at least one focus session before midnight.',
      severity: NotificationSeverity.info,
      timestamp: now.subtract(const Duration(days: 2)),
      isRead: true, // Read state demo
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
    final mutedTextColor = isDark ? const Color(0xFF686D65) : KratosTheme.lightTextSecondary;
    final limeColor = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;

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
                'WAVE 11',
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
              'NOTIFICATIONS + INBOX SHOWCASE',
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
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Section 1: System Banner & Permission
          _buildSectionHeader('01 / SYSTEM NOTIFICATION BANNER', mutedTextColor),
          const SizedBox(height: 10),
          KratosGlassCard(
            variant: KratosSurfaceVariant.elevated,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: const Color(0xFFFF9500),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enable Device System Alerts',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          color: primaryTextColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Get native alerts when deadlines approach or milestones occur.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: mutedTextColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: limeColor,
                    foregroundColor: isDark ? const Color(0xFF020302) : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Enable',
                    style: TextStyle(fontFamily: 'IBM Plex Mono', fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: Metrics Summary Strip
          _buildSectionHeader('02 / METRICS SUMMARY (4-SLOT GAUGES)', mutedTextColor),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildMetricGauge('OVERDUE', 2, const Color(0xFFFF3B30), isDark, mutedTextColor),
              const SizedBox(width: 8),
              _buildMetricGauge('DUE TODAY', 4, limeColor, isDark, mutedTextColor),
              const SizedBox(width: 8),
              _buildMetricGauge('PAUSED', 1, const Color(0xFFFF9500), isDark, mutedTextColor),
              const SizedBox(width: 8),
              _buildMetricGauge('EVENTS', 5, const Color(0xFF00BCD4), isDark, mutedTextColor),
            ],
          ),
          const SizedBox(height: 24),

          // Section 3: Filter Chips Strip
          _buildSectionHeader('03 / FILTER STRIP (MONO CHIPS)', mutedTextColor),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDemoChip('All (12)', isSelected: true, activeColor: limeColor, isDark: isDark, mutedText: mutedTextColor),
                const SizedBox(width: 8),
                _buildDemoChip('Overdue (2)', isSelected: false, activeColor: const Color(0xFFFF3B30), isDark: isDark, mutedText: mutedTextColor),
                const SizedBox(width: 8),
                _buildDemoChip('Due Today (4)', isSelected: false, activeColor: limeColor, isDark: isDark, mutedText: mutedTextColor),
                const SizedBox(width: 8),
                _buildDemoChip('Paused (1)', isSelected: false, activeColor: const Color(0xFFFF9500), isDark: isDark, mutedText: mutedTextColor),
                const SizedBox(width: 8),
                _buildDemoChip('Events (5)', isSelected: false, activeColor: const Color(0xFF00BCD4), isDark: isDark, mutedText: mutedTextColor),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 4: Unread Alerts
          _buildSectionHeader('04 / UNREAD NOTIFICATION CARDS (HIGH SALIENCE)', mutedTextColor),
          const SizedBox(height: 10),
          _buildAlertPreview(overdueAlert, const Color(0xFFFF3B30), Icons.warning_amber_rounded, 'OVERDUE', isDark, limeColor, primaryTextColor, mutedTextColor),
          const SizedBox(height: 10),
          _buildAlertPreview(dueTodayAlert, limeColor, Icons.hourglass_bottom_rounded, 'DUE TODAY', isDark, limeColor, primaryTextColor, mutedTextColor),
          const SizedBox(height: 10),
          _buildAlertPreview(pausedAlert, const Color(0xFFFF9500), Icons.pause_circle_filled_rounded, 'PAUSED > 7 DAYS', isDark, limeColor, primaryTextColor, mutedTextColor),
          const SizedBox(height: 10),
          _buildAlertPreview(levelAlert, const Color(0xFF00BCD4), Icons.arrow_circle_up_rounded, 'LEVEL UP', isDark, limeColor, primaryTextColor, mutedTextColor),
          const SizedBox(height: 24),

          // Section 5: Read Alerts (Low Salience)
          _buildSectionHeader('05 / READ NOTIFICATION CARDS (QUIET HIERARCHY)', mutedTextColor),
          const SizedBox(height: 10),
          _buildAlertPreview(bonusAlert, const Color(0xFFBD00FF), Icons.military_tech_rounded, 'BONUS / MILESTONE', isDark, limeColor, primaryTextColor, mutedTextColor),
          const SizedBox(height: 10),
          _buildAlertPreview(streakAlert, const Color(0xFFFF5E00), Icons.local_fire_department_rounded, 'STREAK', isDark, limeColor, primaryTextColor, mutedTextColor),
          const SizedBox(height: 24),

          // Section 6: Activity Timeline Nodes
          _buildSectionHeader('06 / ACTIVITY TIMELINE STREAM', mutedTextColor),
          const SizedBox(height: 10),
          _buildTimelineNodePreview('LEVEL UP: REACHED LEVEL 14', 'Progression threshold achieved via consistent action.', const Color(0xFF00BCD4), Icons.arrow_circle_up_rounded, 'LEVEL UP', isLast: false, isDark: isDark, primaryText: primaryTextColor, mutedText: mutedTextColor),
          _buildTimelineNodePreview('+250 XP EARNED (FOCUS SESSION)', 'Attributed to Health & Vitality ledger.', limeColor, Icons.bolt_rounded, 'XP EARNED', isLast: false, isDark: isDark, primaryText: primaryTextColor, mutedText: mutedTextColor),
          _buildTimelineNodePreview('GOAL COMPLETED: LIQUID GLASS SYSTEM', '+30% bonus points awarded for tree completion.', const Color(0xFFBD00FF), Icons.flag_rounded, 'GOAL COMPLETED', isLast: false, isDark: isDark, primaryText: primaryTextColor, mutedText: mutedTextColor),
          _buildTimelineNodePreview('PROJECT COMPLETED: LOCAL DRIFT SCHEMAS', 'All phases delivered and validated.', const Color(0xFF388BFD), Icons.layers_rounded, 'PROJECT COMPLETED', isLast: true, isDark: isDark, primaryText: primaryTextColor, mutedText: mutedTextColor),
          const SizedBox(height: 24),

          // Section 7: Empty States
          _buildSectionHeader('07 / ZERO STATE / EMPTY NOTIFICATIONS', mutedTextColor),
          const SizedBox(height: 10),
          const KratosEmptyState(
            icon: Icons.done_all_rounded,
            eyebrow: 'NOTIFICATIONS / CLEAR',
            title: 'All Clear',
            message: 'No pending alerts, overdue tasks, or stale items.',
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('08 / ZERO STATE / TIMELINE IDLE', mutedTextColor),
          const SizedBox(height: 10),
          const KratosEmptyState(
            icon: Icons.timeline_rounded,
            eyebrow: 'TIMELINE / IDLE',
            title: 'No Activity Recorded Yet',
            message: 'Complete tasks, log focus sessions, and earn XP to build your timeline.',
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color mutedText) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'IBM Plex Mono',
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: mutedText,
        letterSpacing: 1.4,
      ),
    );
  }

  Widget _buildMetricGauge(String label, int count, Color color, bool isDark, Color mutedText) {
    return Expanded(
      child: KratosGlassCard(
        variant: count > 0 ? KratosSurfaceVariant.elevated : KratosSurfaceVariant.normal,
        padding: const EdgeInsets.symmetric(vertical: 8),
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontFamily: 'IBM Plex Mono',
                color: count > 0 ? color : mutedText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'IBM Plex Mono',
                color: count > 0 ? color.withValues(alpha: 0.85) : mutedText.withValues(alpha: 0.7),
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoChip(
    String label, {
    required bool isSelected,
    required Color activeColor,
    required bool isDark,
    required Color mutedText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isSelected
            ? activeColor.withValues(alpha: isDark ? 0.15 : 0.12)
            : (isDark ? const Color(0x66050505) : const Color(0x66E7ECE4)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? activeColor
              : (isDark ? Colors.white.withValues(alpha: 0.10) : KratosTheme.lightBorderGlass),
          width: isSelected ? 1.4 : 1.0,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'IBM Plex Mono',
          color: isSelected ? activeColor : mutedText,
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAlertPreview(
    KratosNotification alert,
    Color accentColor,
    IconData iconData,
    String typeLabel,
    bool isDark,
    Color acidLime,
    Color primaryText,
    Color mutedText,
  ) {
    return KratosGlassCard(
      variant: alert.isRead ? KratosSurfaceVariant.normal : KratosSurfaceVariant.active,
      accentColor: alert.isRead ? null : accentColor,
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              bottom: 0,
              width: 4,
              child: Container(color: accentColor),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(iconData, size: 10, color: accentColor),
                            const SizedBox(width: 4),
                            Text(
                              typeLabel,
                              style: TextStyle(
                                fontFamily: 'IBM Plex Mono',
                                color: accentColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '2h ago',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: mutedText,
                          fontSize: 10,
                        ),
                      ),
                      const Spacer(),
                      if (!alert.isRead)
                        Icon(Icons.check_circle_outline, size: 16, color: acidLime),
                      const SizedBox(width: 10),
                      Icon(Icons.close, size: 16, color: mutedText),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    alert.title,
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      color: primaryText,
                      fontSize: 13,
                      fontWeight: alert.isRead ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.body,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: mutedText,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  if (alert.targetType != null && alert.targetType!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Open ${alert.targetType!.toUpperCase()}',
                              style: TextStyle(
                                fontFamily: 'IBM Plex Mono',
                                color: accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 12, color: accentColor),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineNodePreview(
    String title,
    String subtitle,
    Color accentColor,
    IconData iconData,
    String typeTag, {
    required bool isLast,
    required bool isDark,
    required Color primaryText,
    required Color mutedText,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0D100E) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: accentColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: isDark ? 0.35 : 0.20),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(iconData, size: 10, color: accentColor),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDark ? Colors.white12 : const Color(0x1F0F172A),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: KratosGlassCard(
                variant: KratosSurfaceVariant.normal,
                padding: const EdgeInsets.all(12),
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            typeTag,
                            style: TextStyle(
                              fontFamily: 'IBM Plex Mono',
                              color: accentColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Text(
                          'Just now',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            color: mutedText,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        color: primaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: mutedText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
