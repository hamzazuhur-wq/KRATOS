import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/levels/data/levels_dashboard_repository.dart';
import 'package:kratos_app/features/levels/presentation/levels_dashboard_screen.dart';
import 'package:kratos_app/features/progression/data/overall_progression_repository.dart';

void main() {
  testWidgets('shows global level one and empty distribution creation action', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: LevelsDashboardScreen(
          database: database,
          ownerId: 'usr_empty',
          entriesStream: Stream.value(const <LevelsDashboardEntry>[]),
          overallStream: Stream.value(OverallProgressionSnapshot.empty()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('LEVELS'), findsOneWidget);
    expect(find.text('BRONZE I'), findsOneWidget);
    expect(find.text('BRONZE'), findsOneWidget);
    expect(find.text('0 XP'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await database.close();
  });
}
