// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'package:flutter/material.dart';

import '../../../app/kratos_motion.dart';
import '../../../app/kratos_theme.dart';
import '../../../app/kratos_visuals.dart';
import '../../../data/drift/app_database.dart';
import '../../activities/data/activity_timeline_repository.dart';
import '../../goals/presentation/goal_detail_screen.dart';
import '../../projects/presentation/projects_screen.dart';
import '../../tasks/presentation/tasks_screen.dart';
import '../domain/notification_service.dart';
import '../domain/system_notification_bridge.dart';

class NotificationsScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;

  const NotificationsScreen({
    super.key,
    required this.database,
    required this.ownerId,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = NotificationService();
  late final ActivityTimelineRepository _timelineRepo;

  int _selectedTab = 0; // 0: Notifications, 1: Activity Timeline
  String _selectedFilter = 'all'; // 'all', 'overdue', 'ending_today', 'paused', 'event'
  String _timelineFilter = 'all'; // 'all', 'level_up', 'goal_completed', 'project_completed', 'streak_extended', 'xp_earned'
  bool _loading = false;
  String _systemPermission = 'default';

  @override
  void initState() {
    super.initState();
    _timelineRepo = ActivityTimelineRepository(database: widget.database);
    _checkSystemPermission();
    _refreshAlerts();
  }

  void _checkSystemPermission() {
    setState(() {
      _systemPermission = SystemNotificationBridge.instance.getPermission();
    });
  }

  Future<void> _requestSystemPermission() async {
    final res = await SystemNotificationBridge.instance.requestPermission();
    setState(() {
      _systemPermission = res;
    });
    if (res == 'granted') {
      SystemNotificationBridge.instance.showNotification(
        'KRATOS Alerts Enabled',
        'Device notifications are now active for deadlines, achievements, and level-ups.',
      );
      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isDark ? const Color(0xFF141714) : const Color(0xFFE7ECE4),
            content: Text(
              '✅ Device system notifications enabled!',
              style: TextStyle(
                color: isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _refreshAlerts() async {
    setState(() => _loading = true);
    await _service.scanAllAlerts(
      db: widget.database,
      ownerId: widget.ownerId,
      dispatchSystem: true,
    );
    if (mounted) setState(() => _loading = false);
  }

  void _navigateToTarget(KratosNotification alert) {
    _service.markAsRead(alert.id, db: widget.database);
    if (alert.targetType == 'task') {
      Navigator.of(context).push(
        KratosMaterialPageRoute(
          builder: (_) => TasksScreen(database: widget.database, ownerId: widget.ownerId),
        ),
      );
    } else if (alert.targetType == 'goal' && alert.targetId != null) {
      Navigator.of(context).push(
        KratosMaterialPageRoute(
          builder: (_) => GoalDetailScreen(
            database: widget.database,
            ownerId: widget.ownerId,
            goalId: alert.targetId!,
          ),
        ),
      );
    } else if (alert.targetType == 'project') {
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final acidLime = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
    final primaryText = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
    final mutedText = isDark ? const Color(0xFF686D65) : KratosTheme.lightTextSecondary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: mutedText,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: acidLime,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'NOTIFICATIONS & TIMELINE',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                color: primaryText,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                fontSize: 15,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _loading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: acidLime,
                    ),
                  )
                : Icon(Icons.refresh, color: mutedText, size: 20),
            tooltip: 'Refresh Notifications & Timeline',
            onPressed: _loading ? null : _refreshAlerts,
          ),
          if (_selectedTab == 0)
            IconButton(
              icon: Icon(
                Icons.done_all,
                color: acidLime,
                size: 20,
              ),
              tooltip: 'Mark All as Read',
              onPressed: () {
                _service.markAllAsRead(db: widget.database, ownerId: widget.ownerId);
                setState(() {});
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<KratosNotification>>(
        stream: _service.notificationsStream,
        initialData: _service.currentNotifications,
        builder: (context, snapshot) {
          final alerts = snapshot.data ?? [];
          final unreadCount = alerts.where((a) => !a.isRead && !a.isDismissed).length;

          return Column(
            children: [
              _buildTabSwitcher(unreadCount, isDark, acidLime, primaryText, mutedText),
              Expanded(
                child: _selectedTab == 0
                    ? _buildNotificationsTab(alerts, isDark, acidLime, primaryText, mutedText)
                    : _buildActivityTimelineTab(isDark, acidLime, primaryText, mutedText),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabSwitcher(
    int unreadCount,
    bool isDark,
    Color acidLime,
    Color primaryText,
    Color mutedText,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x99050505) : const Color(0xF0E7ECE4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.10) : KratosTheme.lightBorderGlass,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTab == 0
                      ? (isDark ? const Color(0xFF161F16) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: _selectedTab == 0
                      ? Border.all(color: acidLime.withValues(alpha: isDark ? 0.35 : 0.45))
                      : null,
                  boxShadow: _selectedTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'NOTIFICATIONS',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: _selectedTab == 0 ? acidLime : mutedText,
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTab == 1
                      ? (isDark ? const Color(0xFF161F16) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: _selectedTab == 1
                      ? Border.all(color: acidLime.withValues(alpha: isDark ? 0.35 : 0.45))
                      : null,
                  boxShadow: _selectedTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'ACTIVITY TIMELINE',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: _selectedTab == 1 ? acidLime : mutedText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab(
    List<KratosNotification> alerts,
    bool isDark,
    Color acidLime,
    Color primaryText,
    Color mutedText,
  ) {
    final overdueCount = alerts.where((a) => a.kind == NotificationKind.overdue).length;
    final todayCount = alerts.where((a) => a.kind == NotificationKind.endingToday).length;
    final pausedCount = alerts.where((a) => a.kind == NotificationKind.stalePaused).length;
    final eventsCount = alerts
        .where((a) =>
            a.kind == NotificationKind.levelPromoted ||
            a.kind == NotificationKind.weeklyBonusUnlocked ||
            a.kind == NotificationKind.streakReminder)
        .length;

    final filtered = alerts.where((a) {
      if (_selectedFilter == 'overdue') return a.kind == NotificationKind.overdue;
      if (_selectedFilter == 'ending_today') return a.kind == NotificationKind.endingToday;
      if (_selectedFilter == 'paused') return a.kind == NotificationKind.stalePaused;
      if (_selectedFilter == 'event') {
        return a.kind == NotificationKind.levelPromoted ||
            a.kind == NotificationKind.weeklyBonusUnlocked ||
            a.kind == NotificationKind.streakReminder;
      }
      return true;
    }).toList();

    return Column(
      children: [
        _buildSystemPermissionBanner(isDark, acidLime, primaryText, mutedText),
        _buildMetricsSummary(overdueCount, todayCount, pausedCount, eventsCount, isDark, primaryText, mutedText),
        _buildFilterChips(alerts.length, overdueCount, todayCount, pausedCount, eventsCount, isDark, acidLime, mutedText),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(isDark, acidLime, primaryText, mutedText)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) => _buildAlertCard(filtered[idx], isDark, acidLime, primaryText, mutedText),
                ),
        ),
      ],
    );
  }

  Widget _buildSystemPermissionBanner(
    bool isDark,
    Color acidLime,
    Color primaryText,
    Color mutedText,
  ) {
    final isGranted = _systemPermission == 'granted';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: KratosGlassCard(
        variant: isGranted ? KratosSurfaceVariant.normal : KratosSurfaceVariant.elevated,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              isGranted ? Icons.check_circle_outline : Icons.notifications_active_outlined,
              color: isGranted ? acidLime : const Color(0xFFFF9500),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isGranted ? 'Device Notifications Active' : 'Enable Device System Alerts',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      color: isGranted ? acidLime : primaryText,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isGranted
                        ? 'System popups will alert you on Windows / Android.'
                        : 'Get native alerts when deadlines approach or milestones occur.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: mutedText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (!isGranted)
              ElevatedButton(
                onPressed: _requestSystemPermission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: acidLime,
                  foregroundColor: isDark ? const Color(0xFF020302) : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    );
  }

  Widget _buildMetricsSummary(
    int overdue,
    int today,
    int paused,
    int events,
    bool isDark,
    Color primaryText,
    Color mutedText,
  ) {
    final dueTodayColor = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Row(
        children: [
          _buildMetricBadge('OVERDUE', overdue, const Color(0xFFFF3B30), isDark, primaryText, mutedText),
          const SizedBox(width: 8),
          _buildMetricBadge('DUE TODAY', today, dueTodayColor, isDark, primaryText, mutedText),
          const SizedBox(width: 8),
          _buildMetricBadge('PAUSED', paused, const Color(0xFFFF9500), isDark, primaryText, mutedText),
          const SizedBox(width: 8),
          _buildMetricBadge('EVENTS', events, const Color(0xFF00BCD4), isDark, primaryText, mutedText),
        ],
      ),
    );
  }

  Widget _buildMetricBadge(
    String label,
    int count,
    Color color,
    bool isDark,
    Color primaryText,
    Color mutedText,
  ) {
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

  Widget _buildFilterChips(
    int total,
    int overdue,
    int today,
    int paused,
    int events,
    bool isDark,
    Color acidLime,
    Color mutedText,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _buildChip('all', 'All ($total)', isDark: isDark, defaultActiveColor: acidLime, mutedText: mutedText),
          const SizedBox(width: 8),
          _buildChip('overdue', 'Overdue ($overdue)', activeColor: const Color(0xFFFF3B30), isDark: isDark, defaultActiveColor: acidLime, mutedText: mutedText),
          const SizedBox(width: 8),
          _buildChip('ending_today', 'Due Today ($today)', activeColor: acidLime, isDark: isDark, defaultActiveColor: acidLime, mutedText: mutedText),
          const SizedBox(width: 8),
          _buildChip('paused', 'Paused ($paused)', activeColor: const Color(0xFFFF9500), isDark: isDark, defaultActiveColor: acidLime, mutedText: mutedText),
          const SizedBox(width: 8),
          _buildChip('event', 'Events ($events)', activeColor: const Color(0xFF00BCD4), isDark: isDark, defaultActiveColor: acidLime, mutedText: mutedText),
        ],
      ),
    );
  }

  Widget _buildChip(
    String filterId,
    String label, {
    Color? activeColor,
    required bool isDark,
    required Color defaultActiveColor,
    required Color mutedText,
  }) {
    final effectiveActiveColor = activeColor ?? defaultActiveColor;
    final isSelected = _selectedFilter == filterId;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterId),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? effectiveActiveColor.withValues(alpha: isDark ? 0.15 : 0.12)
              : (isDark ? const Color(0x66050505) : const Color(0x66E7ECE4)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? effectiveActiveColor
                : (isDark ? Colors.white.withValues(alpha: 0.10) : KratosTheme.lightBorderGlass),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'IBM Plex Mono',
            color: isSelected ? effectiveActiveColor : mutedText,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(
    KratosNotification alert,
    bool isDark,
    Color acidLime,
    Color primaryText,
    Color mutedText,
  ) {
    Color accentColor;
    IconData iconData;
    String typeLabel;

    switch (alert.kind) {
      case NotificationKind.overdue:
        accentColor = const Color(0xFFFF3B30);
        iconData = Icons.warning_amber_rounded;
        typeLabel = 'OVERDUE';
        break;
      case NotificationKind.endingToday:
        accentColor = acidLime;
        iconData = Icons.hourglass_bottom_rounded;
        typeLabel = 'DUE TODAY';
        break;
      case NotificationKind.stalePaused:
        accentColor = const Color(0xFFFF9500);
        iconData = Icons.pause_circle_filled_rounded;
        typeLabel = 'PAUSED > 7 DAYS';
        break;
      case NotificationKind.levelPromoted:
        accentColor = const Color(0xFF00BCD4);
        iconData = Icons.arrow_circle_up_rounded;
        typeLabel = 'LEVEL UP';
        break;
      case NotificationKind.weeklyBonusUnlocked:
        accentColor = const Color(0xFFBD00FF);
        iconData = Icons.military_tech_rounded;
        typeLabel = 'BONUS / MILESTONE';
        break;
      case NotificationKind.streakReminder:
        accentColor = const Color(0xFFFF5E00);
        iconData = Icons.local_fire_department_rounded;
        typeLabel = 'STREAK';
        break;
      default:
        accentColor = acidLime;
        iconData = Icons.notifications_rounded;
        typeLabel = 'ALERT';
        break;
    }

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
                        _formatRelativeTime(alert.timestamp),
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: mutedText,
                          fontSize: 10,
                        ),
                      ),
                      const Spacer(),
                      if (!alert.isRead)
                        IconButton(
                          icon: Icon(Icons.check_circle_outline, size: 16, color: acidLime),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Mark as Read',
                          onPressed: () => _service.markAsRead(alert.id, db: widget.database),
                        ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: Icon(Icons.close, size: 16, color: mutedText),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Dismiss Alert',
                        onPressed: () => _service.dismiss(alert.id, db: widget.database),
                      ),
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
                      child: InkWell(
                        onTap: () => _navigateToTarget(alert),
                        borderRadius: BorderRadius.circular(8),
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

  // ─────────────────────────────────────────────────────────────
  // ACTIVITY TIMELINE TAB (Phase 7)
  // ─────────────────────────────────────────────────────────────

  Widget _buildActivityTimelineTab(
    bool isDark,
    Color acidLime,
    Color primaryText,
    Color mutedText,
  ) {
    return Column(
      children: [
        _buildTimelineFilterChips(isDark, acidLime, mutedText),
        Expanded(
          child: StreamBuilder<List<ActivityEvent>>(
            stream: _timelineRepo.watchTimeline(
              ownerId: widget.ownerId,
              eventType: _timelineFilter == 'all' ? null : _timelineFilter,
              limit: 50,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(color: acidLime, strokeWidth: 2),
                );
              }

              final events = snapshot.data ?? [];
              if (events.isEmpty) {
                return _buildTimelineEmptyState(isDark, acidLime, primaryText, mutedText);
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: events.length,
                itemBuilder: (ctx, idx) => _buildTimelineCard(
                  events[idx],
                  isLast: idx == events.length - 1,
                  isDark: isDark,
                  acidLime: acidLime,
                  primaryText: primaryText,
                  mutedText: mutedText,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineFilterChips(
    bool isDark,
    Color acidLime,
    Color mutedText,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _buildTimelineChip('all', 'All Events', isDark: isDark, defaultActiveColor: acidLime, mutedText: mutedText),
          const SizedBox(width: 8),
          _buildTimelineChip('level_up', '⚡ Level Ups', activeColor: const Color(0xFF00BCD4), isDark: isDark, defaultActiveColor: acidLime, mutedText: mutedText),
          const SizedBox(width: 8),
          _buildTimelineChip('goal_completed', '🎯 Goals', activeColor: const Color(0xFFBD00FF), isDark: isDark, defaultActiveColor: acidLime, mutedText: mutedText),
          const SizedBox(width: 8),
          _buildTimelineChip('project_completed', '📦 Projects', activeColor: const Color(0xFF388BFD), isDark: isDark, defaultActiveColor: acidLime, mutedText: mutedText),
          const SizedBox(width: 8),
          _buildTimelineChip('streak_extended', '🔥 Streaks', activeColor: const Color(0xFFFF5E00), isDark: isDark, defaultActiveColor: acidLime, mutedText: mutedText),
          const SizedBox(width: 8),
          _buildTimelineChip('xp_earned', '✦ XP', activeColor: acidLime, isDark: isDark, defaultActiveColor: acidLime, mutedText: mutedText),
        ],
      ),
    );
  }

  Widget _buildTimelineChip(
    String filterId,
    String label, {
    Color? activeColor,
    required bool isDark,
    required Color defaultActiveColor,
    required Color mutedText,
  }) {
    final effectiveActiveColor = activeColor ?? defaultActiveColor;
    final isSelected = _timelineFilter == filterId;
    return InkWell(
      onTap: () => setState(() => _timelineFilter = filterId),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? effectiveActiveColor.withValues(alpha: isDark ? 0.15 : 0.12)
              : (isDark ? const Color(0x66050505) : const Color(0x66E7ECE4)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? effectiveActiveColor
                : (isDark ? Colors.white.withValues(alpha: 0.10) : KratosTheme.lightBorderGlass),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'IBM Plex Mono',
            color: isSelected ? effectiveActiveColor : mutedText,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineCard(
    ActivityEvent event, {
    required bool isLast,
    required bool isDark,
    required Color acidLime,
    required Color primaryText,
    required Color mutedText,
  }) {
    Color accentColor;
    IconData iconData;
    String title;
    String subtitle = '';

    Map<String, dynamic> meta = {};
    try {
      meta = jsonDecode(event.metadata) as Map<String, dynamic>;
    } catch (_) {}

    switch (event.eventType) {
      case 'level_up':
        accentColor = const Color(0xFF00BCD4);
        iconData = Icons.arrow_circle_up_rounded;
        title = 'Level Up: Reached Level ${meta['to_level'] ?? 2}';
        subtitle = 'Progression threshold achieved via consistent action.';
        break;
      case 'achievement_unlocked':
        accentColor = const Color(0xFFFFD700);
        iconData = Icons.military_tech_rounded;
        title = 'Achievement: ${meta['kind'] ?? 'Mastery Badge'}';
        subtitle = 'Awarded freeze tokens and permanence badge.';
        break;
      case 'goal_completed':
        accentColor = const Color(0xFFBD00FF);
        iconData = Icons.flag_rounded;
        title = 'Goal Completed: ${meta['title'] ?? 'Objective'}';
        subtitle = '+30% bonus points awarded for tree completion.';
        break;
      case 'project_completed':
        accentColor = const Color(0xFF388BFD);
        iconData = Icons.layers_rounded;
        title = 'Project Completed: ${meta['title'] ?? 'Roadmap'}';
        subtitle = 'All phases delivered and validated.';
        break;
      case 'streak_extended':
        accentColor = const Color(0xFFFF5E00);
        iconData = Icons.local_fire_department_rounded;
        final streak = meta['current_streak'] ?? 1;
        title = 'Streak Extended: $streak Days Active';
        subtitle = 'Maintained uninterrupted daily focus.';
        break;
      case 'xp_earned':
        accentColor = acidLime;
        iconData = Icons.bolt_rounded;
        final pts = meta['points'] ?? 0;
        final action = meta['action'] ?? 'action';
        title = '+$pts XP Earned ($action)';
        subtitle = 'Attributed to life area ledger.';
        break;
      case 'xp_reversed':
        accentColor = const Color(0xFFFF3B30);
        iconData = Icons.undo_rounded;
        title = 'XP Reversal Recorded';
        subtitle = 'Compensating ledger adjustment applied.';
        break;
      default:
        accentColor = mutedText;
        iconData = Icons.history_rounded;
        title = 'Activity: ${event.eventType}';
        subtitle = 'Entity: ${event.entityType}';
        break;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline vertical bar and node
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
          // Content card
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
                            event.eventType.toUpperCase().replaceAll('_', ' '),
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
                          _formatRelativeTime(event.occurredAt),
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

  Widget _buildEmptyState(
    bool isDark,
    Color acidLime,
    Color primaryText,
    Color mutedText,
  ) {
    return Center(
      child: KratosEmptyState(
        icon: Icons.done_all_rounded,
        eyebrow: 'NOTIFICATIONS / CLEAR',
        title: 'All Clear',
        message: 'No pending alerts, overdue tasks, or stale items.',
      ),
    );
  }

  Widget _buildTimelineEmptyState(
    bool isDark,
    Color acidLime,
    Color primaryText,
    Color mutedText,
  ) {
    return Center(
      child: KratosEmptyState(
        icon: Icons.timeline_rounded,
        eyebrow: 'TIMELINE / IDLE',
        title: 'No Activity Recorded Yet',
        message: 'Complete tasks, log focus sessions, and earn XP to build your timeline.',
      ),
    );
  }

  String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt.toLocal());

    if (difference.isNegative || difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
  }
}
