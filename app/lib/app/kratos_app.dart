// Wave 18: KratosApp — Root Application Widget with State Routing.
// Manages authentication state, onboarding completion, and Liquid Glass theme.
// ignore_for_file: avoid_print

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../data/drift/app_database.dart';
import '../core/config/app_config.dart';
import '../domain/hlc.dart';
import '../domain/ids.dart';
import '../features/auth/data/mock_auth_service.dart';
import '../features/auth/data/supabase_auth_service.dart';
import '../features/auth/domain/auth_models.dart';
import '../features/auth/domain/auth_service.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/onboarding/domain/onboarding_service.dart';
import '../features/sync/data/supabase_sync_transport.dart';
import 'app_shell.dart';
import 'kratos_theme.dart';
import 'kratos_theme_controller.dart';
import 'kratos_visuals.dart';
import '../features/preview/wave05_xp_distribution_storybook_screen.dart';
import '../features/preview/wave06_xp_progress_storybook_screen.dart';
import '../features/preview/wave07_life_areas_radar_storybook_screen.dart';
import '../features/preview/wave08_top_skills_storybook_screen.dart';
import '../features/preview/wave09_daily_activity_storybook_screen.dart';
import '../features/preview/focus_time_storybook_screen.dart';
import '../features/preview/insights_storybook_screen.dart';
import '../features/analytics/presentation/insights_screen.dart';
import '../features/preview/wave12_settings_storybook_screen.dart';
import '../features/preview/wave13_profile_storybook_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/calendar/presentation/calendar_screen.dart';
import '../features/home/presentation/due_today_screen.dart';
import '../features/levels/presentation/levels_dashboard_screen.dart';
import '../features/life_areas/presentation/life_areas_screen.dart';
import '../features/skills/presentation/skills_registry_screen.dart';
import '../features/projects/presentation/projects_screen.dart';

class KratosApp extends StatefulWidget {
  final AuthService? authService;
  final AppDatabase? database;

  const KratosApp({super.key, this.authService, this.database});

  @override
  State<KratosApp> createState() => _KratosAppState();
}

class _KratosAppState extends State<KratosApp> {
  late final AuthService _authService;
  late final AppDatabase _database;
  final AppConfig _config = AppConfig.fromEnvironment();
  bool _isOnboarded = false;
  String? _checkedUserId;
  bool _checkingOnboarding = false;

  @override
  void initState() {
    super.initState();
    _database = widget.database ?? AppDatabase();
    _authService = widget.authService ?? _createRuntimeAuth();
    KratosThemeController.instance.load();
  }

  static const String _devPreviewUserId = 'usr_seed_dev_01';
  Future<void>? _devPreviewSeed;

  /// Seeds the dev user (users row, life areas, progression inputs) once for
  /// the `?preview=dashboard` route. Idempotent: skipped when onboarding is
  /// already complete. Never blocks the preview on failure.
  Future<void> _ensureDevPreviewSeed() => _devPreviewSeed ??= () async {
    try {
      debugPrint('[KratosApp] _ensureDevPreviewSeed starting...');
      final onboardingService = OnboardingService(_database);
      debugPrint('[KratosApp] checking isCompleted...');
      final isComp = await onboardingService
          .isCompleted(_devPreviewUserId)
          .timeout(const Duration(seconds: 90));
      debugPrint('[KratosApp] isCompleted = $isComp');
      if (!isComp) {
        debugPrint('[KratosApp] bootstrapDevUser starting...');
        await onboardingService.bootstrapDevUser(userId: _devPreviewUserId);
        debugPrint('[KratosApp] bootstrapDevUser completed!');
      }
    } catch (e, st) {
      debugPrint('[KratosApp] Dev preview seed note: $e\n$st');
    }
  }();

