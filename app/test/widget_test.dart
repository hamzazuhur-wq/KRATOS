import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/app/kratos_app.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/auth/data/mock_auth_service.dart';

void main() {
  testWidgets('KRATOS root renders its Material application', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final auth = MockAuthService(autoAuthenticate: false);
    await tester.pumpWidget(KratosApp(database: database, authService: auth));

    expect(find.byType(KratosApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);

    auth.dispose();
    await database.close();
  });
}
