// ignore_for_file: public_member_api_docs
// Wave 15: Auth Domain Models.
// Pure Dart representation of user session and authentication states.

import '../../../domain/ids.dart';

enum AuthMethod {
  google,
  email,
  developerMock,
}

class KratosUser {
  final Id id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final AuthMethod method;
  final DateTime createdAt;

  const KratosUser({
    required this.id,
    required this.email,
    required this.method,
    required this.createdAt,
    this.displayName,
    this.avatarUrl,
  });

  /// Factory for developer mock user during dev/testing.
  factory KratosUser.devMock({
    String id = 'usr_seed_dev_01',
    String email = 'dev@kratos.internal',
    String displayName = 'Dev Operative',
  }) {
    return KratosUser(
      id: Id(id),
      email: email,
      displayName: displayName,
      method: AuthMethod.developerMock,
      createdAt: DateTime.now().toUtc(),
    );
  }
}

sealed class AuthState {
  const AuthState();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthLoading extends AuthState {
  final String? message;
  const AuthLoading([this.message]);
}

class AuthAuthenticated extends AuthState {
  final KratosUser user;
  const AuthAuthenticated(this.user);
}

class AuthError extends AuthState {
  final String message;
  final Object? cause;
  const AuthError(this.message, [this.cause]);
}