  Future<void> _loadOnboarding(String userId) async {
    if (userId.startsWith('usr_seed_dev') || userId == 'usr_seed_dev_01') {
      try {
        final onboardingService = OnboardingService(_database);
        final completed = await onboardingService.isCompleted(userId);
        if (!completed) {
          await onboardingService.bootstrapDevUser(userId: userId);
        }
      } catch (e) {
        print('[KratosApp] Dev bootstrap note: $e');
      }
      if (!mounted) return;
      setState(() {
        _checkedUserId = userId;
        _isOnboarded = true;
        _checkingOnboarding = false;
      });
      return;
    }

    setState(() => _checkingOnboarding = true);
    try {
      final onboardingService = OnboardingService(_database);
      var completed = await onboardingService
          .isCompleted(userId)
          .timeout(const Duration(seconds: 12));

      // Remote Supabase fallback:
      // If local database has no user record (e.g. fresh browser session or hard reload on Web),
      // check if the user already has life areas seeded in Supabase cloud database.
      if (!completed && _config.hasSupabaseConfiguration) {
        try {
          final client = supabase.Supabase.instance.client;
          final remoteLifeAreas = await client
              .from('life_areas')
              .select(
                'id, name, description, color, icon, sort_order, version_hlc, created_at, updated_at',
              )
              .eq('owner_id', userId);

          if (remoteLifeAreas.isNotEmpty) {
            completed = true;

            final now = DateTime.now().toUtc();
            await _database
                .into(_database.users)
                .insertOnConflictUpdate(
                  UsersCompanion.insert(
                    id: userId,
                    deviceId: Id.uuidV7().value,
                    timezone: 'UTC',
                    createdAt: now,
                    updatedAt: now,
                  ),
                );

            final localAreas = await (_database.select(
              _database.lifeAreas,
            )..where((row) => row.ownerId.equals(userId))).get();
            if (localAreas.isEmpty) {
              for (final area in remoteLifeAreas) {
                await _database
                    .into(_database.lifeAreas)
                    .insertOnConflictUpdate(
                      LifeAreasCompanion(
                        id: drift.Value(area['id'] as String),
                        ownerId: drift.Value(userId),
                        name: drift.Value(area['name'] as String),
                        description: drift.Value(
                          area['description'] as String? ?? '',
                        ),
                        color: drift.Value(
                          area['color'] as String? ?? '#CCFF00',
                        ),
                        icon: drift.Value(area['icon'] as String? ?? 'target'),
                        sortOrder: drift.Value(area['sort_order'] as int? ?? 0),
                        versionHlc: drift.Value(
                          area['version_hlc'] as String? ?? '0',
                        ),
                        createdAt: drift.Value(
                          DateTime.tryParse(
                                area['created_at']?.toString() ?? '',
                              ) ??
                              now,
                        ),
                        updatedAt: drift.Value(
                          DateTime.tryParse(
                                area['updated_at']?.toString() ?? '',
                              ) ??
                              now,
                        ),
                      ),
                    );
              }
            }
          }
        } catch (supaErr) {
          print('[KratosApp] Remote onboarding check error: $supaErr');
        }
      }

      if (!completed &&
          (userId.startsWith('usr_seed_dev') || userId == 'usr_seed_dev_01')) {
        await onboardingService.bootstrapDevUser(userId: userId);
        completed = true;
      }
      if (!mounted) return;
      setState(() {
        _checkedUserId = userId;
        _isOnboarded = completed;
        _checkingOnboarding = false;
      });
    } catch (e, stack) {
      print('[KratosApp] _loadOnboarding error for $userId: $e\n$stack');
      if (!mounted) return;
      // Fall back: treat as not onboarded so we reach the onboarding flow
      // rather than staying on the infinite spinner.
      setState(() {
        _checkedUserId = userId;
        _isOnboarded = false;
        _checkingOnboarding = false;
      });
    }
  }

  @override
  void dispose() {
    if (widget.authService == null) {
      final auth = _authService;
      if (auth is MockAuthService) auth.dispose();
      if (auth is SupabaseAuthService) auth.dispose();
    }
    if (widget.database == null) _database.close();
    super.dispose();
  }

