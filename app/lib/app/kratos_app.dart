// Wave 18: KratosApp — Root Application Widget with State Routing.
// Manages authentication state, onboarding completion, and Liquid Glass theme.

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
import 'kratos_motion.dart';
import 'kratos_theme.dart';
import 'kratos_visuals.dart';

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
  bool _showOpening = true;
  String? _checkedUserId;
  bool _checkingOnboarding = false;

  @override
  void initState() {
    super.initState();
    _database = widget.database ?? AppDatabase();
    _authService = widget.authService ?? _createRuntimeAuth();
  }

  Future<void> _loadOnboarding(String userId) async {
    setState(() => _checkingOnboarding = true);
    try {
      final onboardingService = OnboardingService(_database);
      var completed = await onboardingService
          .isCompleted(userId)
          .timeout(const Duration(seconds: 12));
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
      // ignore: avoid_print
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
    return MaterialApp(
      title: 'KRATOS',
      debugShowCheckedModeBanner: false,
      theme: KratosTheme.darkTheme,
      builder: (context, child) =>
          KratosTextReveal(child: child ?? const SizedBox.shrink()),
      home: Stack(
        fit: StackFit.expand,
        children: [
          StreamBuilder<AuthState>(
            stream: _authService.authStateStream,
            initialData: _authService.currentState,
            builder: (context, snapshot) {
              final state = snapshot.data;

              print('[AUTH-TRACE] KratosApp stream builder state: AuthAuthenticated');
              if (state is AuthAuthenticated) {
                if (_checkedUserId != state.user.id.value &&
                    !_checkingOnboarding) {
                  _loadOnboarding(state.user.id.value);
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (_checkingOnboarding) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
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

              if (state is AuthLoading) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              // Unauthenticated
              print('[AUTH-TRACE] KratosApp returning LoginScreen');
              return LoginScreen(
                authService: _authService,
                onLoginSuccess: () {
                  // Auth stream will trigger rebuild into AppShell
                },
              );
            },
          ),
          if (_showOpening)
            KratosOpeningSequence(
              onFinished: () {
                if (mounted) setState(() => _showOpening = false);
              },
            ),
        ],
      ),
    );
  }
}

