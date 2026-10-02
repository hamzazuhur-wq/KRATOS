// KRATOS Authentication Models — Clean Rebuild.
// Represents authenticated user identities and minimal authentication states.

import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import '../../../domain/ids.dart';

enum AuthMethod {
  google,
  email,
  developerMock,
}

/// Representation of an authenticated KRATOS operative.
class KratosUser {
  final Id id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final DateTime? createdAt;
  final AuthMethod method;

  const KratosUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.createdAt,
    this.method = AuthMethod.google,
  });

  /// Extracts user identity directly from Supabase User & OAuth metadata.
  factory KratosUser.fromSupabase(supa.User user) {
    final metadata = user.userMetadata;
    final fullName = metadata?['full_name'] as String?;
    final name = metadata?['name'] as String?;
    final avatar = (metadata?['avatar_url'] ?? metadata?['picture']) as String?;

    final resolvedName = (fullName != null && fullName.trim().isNotEmpty)
        ? fullName.trim()
        : (name != null && name.trim().isNotEmpty)
            ? name.trim()
            : (user.email != null && user.email!.contains('@'))
                ? user.email!.split('@').first
                : 'Operative';

    return KratosUser(
      id: Id(user.id),
      email: user.email ?? '',
      displayName: resolvedName,
      avatarUrl: avatar,
      createdAt: DateTime.tryParse(user.createdAt),
      method: AuthMethod.google,
    );
  }

  /// Developer / Test mock factory.
  factory KratosUser.devMock({
    String id = 'usr_seed_dev_01',
    String email = 'dev@kratos.internal',
    String displayName = 'Dev Operative',
    String? avatarUrl,
    DateTime? createdAt,
    AuthMethod method = AuthMethod.developerMock,
  }) {
    return KratosUser(
      id: Id(id),
      email: email,
      displayName: displayName,
      avatarUrl: avatarUrl,
      createdAt: createdAt,
      method: method,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KratosUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          displayName == other.displayName &&
          avatarUrl == other.avatarUrl &&
          createdAt == other.createdAt &&
          method == other.method;

  @override
  int get hashCode =>
      Object.hash(id, email, displayName, avatarUrl, createdAt, method);
}

/// Minimal authentication states:
/// Initializing -> Authenticating -> Authenticated / Unauthenticated / Error.
sealed class AuthState {
  const AuthState();
}

/// App is booting, restoring persisted session or exchanging deep link.
class AuthInitializing extends AuthState {
  const AuthInitializing();
}

/// OAuth handshake or authentication in progress.
class AuthAuthenticating extends AuthState {
  const AuthAuthenticating();
}

/// Active valid Supabase session exists.
class AuthAuthenticated extends AuthState {
  final KratosUser user;
  const AuthAuthenticated(this.user);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthAuthenticated &&
          runtimeType == other.runtimeType &&
          user == other.user;

  @override
  int get hashCode => user.hashCode;
}

/// No active session.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Authentication failure occurred.
class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthError &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}

/// Result returned after attempting account creation.
class AuthSignUpResult {
  final bool requiresEmailVerification;
  final String email;
  final KratosUser? user;

  const AuthSignUpResult({
    required this.requiresEmailVerification,
    required this.email,
    this.user,
  });
}
