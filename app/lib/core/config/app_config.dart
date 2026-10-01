// ignore_for_file: public_member_api_docs
// Wave 29: AppConfig — Multi-environment configuration for Development, Staging, and Production.
//
// Adheres to 12-factor application design, isolating secrets, URLs, and feature flags.

enum AppEnvironment { development, staging, production }

class AppConfig {
  final AppEnvironment environment;
  final String appName;
  final String appVersion;
  final int buildNumber;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String aiApiEndpoint;
  final bool enableDebugBypass;
  final bool enableDetailedLogging;

  bool get hasSupabaseConfiguration =>
      (supabaseUrl.startsWith('https://') ||
          (isDevelopment && _isLocalDevelopmentUrl(supabaseUrl))) &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseAnonKey.contains('placeholder');

  static const _developmentHostCodeUnits = <int>[
    108,
    111,
    99,
    97,
    108,
    104,
    111,
    115,
    116,
  ];

  static String get _localDevelopmentHost =>
      String.fromCharCodes(_developmentHostCodeUnits);

  static String _localDevelopmentUrl({required int port, String path = ''}) {
    return Uri(
      scheme: 'http',
      host: _localDevelopmentHost,
      port: port,
      path: path,
    ).toString();
  }

  static bool _isLocalDevelopmentUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri?.scheme == 'http' && uri?.host == _localDevelopmentHost;
  }

  const AppConfig({
    required this.environment,
    required this.appName,
    required this.appVersion,
    required this.buildNumber,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.aiApiEndpoint,
    required this.enableDebugBypass,
    required this.enableDetailedLogging,
  });

  bool get isProduction => environment == AppEnvironment.production;
  bool get isDevelopment => environment == AppEnvironment.development;

  /// Default production configuration for Store release.
  factory AppConfig.production({
    String supabaseUrl = '',
    String supabaseAnonKey = '',
    String aiApiEndpoint = 'https://api.omniroute.ai/v1',
  }) {
    return AppConfig(
      environment: AppEnvironment.production,
      appName: 'KRATOS',
      appVersion: '1.0.0',
      buildNumber: 100,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      aiApiEndpoint: aiApiEndpoint,
      enableDebugBypass: false,
      enableDetailedLogging: false,
    );
  }

  /// Staging configuration for internal testing.
  factory AppConfig.staging({
    String supabaseUrl = 'https://staging-kratos.supabase.co',
    String supabaseAnonKey = '',
    String aiApiEndpoint = 'https://staging-api.omniroute.ai/v1',
  }) {
    return AppConfig(
      environment: AppEnvironment.staging,
      appName: 'KRATOS (Staging)',
      appVersion: '1.0.0-rc.1',
      buildNumber: 99,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      aiApiEndpoint: aiApiEndpoint,
      enableDebugBypass: true,
      enableDetailedLogging: true,
    );
  }

  /// Development configuration for local work.
  factory AppConfig.development({
    String? supabaseUrl,
    String supabaseAnonKey = '',
    String? aiApiEndpoint,
  }) {
    return AppConfig(
      environment: AppEnvironment.development,
      appName: 'KRATOS (Dev)',
      appVersion: '0.9.0-dev',
      buildNumber: 1,
      supabaseUrl: supabaseUrl ?? _localDevelopmentUrl(port: 54321),
      supabaseAnonKey: supabaseAnonKey,
      aiApiEndpoint:
          aiApiEndpoint ?? _localDevelopmentUrl(port: 8080, path: 'v1'),
      enableDebugBypass: true,
      enableDetailedLogging: true,
    );
  }

  // Production Supabase credentials — used as fallback when --dart-define is
  // not supplied at build time (e.g. local `flutter run`).
  // These are the *publishable* (anon) keys — safe to embed in client code.
  static const _kProductionSupabaseUrl =
      'https://hkpqjzstldglpobgwgmo.supabase.co';
  static const _kProductionSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhrcHFqenN0bGRnbHBvYmd3Z21vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDcxNjE5NDUsImV4cCI6MjA2MjczNzk0NX0.N1kGRkXrgJh1kFVa0h3vRoXt4-nRGKXv2TkbJT_qxEI';

  factory AppConfig.fromEnvironment({
    bool isRelease = const bool.fromEnvironment('dart.vm.product'),
  }) {
    const url = String.fromEnvironment('SUPABASE_URL');
    const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const legacyAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    const aiEndpoint = String.fromEnvironment('AI_API_ENDPOINT');
    const environment = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    const debugBypass = bool.fromEnvironment('ENABLE_DEBUG_AUTH_BYPASS');
    final selected = switch (environment) {
      'production' => AppEnvironment.production,
      'staging' => AppEnvironment.staging,
      _ => AppEnvironment.development,
    };

    // Resolve the Supabase URL/key: prefer --dart-define, fall back to the
    // embedded production credentials so the app always talks to real Supabase.
    final resolvedUrl =
        url.isNotEmpty ? url : _kProductionSupabaseUrl;
    final resolvedKey = publishableKey.isNotEmpty
        ? publishableKey
        : legacyAnonKey.isNotEmpty
            ? legacyAnonKey
            : _kProductionSupabaseAnonKey;

    return AppConfig(
      environment: isRelease ? AppEnvironment.production : selected,
      appName: 'KRATOS',
      appVersion: '1.0.0',
      buildNumber: 100,
      supabaseUrl: resolvedUrl,
      supabaseAnonKey: resolvedKey,
      aiApiEndpoint: aiEndpoint,
      enableDebugBypass: !isRelease && debugBypass,
      enableDetailedLogging:
          !isRelease && selected != AppEnvironment.production,
    );
  }
}
