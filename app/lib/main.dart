// Wave 18: KRATOS Entrypoint.
// Initializes the local database, auth service, and boots the KratosApp shell.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/kratos_app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  if (config.hasSupabaseConfiguration) {
    try {
      await Supabase.initialize(
        url: config.supabaseUrl,
        publishableKey: config.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          // Detect sessions on both web (URL fragment/query) and mobile (deep link).
          detectSessionInUri: true,
          // Required for PKCE flow across web and mobile.
          authFlowType: AuthFlowType.pkce,
        ),
      );
      runApp(const KratosApp());
      return;
    } catch (e, st) {
      debugPrint('[KRATOS] Supabase initialization failed: $e\n$st');
      runApp(const KratosApp());
      return;
    }
  }
  runApp(const KratosApp());
}
