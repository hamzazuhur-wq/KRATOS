import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/features/auth/domain/auth_models.dart';
import 'package:kratos_app/features/auth/domain/auth_service.dart';
import 'package:kratos_app/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('cancelled OTP result cannot overwrite a newer email attempt', (
    tester,
  ) async {
    final auth = _ControlledAuthService();
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authService: auth, onLoginSuccess: () {}),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'a@example.com');
    await tester.tap(find.text('Continue with Email'));
    await tester.pump();
    expect(find.text('Cancel and change email'), findsOneWidget);
    expect(auth.requestedEmails, ['a@example.com']);

    await tester.tap(find.text('Cancel and change email'));
    await tester.pump();
    expect(find.text('Continue with Email'), findsOneWidget);
    expect(auth.cancellations, 1);

    await tester.enterText(find.byType(TextField).first, 'b@example.com');
    await tester.tap(find.text('Continue with Email'));
    await tester.pump();
    expect(auth.requestedEmails, ['a@example.com', 'b@example.com']);

    auth.requests[0].completeError(AuthFailure('Old mailbox failed.'));
    await tester.pump();
    auth.requests[1].complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.textContaining('Code sent to b@example.com'), findsOneWidget);
    expect(find.textContaining('Old mailbox failed.'), findsNothing);
  });

  testWidgets('send failure stays recoverable and allows switching email', (
    tester,
  ) async {
    final auth = _ControlledAuthService();
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authService: auth, onLoginSuccess: () {}),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'full@example.com');
    await tester.tap(find.text('Continue with Email'));
    await tester.pump();
    auth.requests.single.completeError(AuthFailure('Mailbox is full.'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.textContaining('Mailbox is full.'), findsOneWidget);
    expect(find.text('Change email'), findsOneWidget);
    await tester.ensureVisible(find.text('Change email'));
    await tester.pump();
    await tester.tap(find.text('Change email'));
    await tester.pump();
    expect(find.text('Continue with Email'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'new@example.com');
    await tester.tap(find.text('Continue with Email'));
    await tester.pump();
    expect(auth.requestedEmails.last, 'new@example.com');
  });
}

class _ControlledAuthService implements AuthService {
  final requestedEmails = <String>[];
  final requests = <Completer<void>>[];
  int cancellations = 0;

  @override
  bool get isDevBypassEnabled => false;

  @override
  Stream<AuthState> get authStateStream => const Stream.empty();

  @override
  AuthState get currentState => const AuthUnauthenticated();

  @override
  KratosUser? get currentUser => null;

  @override
  bool get hasValidSession => false;

  @override
  Future<void> signInWithGoogle({String? redirectTo}) async {}

  @override
  Future<void> signInWithEmail(String email, {String? password}) {
    requestedEmails.add(email);
    final request = Completer<void>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<void> resendEmailOtp(String email) => signInWithEmail(email);

  @override
  void cancelEmailOtpAttempt() => cancellations++;

  @override
  Future<void> verifyEmailOtp(String email, String token) async {}

  @override
  Future<void> signInWithDevBypass({
    String? userId,
    String? displayName,
  }) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> signOut() async {}
}
