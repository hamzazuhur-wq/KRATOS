// Wave 18: KRATOS Entrypoint.
// Initializes the local database, auth service, and boots the KratosApp shell.

import 'package:flutter/foundation.dart';
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
        authOptions: FlutterAuthClientOptions(
          // On web, read the OAuth token from the URL fragment (#access_token=…)
          // or query params (?code=…) that Supabase appends after the redirect.
          detectSessionInUri: kIsWeb,
          // Required for PKCE flow on web — stores the code verifier across
          // the OAuth redirect so the session can be exchanged server-side.
          authFlowType: AuthFlowType.pkce,
        ),
      );
      runApp(const KratosApp());
      return;
    } catch (_) {
      runApp(const KratosApp());
      return;
    }
  }
  runApp(const KratosApp());
}
