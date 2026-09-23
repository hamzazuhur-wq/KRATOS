// ignore_for_file: public_member_api_docs
// Wave 29: AppConfig — Multi-environment configuration for Development, Staging, and Production.
//
// Adheres to 12-factor application design, isolating secrets, URLs, and feature flags.

enum AppEnvironment {
  development,
  staging,
  production,
}

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
    String supabaseUrl = 'https://prod-kratos.supabase.co',
    String supabaseAnonKey = 'prod-anon-key-placeholder',
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
    String supabaseAnonKey = 'staging-anon-key-placeholder',
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
    String supabaseUrl = 'http://localhost:54321',
    String supabaseAnonKey = 'dev-anon-key-placeholder',
    String aiApiEndpoint = 'http://localhost:8080/v1',
  }) {
    return AppConfig(
      environment: AppEnvironment.development,
      appName: 'KRATOS (Dev)',
      appVersion: '0.9.0-dev',
      buildNumber: 1,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      aiApiEndpoint: aiApiEndpoint,
      enableDebugBypass: true,
      enableDetailedLogging: true,
    );
  }
}
