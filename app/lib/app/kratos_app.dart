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
import '../features/preview/wave12_settings_storybook_screen.dart';
import '../features/preview/wave10_calendar_storybook_screen.dart';
import '../features/preview/wave13_profile_storybook_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

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

  Future<void> _loadOnboarding(String userId) async {
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
              .select('id, name, description, color, icon, sort_order, version_hlc, created_at, updated_at')
              .eq('owner_id', userId);

          if (remoteLifeAreas.isNotEmpty) {
            completed = true;

            final now = DateTime.now().toUtc();
            await _database.into(_database.users).insertOnConflictUpdate(
              UsersCompanion.insert(
                id: userId,
                deviceId: Id.uuidV7().value,
                timezone: 'UTC',
                createdAt: now,
                updatedAt: now,
              ),
            );

            final localAreas = await (_database.select(_database.lifeAreas)
              ..where((row) => row.ownerId.equals(userId))).get();
            if (localAreas.isEmpty) {
              for (final area in remoteLifeAreas) {
                await _database.into(_database.lifeAreas).insertOnConflictUpdate(
                  LifeAreasCompanion(
                    id: drift.Value(area['id'] as String),
                    ownerId: drift.Value(userId),
                    name: drift.Value(area['name'] as String),
                    description: drift.Value(area['description'] as String? ?? ''),
                    color: drift.Value(area['color'] as String? ?? '#CCFF00'),
                    icon: drift.Value(area['icon'] as String? ?? 'target'),
                    sortOrder: drift.Value(area['sort_order'] as int? ?? 0),
                    versionHlc: drift.Value(area['version_hlc'] as String? ?? '0'),
                    createdAt: drift.Value(DateTime.tryParse(area['created_at']?.toString() ?? '') ?? now),
                    updatedAt: drift.Value(DateTime.tryParse(area['updated_at']?.toString() ?? '') ?? now),
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
          builder: (context, child) => child ?? const SizedBox.shrink(),
          home: Builder(
            builder: (context) {
              final uri = Uri.base;
              final previewKey = uri.queryParameters['preview'];
              if (previewKey == 'wave10' || uri.fragment.contains('preview=wave10')) {
                return const Wave10CalendarStorybookScreen();
              }
              if (previewKey == 'wave12' || uri.fragment.contains('preview=wave12')) {
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
              if (previewKey == 'settings' || uri.fragment.contains('preview=settings')) {
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
              if (previewKey == 'wave13' || uri.fragment.contains('preview=wave13')) {
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
              if (previewKey == 'profile' || uri.fragment.contains('preview=profile')) {
                final themeParam = uri.queryParameters['theme'];
                if (themeParam == 'light' || themeParam == 'dark') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    KratosThemeController.instance.setThemeMode(
                      themeParam == 'light' ? ThemeMode.light : ThemeMode.dark,
                    );
                  });
                }
                return ProfileScreen(
                  database: _database,
                  userId: 'demo-user-wave13',
                  previewDialog: uri.queryParameters['dialog'],
                );
              }
              return StreamBuilder<AuthState>(
                stream: _authService.authStateStream,
                initialData: _authService.currentState,
                builder: (context, snapshot) {
          final state = snapshot.data;

          if (state is AuthAuthenticated) {
            if (_checkedUserId != state.user.id.value &&
                !_checkingOnboarding) {
              _loadOnboarding(state.user.id.value);
              return const Scaffold(
                backgroundColor: KratosTheme.volcanic,
                body: Center(
                  child: CircularProgressIndicator(
                    color: KratosTheme.acidLime,
                  ),
                ),
              );
            }
            if (_checkingOnboarding) {
              return const Scaffold(
                backgroundColor: KratosTheme.volcanic,
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
                      await OnboardingService(_database).completeOnboarding(
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
                  ? SupabaseSyncTransport(supabase.Supabase.instance.client)
                  : null,
              onSignOut: () => _authService.signOut(),
            );
          }

          if (state is AuthInitializing || state is AuthAuthenticating) {
            return const Scaffold(
              backgroundColor: KratosTheme.volcanic,
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


