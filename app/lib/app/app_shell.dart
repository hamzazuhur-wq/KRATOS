import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/drift/app_database.dart';
import '../domain/ids.dart';
import 'kratos_motion.dart';
import 'kratos_main_bar.dart';
import 'kratos_theme.dart';
import 'number_pop_in.dart';
import 'kratos_visuals.dart';
import '../features/activities/presentation/activities_screen.dart';
import '../features/calendar/presentation/calendar_screen.dart';
import '../features/activities/presentation/activity_detail_screen.dart';
import '../features/goals/presentation/goals_screen.dart';
import '../features/home/data/due_today_repository.dart';
import '../features/home/presentation/due_today_screen.dart';
import '../features/home/presentation/home_dashboard_screen.dart';
import '../features/ideas/presentation/ideas_dashboard_screen.dart';
import '../features/levels/presentation/levels_dashboard_screen.dart';
import '../features/life_areas/presentation/life_areas_screen.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/profile/domain/profile_models.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/projects/presentation/projects_screen.dart';
import '../features/sessions/presentation/global_active_session_mini_player.dart';
import '../features/sessions/presentation/global_timer_banner.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/skills/presentation/skills_registry_screen.dart';
import '../features/streaks/domain/streak_models.dart';
import '../features/streaks/data/streaks_dao.dart';
import '../features/streaks/domain/streak_config.dart';
import '../features/streaks/presentation/streak_screen.dart';
import '../features/sync/domain/sync_engine.dart';
import '../features/sync/domain/sync_models.dart';
import '../features/sync/presentation/sync_status_badge.dart';
import '../features/tasks/presentation/tasks_screen.dart';
import '../features/analytics/presentation/analytics_screen.dart';
import '../features/notifications/domain/deadline_notification_scheduler.dart';
import '../features/notifications/domain/notification_service.dart';
import '../features/notifications/domain/notification_models.dart';
import '../features/notifications/presentation/notifications_screen.dart';

class AppShell extends StatefulWidget {
  final VoidCallback? onSignOut;
  final AppDatabase database;
  final String userId;
  final SyncTransport? syncTransport;

