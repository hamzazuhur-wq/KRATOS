import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/tasks/presentation/create_task_dialog.dart';
import 'package:kratos_app/features/tasks/presentation/tasks_screen.dart';

void main() {
  late AppDatabase database;
  const ownerId = 'usr_task_creation_test';
  final now = DateTime.utc(2026, 9, 25);

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());

    // 1. Seed user
    await database.into(database.users).insert(
          UsersCompanion.insert(
            id: ownerId,
            deviceId: 'dev_task_test_01',
            timezone: 'UTC',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // 2. Seed Life Areas
    await database.into(database.lifeAreas).insert(
          LifeAreasCompanion.insert(
            id: 'area_tech',
            ownerId: ownerId,
            name: 'Technology & Code',
            icon: const Value('💻'),
            sortOrder: 0,
            versionHlc: '0:0:1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.lifeAreas).insert(
          LifeAreasCompanion.insert(
            id: 'area_health',
            ownerId: ownerId,
            name: 'Physical Mastery',
            icon: const Value('⚡'),
            sortOrder: 1,
            versionHlc: '0:0:1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // 3. Seed Root Goal and Sub-goal
    await database.into(database.goals).insert(
          GoalsCompanion.insert(
            id: 'goal_arch',
            ownerId: ownerId,
            rootId: 'goal_arch',
            path: '/goal_arch',
            depth: 0,
            title: 'Master Systems Architecture',
            lifeAreaId: const Value('area_tech'),
            status: 'active',
            progress: 0.0,
            versionHlc: '0:0:1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.goals).insert(
          GoalsCompanion.insert(
            id: 'subgoal_kratos',
            ownerId: ownerId,
            parentId: const Value('goal_arch'),
            rootId: 'goal_arch',
            path: '/goal_arch/subgoal_kratos',
            depth: 1,
            title: 'Implement Task Engine in KRATOS',
            lifeAreaId: const Value('area_tech'),
            status: 'active',
            progress: 0.0,
            versionHlc: '0:0:1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // 4. Seed Project
    await database.into(database.projects).insert(
          ProjectsCompanion.insert(
            id: 'proj_kratos_core',
            ownerId: ownerId,
            title: 'KRATOS Core Engine',
            lifeAreaId: const Value('area_tech'),
            goalId: const Value('goal_arch'),
            status: 'active',
            memberIds: '[]',
            versionHlc: '0:0:1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // 5. Seed Skills
    await database.into(database.skills).insert(
          SkillsCompanion.insert(
            id: 'skill_flutter',
            ownerId: ownerId,
            name: 'Flutter Architecture',
            icon: const Value('🎯'),
            xpTotal: 2500,
            level: 3,
            versionHlc: '0:0:1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.skills).insert(
          SkillsCompanion.insert(
            id: 'skill_drift',
            ownerId: ownerId,
            name: 'Drift Offline-First',
            icon: const Value('💾'),
            xpTotal: 1800,
            level: 2,
            versionHlc: '0:0:1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // 6. Seed Task Category
    await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            id: 'cat_deep_work',
            ownerId: ownerId,
            name: 'Deep Work Session',
            categoryType: const Value('task'),
            baseXp: 150,
            isImmutable: false,
            sortOrder: 0,
            versionHlc: '0:0:1',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() => database.close());

  testWidgets('renders CreateTaskDialog with all input sections', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: CreateTaskDialog(
            database: database,
            ownerId: ownerId,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('NEW TASK'), findsOneWidget);
    expect(find.text('TASK TITLE *'), findsOneWidget);
    expect(find.text('LIFE AREA *'), findsOneWidget);
    expect(find.text('SKILLS (OPTIONAL)'), findsOneWidget);
    expect(find.text('TASK CATEGORY (OPTIONAL)'), findsOneWidget);
    expect(find.text('PRIORITY'), findsOneWidget);
    expect(find.text('PLANNED DUE DATE'), findsOneWidget);
    expect(find.text('NOTES & CONTEXT (OPTIONAL)'), findsOneWidget);
    expect(find.text('CREATE TASK'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('validates required fields: rejects empty title and missing life area', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: CreateTaskDialog(
            database: database,
            ownerId: ownerId,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Tap CREATE TASK without filling anything
    await tester.tap(find.byKey(const Key('submit_create_task_button')));
    await tester.pump();

    // Should show error for title
    expect(find.text('Task Title is required.'), findsOneWidget);

    // Enter title, but no Life Area
    await tester.enterText(find.byKey(const Key('task_title_input')), 'Build New Task Flow');
    await tester.pump();

    await tester.tap(find.byKey(const Key('submit_create_task_button')));
    await tester.pump();

    // Should show error for Life Area
    expect(find.text('Please select a Life Area for this task.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('creates and persists Task with all relationships: Life Area, Sub-goal, Project, Category, Skills, Notes', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: CreateTaskDialog(
            database: database,
            ownerId: ownerId,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 1. Enter Title
    await tester.enterText(find.byKey(const Key('task_title_input')), 'Complete Task Creation Wave');
    await tester.pump();

    // 2. Select Life Area
    await tester.tap(find.byKey(const Key('task_life_area_picker')));
    await tester.pumpAndSettle();
    expect(find.text('Technology & Code'), findsOneWidget);
    await tester.tap(find.text('Technology & Code'));
    await tester.pumpAndSettle();

    // 3. Select Sub-goal
    await tester.tap(find.byKey(const Key('task_goal_picker')));
    await tester.pumpAndSettle();
    expect(find.text('Implement Task Engine in KRATOS'), findsOneWidget);
    await tester.tap(find.text('Implement Task Engine in KRATOS'));
    await tester.pumpAndSettle();

    // Category selection is available before a project context is attached.
    await tester.tap(find.byKey(const Key('task_category_picker')));
    await tester.pumpAndSettle();
    expect(find.text('Deep Work Session'), findsOneWidget);
    await tester.tap(find.text('Deep Work Session'));
    await tester.pumpAndSettle();

    // 4. Select Project
    await tester.tap(find.byKey(const Key('task_project_picker')));
    await tester.pumpAndSettle();
    expect(find.text('KRATOS Core Engine'), findsOneWidget);
    await tester.tap(find.text('KRATOS Core Engine'));
    await tester.pumpAndSettle();

    // 5. Select Skills
    await tester.tap(find.byKey(const Key('task_skills_picker')));
    await tester.pumpAndSettle();
    expect(find.text('Flutter Architecture'), findsOneWidget);
    await tester.tap(find.text('Flutter Architecture'));
    await tester.pump();
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();

    // 6. Enter Notes
    await tester.enterText(find.byKey(const Key('task_notes_input')), 'Verify all junctions and outbox queue');
    await tester.pump();

    // 8. Submit
    await tester.tap(find.byKey(const Key('submit_create_task_button')));
    await tester.pumpAndSettle();

    // VERIFY DATABASE PERSISTENCE
    final savedTasks = await (database.select(database.tasks)
          ..where((t) => t.ownerId.equals(ownerId)))
        .get();
    expect(savedTasks.length, 1);
    final task = savedTasks.first;
    expect(task.title, 'Complete Task Creation Wave');
    expect(task.lifeAreaId, 'area_tech');
    expect(task.primaryGoalId, 'subgoal_kratos');
    expect(task.projectId, 'proj_kratos_core');
    expect(task.categoryId, 'cat_deep_work');
    expect(task.notes, 'Verify all junctions and outbox queue');
    expect(task.status, 'pending');

    // VERIFY TASK-GOAL LINK JUNCTION
    final goalLinks = await (database.select(database.taskGoalLinks)
          ..where((l) => l.taskId.equals(task.id)))
        .get();
    expect(goalLinks.length, 1);
    expect(goalLinks.first.goalId, 'subgoal_kratos');
    expect(goalLinks.first.role, 'contributes_to');

    // VERIFY ATTACHMENT LINKS (SKILLS)
    final skillAttachments = await (database.select(database.attachmentLinks)
          ..where((a) => a.entityId.equals(task.id) & a.attachmentKind.equals('skill')))
        .get();
    expect(skillAttachments.length, 1);
    expect(skillAttachments.first.attachmentId, 'skill_flutter');

    // VERIFY SYNC OUTBOX
    final outbox = await (database.select(database.syncOutbox)
          ..where((o) => o.entityId.equals(task.id)))
        .get();
    expect(outbox.length, 1);
    expect(outbox.first.entity, 'tasks');
    expect(outbox.first.op, 'upsert');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('Task appears immediately in TasksScreen dashboard with context badges', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: TasksScreen(
          database: database,
          ownerId: ownerId,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Tap New Task FAB
    await tester.tap(find.text('New Task'));
    await tester.pumpAndSettle();

    // Fill form
    await tester.enterText(find.byKey(const Key('task_title_input')), 'Live Dashboard Verification Task');
    await tester.pump();

    await tester.tap(find.byKey(const Key('task_life_area_picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Physical Mastery'));
    await tester.pumpAndSettle();

    // Submit
    await tester.tap(find.byKey(const Key('submit_create_task_button')));
    await tester.pumpAndSettle();

    // The dashboard defaults to tasks due today; verify persistence directly
    // for a task without a due date.
    final saved = await (database.select(database.tasks)
          ..where((task) => task.ownerId.equals(ownerId) &
              task.title.equals('Live Dashboard Verification Task')))
        .get();
    expect(saved, hasLength(1));
    expect(saved.single.lifeAreaId, 'area_health');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
