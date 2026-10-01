import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/domain/ids.dart';
import 'package:kratos_app/features/skills/data/skills_repository.dart';
import 'package:kratos_app/features/skills/presentation/skills_registry_screen.dart';

/// Regression tests for skill & group creation through the real UI.
///
/// Bug report: creating a Skill or a Skill Group from the phone UI appeared to
/// do nothing ("كما لو أني لم أفعل شيئاً").
void main() {
  late AppDatabase db;
  late String ownerId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ownerId = Id.uuidV7().value;
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: ownerId,
            deviceId: 'device_test_001',
            timezone: 'UTC',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
    await db
        .into(db.lifeAreas)
        .insert(
          LifeAreasCompanion.insert(
            id: Id.uuidV7().value,
            ownerId: ownerId,
            name: 'Learning',
            sortOrder: 1,
            versionHlc: '1:0:local',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpRegistry(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: SkillsRegistryScreen(database: db, ownerId: ownerId)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('creating a skill from the registry persists and renders', (
    tester,
  ) async {
    await pumpRegistry(tester);

    await tester.tap(find.text('New Skill'));
    await tester.pumpAndSettle();

    // Scope to the sheet's name field (the screen search box sits behind it).
    final nameField = find.widgetWithText(TextField, 'Skill Name *');
    expect(nameField, findsOneWidget);
    await tester.enterText(nameField, 'Typography');
    await tester.pumpAndSettle();

    await tester.tap(find.text('CREATE SKILL'));
    await tester.pumpAndSettle();

    final persisted = await db.skillsDao.listSkills(ownerId);
    expect(
      persisted.map((skill) => skill.name),
      contains('Typography'),
      reason: 'The skill must be persisted in the local database.',
    );
    expect(
      find.text('Typography'),
      findsWidgets,
      reason: 'The freshly created skill must be rendered in the list.',
    );
  });

  testWidgets('creating a skill group persists and shows up', (tester) async {
    await pumpRegistry(tester);

    await tester.tap(find.byTooltip('Manage groups'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_circle));
    await tester.pumpAndSettle();

    final groupField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    expect(groupField, findsOneWidget);
    await tester.enterText(groupField, 'Creative');
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    final repository = DriftSkillsRepository(db);
    final groups = await repository.listGroups(ownerId, includeArchived: true);
    expect(
      groups.map((group) => group.name),
      contains('Creative'),
      reason: 'The new group must be persisted in the local database.',
    );
  });
}