  AuthService _createRuntimeAuth() {
    if (_config.hasSupabaseConfiguration) {
      return SupabaseAuthService();
    }
    return MockAuthService(autoAuthenticate: false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: KratosThemeController.instance,
      builder: (context, _) {
        final controller = KratosThemeController.instance;
        return MaterialApp(
          title: 'KRATOS',
          debugShowCheckedModeBanner: false,
          theme: KratosTheme.lightTheme,
          darkTheme: KratosTheme.darkTheme,
          themeMode: controller.themeMode,
          builder: (context, child) =>
              KratosEnvironment(child: child ?? const SizedBox.shrink()),
          home: Builder(
            builder: (context) {
              final uri = Uri.base;
              final previewKey = uri.queryParameters['preview'];
              if (previewKey == 'dashboard' ||
                  previewKey == 'home' ||
                  previewKey == 'app' ||
                  uri.queryParameters['dev'] == 'true' ||
                  uri.queryParameters['mode'] == 'dev' ||
                  uri.fragment.contains('preview=dashboard') ||
                  uri.fragment.contains('preview=home') ||
                  uri.fragment.contains('preview=app') ||
                  uri.fragment.contains('dev=true')) {
                var themeParam = uri.queryParameters['theme'];
                if (themeParam == null && uri.fragment.contains('theme=')) {
                  if (uri.fragment.contains('theme=light')) {
                    themeParam = 'light';
                  } else if (uri.fragment.contains('theme=dark')) {
                    themeParam = 'dark';
                  }
                }
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return FutureBuilder<void>(
                  future: _ensureDevPreviewSeed(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Scaffold(
                        backgroundColor: Colors.transparent,
                        body: Center(
                          child: CircularProgressIndicator(
                            color: KratosTheme.acidLime,
                          ),
                        ),
                      );
                    }
                    return AppShell(
                      database: _database,
                      userId: _devPreviewUserId,
                      initialTabIndex: 0,
                    );
                  },
                );
              }
              if (previewKey == 'analytics' ||
                  uri.fragment.contains('preview=analytics') ||
                  previewKey == 'stats' ||
                  uri.fragment.contains('preview=stats')) {
                var themeParam = uri.queryParameters['theme'];
                if (themeParam == null && uri.fragment.contains('theme=')) {
                  if (uri.fragment.contains('theme=light')) {
                    themeParam = 'light';
                  } else if (uri.fragment.contains('theme=dark')) {
                    themeParam = 'dark';
                  }
                }
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return FutureBuilder<void>(
                  future: _ensureDevPreviewSeed(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Scaffold(
                        backgroundColor: Colors.transparent,
                        body: Center(
                          child: CircularProgressIndicator(
                            color: KratosTheme.acidLime,
                          ),
                        ),
                      );
                    }
                    return AppShell(
                      database: _database,
                      userId: _devPreviewUserId,
                      initialTabIndex: 5,
                    );
                  },
                );
              }
              if (previewKey == 'tasks' ||
                  uri.fragment.contains('preview=tasks')) {
                var themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return FutureBuilder<void>(
                  future: _ensureDevPreviewSeed(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Scaffold(
                        backgroundColor: Colors.transparent,
                        body: Center(
                          child: CircularProgressIndicator(
                            color: KratosTheme.acidLime,
                          ),
                        ),
                      );
                    }
                    return AppShell(
                      database: _database,
                      userId: _devPreviewUserId,
                      initialTabIndex: 1,
                    );
                  },
                );
              }
              if (previewKey == 'goals' ||
                  uri.fragment.contains('preview=goals')) {
                var themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return FutureBuilder<void>(
                  future: _ensureDevPreviewSeed(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Scaffold(
                        backgroundColor: Colors.transparent,
                        body: Center(
                          child: CircularProgressIndicator(
                            color: KratosTheme.acidLime,
                          ),
                        ),
                      );
                    }
                    return AppShell(
                      database: _database,
                      userId: _devPreviewUserId,
                      initialTabIndex: 2,
                    );
                  },
                );
              }
              if (previewKey == 'activities' ||
                  uri.fragment.contains('preview=activities')) {
                var themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return FutureBuilder<void>(
                  future: _ensureDevPreviewSeed(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Scaffold(
                        backgroundColor: Colors.transparent,
                        body: Center(
                          child: CircularProgressIndicator(
                            color: KratosTheme.acidLime,
                          ),
                        ),
                      );
                    }
                    return AppShell(
                      database: _database,
                      userId: _devPreviewUserId,
                      initialTabIndex: 3,
                    );
                  },
                );
              }
              if (previewKey == 'ideas' ||
                  uri.fragment.contains('preview=ideas')) {
                var themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return FutureBuilder<void>(
                  future: _ensureDevPreviewSeed(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Scaffold(
                        backgroundColor: Colors.transparent,
                        body: Center(
                          child: CircularProgressIndicator(
                            color: KratosTheme.acidLime,
                          ),
                        ),
                      );
                    }
                    return AppShell(
                      database: _database,
                      userId: _devPreviewUserId,
                      initialTabIndex: 4,
                    );
                  },
                );
              }
              if (previewKey == 'due_today' ||
                  uri.fragment.contains('preview=due_today')) {
                var themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return FutureBuilder<void>(
                  future: _ensureDevPreviewSeed(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Scaffold(
                        backgroundColor: Colors.transparent,
                        body: Center(
                          child: CircularProgressIndicator(
                            color: KratosTheme.acidLime,
                          ),
                        ),
                      );
                    }
                    return DueTodayScreen(
                      database: _database,
                      ownerId: _devPreviewUserId,
                    );
                  },
                );
              }
              if (previewKey == 'levels' ||
                  uri.fragment.contains('preview=levels')) {
                var themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return FutureBuilder<void>(
                  future: _ensureDevPreviewSeed(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Scaffold(
                        backgroundColor: Colors.transparent,
                        body: Center(
                          child: CircularProgressIndicator(
                            color: KratosTheme.acidLime,
                          ),
                        ),
                      );
                    }
                    return LevelsDashboardScreen(
                      database: _database,
                      ownerId: _devPreviewUserId,
                    );
                  },
                );
              }
              if (previewKey == 'projects' ||
                  uri.fragment.contains('preview=projects')) {
                var themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return FutureBuilder<void>(
                  future: _ensureDevPreviewSeed(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Scaffold(
                        backgroundColor: Colors.transparent,
                        body: Center(
                          child: CircularProgressIndicator(
                            color: KratosTheme.acidLime,
                          ),
                        ),
                      );
                    }
                    return ProjectsScreen(
                      database: _database,
                      ownerId: _devPreviewUserId,
                    );
                  },
                );
              }
              if (previewKey == 'life_areas' ||
                  uri.fragment.contains('preview=life_areas')) {
                var themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return FutureBuilder<void>(
                  future: _ensureDevPreviewSeed(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Scaffold(
                        backgroundColor: Colors.transparent,
                        body: Center(
                          child: CircularProgressIndicator(
                            color: KratosTheme.acidLime,
                          ),
                        ),
                      );
                    }
                    return LifeAreasScreen(
                      database: _database,
                      ownerId: _devPreviewUserId,
                    );
                  },
                );
              }
              if (previewKey == 'skills_registry' ||
                  uri.fragment.contains('preview=skills_registry')) {
                var themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return FutureBuilder<void>(
                  future: _ensureDevPreviewSeed(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Scaffold(
                        backgroundColor: Colors.transparent,
                        body: Center(
                          child: CircularProgressIndicator(
                            color: KratosTheme.acidLime,
                          ),
                        ),
                      );
                    }
                    return SkillsRegistryScreen(
                      database: _database,
                      ownerId: _devPreviewUserId,
                    );
                  },
                );
              }
              if (previewKey == 'wave05' ||
                  previewKey == 'xp_distribution' ||
                  uri.fragment.contains('preview=wave05') ||
                  uri.fragment.contains('preview=xp_distribution')) {
                final themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return const Wave05XpDistributionStorybookScreen();
              }
              if (previewKey == 'wave06' ||
                  previewKey == 'xp_progress' ||
                  uri.fragment.contains('preview=wave06') ||
                  uri.fragment.contains('preview=xp_progress')) {
                final themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return const Wave06XpProgressStorybookScreen();
              }
              if (previewKey == 'wave07' ||
                  previewKey == 'radar' ||
                  previewKey == 'life_areas_radar' ||
                  uri.fragment.contains('preview=wave07') ||
                  uri.fragment.contains('preview=radar') ||
                  uri.fragment.contains('preview=life_areas_radar')) {
                final themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return const Wave07LifeAreasRadarStorybookScreen();
              }
              if (previewKey == 'wave08' ||
                  previewKey == 'top_skills' ||
                  previewKey == 'skills' ||
                  uri.fragment.contains('preview=wave08') ||
                  uri.fragment.contains('preview=top_skills')) {
                final themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return const Wave08TopSkillsStorybookScreen();
              }
              if (previewKey == 'wave09' ||
                  previewKey == 'this_week' ||
                  previewKey == 'daily_activity' ||
                  uri.fragment.contains('preview=wave09') ||
                  uri.fragment.contains('preview=this_week') ||
                  uri.fragment.contains('preview=daily_activity')) {
                final themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return const Wave09DailyActivityStorybookScreen();
              }
              if (previewKey == 'focus_time' ||
                  previewKey == 'focus' ||
                  uri.fragment.contains('preview=focus_time') ||
                  uri.fragment.contains('preview=focus')) {
                final themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return const FocusTimeStorybookScreen();
              }
              if (previewKey == 'calendar' ||
                  previewKey == 'wave10' ||
                  uri.fragment.contains('preview=calendar') ||
                  uri.fragment.contains('preview=wave10')) {
                final themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return FutureBuilder<void>(
                  future: _ensureDevPreviewSeed(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Scaffold(
                        backgroundColor: Colors.transparent,
                        body: Center(
                          child: CircularProgressIndicator(
                            color: KratosTheme.acidLime,
                          ),
                        ),
                      );
                    }
                    return CalendarScreen(
                      database: _database,
                      ownerId: _devPreviewUserId,
                    );
                  },
                );
              }
              if (previewKey == 'insights' ||
                  previewKey == 'positive_trends' ||
                  uri.fragment.contains('preview=insights') ||
                  uri.fragment.contains('preview=positive_trends')) {
                final themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return const InsightsStorybookScreen();
              }
              if (previewKey == 'insights_full' ||
                  uri.fragment.contains('preview=insights_full')) {
                final themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return InsightsScreen(
                  database: _database,
                  ownerId: 'demo-user-insights',
                );
              }
              if (previewKey == 'wave12' ||
                  uri.fragment.contains('preview=wave12')) {
                final themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return const Wave12SettingsStorybookScreen();
              }
              if (previewKey == 'settings' ||
                  uri.fragment.contains('preview=settings')) {
                final themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return SettingsScreen(
                  database: _database,
                  ownerId: 'demo-user-wave12',
                );
              }
              if (previewKey == 'wave13' ||
                  uri.fragment.contains('preview=wave13')) {
                final themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return const Wave13ProfileStorybookScreen();
              }
              if (previewKey == 'profile' ||
                  uri.fragment.contains('preview=profile')) {
                final themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return FutureBuilder<void>(
                  future: _ensureDevPreviewSeed(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Scaffold(
                        backgroundColor: Colors.transparent,
                        body: Center(
                          child: CircularProgressIndicator(
                            color: KratosTheme.acidLime,
                          ),
                        ),
                      );
                    }
                    return ProfileScreen(
                      database: _database,
                      userId: _devPreviewUserId,
                      previewDialog: uri.queryParameters['dialog'],
                    );
                  },
                );
              }
              return StreamBuilder<AuthState>(
                stream: _authService.authStateStream,
                initialData: _authService.currentState,
                builder: (context, snapshot) {
                  final state = snapshot.data;

                  if (state is AuthAuthenticated) {
                    final userId = state.user.id.value;
                    final isDevUser = userId.startsWith('usr_seed_dev') ||
                        userId == 'usr_seed_dev_01';

                    if (isDevUser) {
                      if (_checkedUserId != userId) {
                        _loadOnboarding(userId);
                      }
                      return AppShell(
                        database: _database,
                        userId: userId,
                        syncTransport: _authService is SupabaseAuthService
                            ? SupabaseSyncTransport(
                                supabase.Supabase.instance.client,
                              )
                            : null,
                        onSignOut: () => _authService.signOut(),
                      );
                    }

                    if (_checkedUserId != state.user.id.value &&
                        !_checkingOnboarding) {
                      _loadOnboarding(state.user.id.value);
                      return const Scaffold(
                        backgroundColor: Colors.transparent,
                        body: Center(
                          child: CircularProgressIndicator(
                            color: KratosTheme.acidLime,
                          ),
                        ),
                      );
                    }
                    if (_checkingOnboarding) {
                      return const Scaffold(
                        backgroundColor: Colors.transparent,
                        body: Center(
                          child: CircularProgressIndicator(
                            color: KratosTheme.acidLime,
                          ),
                        ),
                      );
                    }
                    if (!_isOnboarded) {
                      return OnboardingScreen(
                        onComplete:
                            ({
                              required selectedAreaIds,
                              initialGoalTitle,
                              initialGoalXp = 500,
                            }) async {
                              final deviceId = Id.uuidV7();
                              await OnboardingService(_database)
                                  .completeOnboarding(
                                    userId: state.user.id.value,
                                    selectedAreaIds: selectedAreaIds,
                                    initialGoalTitle: initialGoalTitle,
                                    initialGoalXp: initialGoalXp,
                                    deviceId: deviceId.value,
                                    versionHlc: Hlc.now(deviceId).toString(),
                                  );
                              if (mounted) {
                                setState(() {
                                  _isOnboarded = true;
                                  _checkedUserId = state.user.id.value;
                                });
                              }
                            },
                      );
                    }
                    return AppShell(
                      database: _database,
                      userId: state.user.id.value,
                      syncTransport: _authService is SupabaseAuthService
                          ? SupabaseSyncTransport(
                              supabase.Supabase.instance.client,
                            )
                          : null,
                      onSignOut: () => _authService.signOut(),
                    );
                  }

                  if (state is AuthInitializing ||
                      state is AuthAuthenticating) {
                    return const Scaffold(
                      backgroundColor: Colors.transparent,
                      body: Center(
                        child: CircularProgressIndicator(
                          color: KratosTheme.acidLime,
                        ),
                      ),
                    );
                  }

                  // Unauthenticated or AuthError
                  return LoginScreen(
                    authService: _authService,
                    initialError: state is AuthError ? state.message : null,
                    onLoginSuccess: () {
                      // Auth stream will trigger rebuild into AppShell
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