  const AppShell({
    super.key,
    required this.database,
    required this.userId,
    this.syncTransport,
    this.onSignOut,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0; // 0 = Home
  final GlobalKey<ScaffoldState> _mobileScaffoldKey =
      GlobalKey<ScaffoldState>();
  late final DeadlineNotificationScheduler _notificationScheduler;
  SyncEngine? _syncEngine;
  StreamSubscription<SyncConnectionState>? _syncSubscription;
  SyncConnectionState _syncState = SyncConnectionState.offline;
  final List<Widget?> _tabScreens = List<Widget?>.filled(7, null);
  StreakInfo _streakInfo = StreakInfo.create(
    userId: Id(''),
    lifeAreaId: Id('overall'),
    currentStreak: 0,
    longestStreak: 0,
    freezeTokensAvailable: 0,
  );
  late final Stream<UserProfileData> _profileStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationScheduler = DeadlineNotificationScheduler(widget.database);
    _profileStream = ProfileRepository(database: widget.database)
        .watchProfile(widget.userId)
        .asBroadcastStream();
    _startSync();
    _loadStreak();
    NotificationService().scanAllAlerts(
      db: widget.database,
      ownerId: widget.userId,
      dispatchSystem: false,
    );
    _notificationScheduler.bootstrap(ownerId: widget.userId);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the background is exactly when a slipped deadline should
    // surface as a real OS notification.
    if (state == AppLifecycleState.resumed) {
      _notificationScheduler.bootstrap(ownerId: widget.userId);
    }
  }

  Future<void> _startSync() async {
    final transport = widget.syncTransport;
    if (transport == null) return;
    try {
      var profile = await (widget.database.select(
        widget.database.users,
      )..where((row) => row.id.equals(widget.userId))).getSingleOrNull();
      if (profile == null) {
        final deviceId = Id.uuidV7().value;
        final now = DateTime.now().toUtc();
        await widget.database
            .into(widget.database.users)
            .insertOnConflictUpdate(
              UsersCompanion.insert(
                id: widget.userId,
                deviceId: deviceId,
                timezone: 'UTC',
                createdAt: now,
                updatedAt: now,
              ),
            );
        profile = await (widget.database.select(
          widget.database.users,
        )..where((row) => row.id.equals(widget.userId))).getSingle();
      }
      if (!mounted) return;
      final engine = SyncEngine(
        outbox: widget.database.syncDao,
        transport: transport,
        userId: widget.userId,
        deviceId: profile.deviceId,
        database: widget.database,
      );
      _syncEngine = engine;
      _syncSubscription = engine.stateStream.listen((state) {
        if (mounted) setState(() => _syncState = state);
      });
      engine.start();
    } catch (_) {
      if (mounted) setState(() => _syncState = SyncConnectionState.error);
    }
  }

  Future<void> _loadStreak() async {
    try {
      final streaks = await widget.database.streaksDao.allStreaksForUser(
        widget.userId,
      );
      final global = streaks.where(
        (streak) => streak.lifeAreaId == StreaksDao.globalStreakKey,
      );
      if (!mounted) return;
      final globalStreak = global.isEmpty ? null : global.first;
      final visibleStreaks = globalStreak == null ? streaks : [globalStreak];
      int currentStreak = 0;
      int longestStreak = 0;
      for (final s in visibleStreaks) {
        currentStreak = s.currentStreak > currentStreak
            ? s.currentStreak
            : currentStreak;
        longestStreak = s.longestStreak > longestStreak
            ? s.longestStreak
            : longestStreak;
      }
      final freezeCount = globalStreak == null
          ? StreakConfig.maxFreezes
          : await widget.database.streaksDao.globalFreezesAvailable(
              widget.userId,
            );
      if (!mounted) return;
      setState(() {
        _streakInfo = StreakInfo.create(
          userId: Id(widget.userId),
          lifeAreaId: Id(StreaksDao.globalStreakKey),
          currentStreak: currentStreak,
          longestStreak: longestStreak,
          freezeTokensAvailable: freezeCount,
        );
      });
    } catch (_) {
      // Keep default zero state if DB not ready yet
    }
  }

  void _nextTab() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % 6;
    });
  }

  void _prevTab() {
    setState(() {
      _currentIndex = (_currentIndex - 1 + 6) % 6;
    });
  }

  @override
  void dispose() {
    KratosPageRoute.globalHeaderBuilder = null;
    WidgetsBinding.instance.removeObserver(this);
    _syncSubscription?.cancel();
    _syncEngine?.dispose();
    super.dispose();
  }

  String get _currentSectionTitle => switch (_currentIndex) {
    0 => 'HOME',
    1 => 'TASKS',
    2 => 'GOALS',
    3 => 'ACTIVITIES',
    4 => 'IDEAS',
    5 => 'CALENDAR',
      6 => 'STATS',
    _ => 'KRATOS',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 840;
    KratosPageRoute.globalHeaderBuilder = (routeContext) =>
        _buildGlobalMainBar(context, isMobile: !isDesktop);

    if (isDesktop) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const KratosEnvironment(),
          Scaffold(
            backgroundColor: Colors.transparent,
            body: Row(
              children: [
                Container(
                  width: 270,
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xF2121613),
                              Color(0xF20D100E),
                              Color(0xF5080A08),
                            ],
                          )
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xF8FFFFFF),
                              Color(0xF4F8F9FA),
                              Color(0xF2F0F2F5),
                            ],
                          ),
                    border: Border(
                      right: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.09)
                            : KratosTheme.lightBorderGlass,
                        width: 1.0,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.40)
                            : const Color(0x0C0F172A),
                        blurRadius: 20,
                        offset: const Offset(4, 0),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: SafeArea(
                      child: _buildSidebarContent(context, isDrawer: false),
                    ),
                  ),
                ),
                Expanded(
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    appBar: PreferredSize(
                      preferredSize: const Size.fromHeight(64),
                      child: _buildGlobalMainBar(context, isMobile: false),
                    ),
                    body: Stack(
                      children: [
                        Column(
                          children: [
                            GlobalTimerBanner(
                              database: widget.database,
                              ownerId: widget.userId,
                            ),
                            Expanded(
                              child: KratosTabTransition(
                                currentIndex: _currentIndex,
                                onSwipeLeft: _nextTab,
                                onSwipeRight: _prevTab,
                                children: _buildTabScreens(),
                              ),
                            ),
                          ],
                        ),
                        GlobalActiveSessionMiniPlayer(
                          database: widget.database,
                          ownerId: widget.userId,
                          onOpenDetail: (type, id) {
                            if (type == 'activity') {
                              Navigator.of(context).push(
                                KratosMaterialPageRoute(
                                  builder: (_) => ActivityDetailScreen(
                                    database: widget.database,
                                    ownerId: widget.userId,
                                    activityId: id,
                                  ), settings: RouteSettings(name: '/activity/$id'),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Stack(
        fit: StackFit.expand,
        children: [
          const KratosEnvironment(),
        Scaffold(
          key: _mobileScaffoldKey,
          backgroundColor: Colors.transparent,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: _buildGlobalMainBar(context, isMobile: true),
          ),
          drawer: Drawer(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xF5141815),
                          Color(0xF50E110F),
                          Color(0xF8080A08),
                        ],
                      )
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xF8FFFFFF),
                          Color(0xF5F8F9FA),
                          Color(0xF5F0F2F5),
                        ],
                      ),
                border: Border(
                  right: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : KratosTheme.lightBorderGlass,
                    width: 1.0,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.60)
                        : const Color(0x180F172A),
                    blurRadius: 28,
                    offset: const Offset(6, 0),
                  ),
                ],
              ),
              child: SafeArea(
                child: _buildSidebarContent(context, isDrawer: true),
              ),
            ),
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  GlobalTimerBanner(
                    database: widget.database,
                    ownerId: widget.userId,
                  ),
                  Expanded(
                    child: KratosTabTransition(
                      currentIndex: _currentIndex,
                      onSwipeLeft: _nextTab,
                      onSwipeRight: _prevTab,
                      children: _buildTabScreens(),
                    ),
                  ),
                ],
              ),
              GlobalActiveSessionMiniPlayer(
                database: widget.database,
                ownerId: widget.userId,
                onOpenDetail: (type, id) {
                  if (type == 'activity') {
                    Navigator.of(context).push(
                      KratosPageRoute(
                        page: ActivityDetailScreen(
                          database: widget.database,
                          ownerId: widget.userId,
                          activityId: id,
                        ), settings: RouteSettings(name: '/activity/$id'),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          bottomNavigationBar: KratosGlassBottomBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: const [
              KratosNavItem(
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard,
                label: 'Home',
              ),
              KratosNavItem(
                icon: Icons.checklist_outlined,
                activeIcon: Icons.checklist,
                label: 'Tasks',
              ),
              KratosNavItem(
                icon: Icons.track_changes_outlined,
                activeIcon: Icons.track_changes,
                label: 'Goals',
              ),
              KratosNavItem(
                icon: Icons.repeat,
                activeIcon: Icons.repeat,
                label: 'Activities',
              ),
              KratosNavItem(
                icon: Icons.lightbulb_outline,
                activeIcon: Icons.lightbulb,
                label: 'Ideas',
              ),
              KratosNavItem(
                icon: Icons.analytics_outlined,
                activeIcon: Icons.analytics,
                label: 'Stats',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalMainBar(BuildContext context, {required bool isMobile}) {
    return StreamBuilder<List<KratosNotification>>(
      stream: NotificationService().notificationsStream,
      initialData: NotificationService().currentNotifications,
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? const <KratosNotification>[];
        final unread = alerts.where((a) => !a.isRead && !a.isDismissed).length;
        final urgent = alerts.any(
          (a) =>
              !a.isRead &&
              !a.isDismissed &&
              a.severity == NotificationSeverity.urgent,
        );
        // AppShell links KratosMainBar (hosting StreakBadgeWidget) with Navigation and Sync
        return KratosMainBar(
          database: widget.database,
          ownerId: widget.userId,
          streakInfo: _streakInfo,
          notificationCount: unread,
          hasUrgentNotification: urgent,
          currentSection: _currentSectionTitle,
          onMenu: _openGlobalMenu,
          onNotifications: () => _openNotifications(context),
          onStreak: () => Navigator.of(context).push(
            KratosPageRoute(
              page: StreakScreen(
                database: widget.database,
                userId: widget.userId,
                streakInfo: _streakInfo,
              ), settings: const RouteSettings(name: '/streaks'),
            ),
          ),
        );
      },
    );
  }

  void _openGlobalMenu() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
    if (MediaQuery.of(context).size.width >= 840) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mobileScaffoldKey.currentState?.openDrawer();
    });
  }

  void _openNotifications(BuildContext context) {
    Navigator.of(context).push(
      KratosPageRoute(
        page: NotificationsScreen(
          database: widget.database,
          ownerId: widget.userId,
        ), settings: const RouteSettings(name: '/notifications'),
      ),
    );
  }

  List<Widget> _buildTabScreens() {
    _tabScreens[_currentIndex] ??= switch (_currentIndex) {
      0 => HomeDashboardScreen(
        database: widget.database,
        ownerId: widget.userId,
        useRichCaption: true,
        onNavigateTab: (index) => setState(() => _currentIndex = index),
      ),
      1 => TasksScreen(database: widget.database, ownerId: widget.userId),
      2 => GoalsScreen(database: widget.database, ownerId: widget.userId),
      3 => ActivitiesScreen(database: widget.database, ownerId: widget.userId),
      4 => IdeasDashboardScreen(
        database: widget.database,
        ownerId: widget.userId,
      ),
      5 => CalendarScreen(
          database: widget.database,
          ownerId: widget.userId,
        ),
        _ => AnalyticsScreen(
        ownerId: widget.userId,
        database: widget.database,
      ),
    };
    return _tabScreens
        .map((screen) => screen ?? const SizedBox.shrink())
        .toList(growable: false);
  }

  Widget _buildSidebarContent(BuildContext context, {required bool isDrawer}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // 1. Profile Header (Visually distinct, clickable to open ProfileScreen)
        StreamBuilder<UserProfileData>(
          stream: _profileStream,
          builder: (context, snapshot) {
            final profile = snapshot.data;
            final displayName = profile?.displayName ?? 'Operative';
            final caption =
                (profile?.caption != null && profile!.caption!.isNotEmpty)
                ? profile.caption!
                : 'Who you are and who you want to be';
            final avatarUrl = profile?.avatarUrl;
            final hasImage = avatarUrl != null && avatarUrl.isNotEmpty;

            return InkWell(
              onTap: () {
                final nav = Navigator.of(context);
                if (isDrawer) {
                  nav.pop();
                }
                nav.push(
                  KratosPageRoute(
                    page: ProfileScreen(
                      database: widget.database,
                      userId: widget.userId,
                      onSignOut: widget.onSignOut,
                    ), settings: const RouteSettings(name: '/profile'),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.035)
                      : const Color(0xFFF3F4F6),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.white12 : const Color(0x1F000000),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (isDark
                                      ? const Color(0xFFC6F135)
                                      : KratosTheme.lightAcidLime)
                                  .withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                          child: ClipOval(
                            child: hasImage
                                ? (avatarUrl.startsWith('data:image')
                                      ? Image.memory(
                                          base64Decode(
                                            avatarUrl.split(',').last,
                                          ),
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, stack) =>
                                              _buildFallbackInitial(
                                                displayName,
                                              ),
                                        )
                                      : Image.network(
                                          avatarUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, stack) =>
                                              _buildFallbackInitial(
                                                displayName,
                                              ),
                                        ))
                                : _buildFallbackInitial(displayName),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : KratosTheme.lightTextPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFFC6F135)
                                      : KratosTheme.lightAcidLime,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: isDark
                              ? Colors.white30
                              : KratosTheme.lightTextMuted,
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'User: ${widget.userId}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white38
                                  : KratosTheme.lightTextMuted,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SyncStatusBadge(state: _syncState),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // Flat List of 10 items in exact required order (NO categories / NO section headers / NO dividers)
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _buildSidebarTile(
                icon: Icons.dashboard_outlined,
                title: 'Home',
                isSelected: _currentIndex == 0,
                onTap: () {
                  setState(() => _currentIndex = 0);
                  if (isDrawer) Navigator.of(context).pop();
                },
              ),
              _buildSidebarTile(
                icon: Icons.notification_important_outlined,
                title: 'Due Today',
                trailing: _buildDueBadge(),
                onTap: () {
                  final nav = Navigator.of(context);
                  if (isDrawer) nav.pop();
                  nav.push(
                    KratosPageRoute(
                      page: DueTodayScreen(
                        database: widget.database,
                        ownerId: widget.userId,
                      ), settings: const RouteSettings(name: '/due_today'),
                    ),
                  );
                },
              ),
              _buildSidebarTile(
                icon: Icons.checklist_outlined,
                title: 'Tasks',
                isSelected: _currentIndex == 1,
                onTap: () {
                  setState(() => _currentIndex = 1);
                  if (isDrawer) Navigator.of(context).pop();
                },
              ),
              _buildSidebarTile(
                icon: Icons.track_changes_outlined,
                title: 'Goals',
                isSelected: _currentIndex == 2,
                onTap: () {
                  setState(() => _currentIndex = 2);
                  if (isDrawer) Navigator.of(context).pop();
                },
              ),
              _buildSidebarTile(
                icon: Icons.repeat,
                title: 'Activities',
                isSelected: _currentIndex == 3,
                onTap: () {
                  setState(() => _currentIndex = 3);
                  if (isDrawer) Navigator.of(context).pop();
                },
              ),
              _buildSidebarTile(
                icon: Icons.lightbulb_outline,
                title: 'Idea Capture',
                isSelected: _currentIndex == 4,
                onTap: () {
                  setState(() => _currentIndex = 4);
                  if (isDrawer) Navigator.of(context).pop();
                },
              ),
              _buildSidebarTile(
                icon: Icons.calendar_month_outlined,
                  title: 'Calendar',
                  isSelected: _currentIndex == 5,
                  onTap: () {
                    setState(() => _currentIndex = 5);
                  },
                ),
                _buildSidebarTile(
                  icon: Icons.analytics_outlined,
                  title: 'Stats',
                  isSelected: _currentIndex == 6,
                  onTap: () {
                    setState(() => _currentIndex = 6);
                  if (isDrawer) Navigator.of(context).pop();
                },
              ),
              _buildSidebarTile(
                icon: Icons.military_tech_outlined,
                title: 'Levels',
                onTap: () {
                  final nav = Navigator.of(context);
                  if (isDrawer) nav.pop();
                  nav.push(
                    KratosPageRoute(
                      page: LevelsDashboardScreen(
                        database: widget.database,
                        ownerId: widget.userId,
                      ), settings: const RouteSettings(name: '/levels'),
                    ),
                  );
                },
              ),
              _buildSidebarTile(
                icon: Icons.visibility_outlined,
                title: 'Life Areas',
                onTap: () {
                  final nav = Navigator.of(context);
                  if (isDrawer) nav.pop();
                  nav.push(
                    KratosPageRoute(
                      page: LifeAreasScreen(
                        database: widget.database,
                        ownerId: widget.userId,
                      ), settings: const RouteSettings(name: '/life_areas'),
                    ),
                  );
                },
              ),
              _buildSidebarTile(
                icon: Icons.psychology_outlined,
                title: 'Skills',
                onTap: () {
                  final nav = Navigator.of(context);
                  if (isDrawer) nav.pop();
                  nav.push(
                    KratosPageRoute(
                      page: SkillsRegistryScreen(
                        database: widget.database,
                        ownerId: widget.userId,
                      ), settings: const RouteSettings(name: '/skills'),
                    ),
                  );
                },
              ),
              _buildSidebarTile(
                icon: Icons.task_alt_outlined,
                title: 'Projects',
                onTap: () {
                  final nav = Navigator.of(context);
                  if (isDrawer) nav.pop();
                  nav.push(
                    KratosPageRoute(
                      page: ProjectsScreen(
                        database: widget.database,
                        ownerId: widget.userId,
                      ), settings: const RouteSettings(name: '/projects'),
                    ),
                  );
                },
              ),
              _buildSidebarTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: () {
                  final nav = Navigator.of(context);
                  if (isDrawer) nav.pop();
                  nav.push(
                    KratosPageRoute(
                      page: SettingsScreen(
                        database: widget.database,
                        ownerId: widget.userId,
                      ), settings: const RouteSettings(name: '/settings'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Sign Out Footer
        if (widget.onSignOut != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white12 : const Color(0x1F000000),
                  width: 0.5,
                ),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : const Color(0xFFFEE2E2).withValues(alpha: 0.5),
                leading: const Icon(
                  Icons.logout,
                  color: Color(0xFFFF3B30),
                  size: 20,
                ),
                title: const Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Color(0xFFFF3B30),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                onTap: () {
                  if (isDrawer) Navigator.of(context).pop();
                  widget.onSignOut!();
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSidebarTile({
    required IconData icon,
    required String title,
    bool isSelected = false,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return _SidebarNavTile(
      icon: icon,
      title: title,
      isSelected: isSelected,
      trailing: trailing,
      onTap: onTap,
    );
  }

  /// Live overdue badge for the Due Today navigation entry.
  Widget _buildDueBadge() {
    return StreamBuilder<DueOverview>(
      stream: DueTodayRepository(widget.database)
          .watchDueOverview(widget.userId),
      builder: (context, snapshot) {
        final count = snapshot.data?.overdueCount ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B30).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: const Color(0xFFFF3B30).withValues(alpha: 0.6),
            ),
          ),
          child: KratosNumberPopIn(
            '$count',
            style: const TextStyle(
              color: Color(0xFFFF3B30),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallbackInitial(String name) {
    final initial = name.trim().isNotEmpty
        ? name.trim().substring(0, 1).toUpperCase()
        : 'K';
    return Container(
      color: const Color(0xFF1E281E),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFFC6F135),
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _SidebarNavTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SidebarNavTile({
    required this.icon,
    required this.title,
    this.isSelected = false,
    this.trailing,
    required this.onTap,
  });

  @override
  State<_SidebarNavTile> createState() => _SidebarNavTileState();
}

class _SidebarNavTileState extends State<_SidebarNavTile> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
    final isSelected = widget.isSelected;
    final unselectedIcon = isDark ? Colors.white54 : KratosTheme.lightTextSecondary;
    final unselectedText = isDark ? Colors.white70 : KratosTheme.lightTextPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.985 : (_hovered ? 1.008 : 1.0),
            duration: const Duration(milliseconds: 100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isSelected
                    ? accent.withValues(alpha: isDark ? 0.14 : 0.12)
                    : (_hovered
                        ? (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0x0C0F172A))
                        : Colors.transparent),
                border: Border.all(
                  color: isSelected
                      ? accent.withValues(alpha: isDark ? 0.45 : 0.55)
                      : (_hovered
                          ? (isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0x1F0F172A))
                          : Colors.transparent),
                  width: 1.0,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: accent.withValues(alpha: isDark ? 0.08 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Row(
                children: [
                  // Subtle left active indicator bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: isSelected ? accent : Colors.transparent,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Icon(
                    widget.icon,
                    color: isSelected ? accent : unselectedIcon,
                    size: 19,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: isSelected
                            ? (isDark ? Colors.white : KratosTheme.lightTextPrimary)
                            : unselectedText,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  if (widget.trailing != null) widget.trailing!,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}





