// Wave 18: KratosApp — Root Application Widget with State Routing.
// Manages authentication state, onboarding completion, and Liquid Glass theme.

import 'package:flutter/material.dart';
import '../features/auth/data/mock_auth_service.dart';
import '../features/auth/domain/auth_models.dart';
import '../features/auth/domain/auth_service.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import 'app_shell.dart';
import 'kratos_theme.dart';

class KratosApp extends StatefulWidget {
  final AuthService? authService;

  const KratosApp({super.key, this.authService});

  @override
  State<KratosApp> createState() => _KratosAppState();
}

class _KratosAppState extends State<KratosApp> {
  late final AuthService _authService;
  bool _isOnboarded = true; // Set to true by default for developer convenience

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? MockAuthService(autoAuthenticate: true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KRATOS',
      debugShowCheckedModeBanner: false,
      theme: KratosTheme.darkTheme,
      home: StreamBuilder<AuthState>(
        stream: _authService.authStateStream,
        initialData: _authService.currentState,
        builder: (context, snapshot) {
          final state = snapshot.data;

          if (state is AuthAuthenticated) {
            if (!_isOnboarded) {
              return OnboardingScreen(
                onComplete: ({
                  required selectedAreaIds,
                  initialGoalTitle,
                  initialGoalXp = 500,
                }) async {
                  setState(() => _isOnboarded = true);
                },
              );
            }
            return AppShell(
              onSignOut: () => _authService.signOut(),
            );
          }

          // Unauthenticated or Loading
          return LoginScreen(
            authService: _authService,
            onLoginSuccess: () {
              // Auth stream will trigger rebuild into AppShell
            },
          );
        },
      ),
    );
  }
}
