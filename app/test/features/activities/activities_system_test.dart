import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/activities/data/activity_dashboard_repository.dart';
import 'package:kratos_app/features/activities/presentation/activities_screen.dart';
import 'package:kratos_app/features/activities/presentation/activity_detail_screen.dart';
import 'package:kratos_app/features/activities/presentation/create_activity_dialog.dart';
import 'package:kratos_app/features/categories/data/categories_dao.dart';
import 'package:kratos_app/features/sessions/domain/global_active_session_controller.dart';
import 'package:kratos_app/features/sessions/presentation/global_active_session_mini_player.dart';

void main() {
  late AppDatabase db;
  const ownerId = 'user_activity_test_001';
  const lifeAreaId = 'la_learning_001';
  const categoryId = 'cat_act_knowledge_001';
  const skillId1 = 'skill_english_001';
  const skillId2 = 'skill_focus_002';

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.hamza.kratos/focus_session'),
          (call) async => true,
        );

    db = AppDatabase.forTesting(NativeDatabase.memory());

    // 1. Seed user
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: ownerId,
            email: const drift.Value('tester@kratos.io'),
            displayName: const drift.Value('Kratos Operative'),
            deviceId: 'device_test_001',
            timezone: 'UTC',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );

    // 2. Seed Life Area
    await db
        .into(db.lifeAreas)
        .insert(
          LifeAreasCompanion.insert(
            id: lifeAreaId,
            ownerId: ownerId,
            name: 'Learning & Growth',
            sortOrder: 1,
            versionHlc: '0:0:0',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );

    // 3. Seed Activity Category
    final catDao = CategoriesDao(db);
    await catDao.createCategory(
      category: CategoriesCompanion.insert(
        id: categoryId,
        ownerId: ownerId,
        name: 'Knowledge',
        categoryType: const drift.Value('activity'),
        baseXp: 10,
        isImmutable: false,
        sortOrder: 0,
        versionHlc: '0:0:0',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
      actions: [],
    );

    // 4. Seed Skills
    await db
        .into(db.skills)
        .insert(
          SkillsCompanion.insert(
            id: skillId1,
            ownerId: ownerId,
            name: 'English Comprehension',
            level: 1,
            xpTotal: 0,
            versionHlc: '0:0:0',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
    await db
        .into(db.skills)
        .insert(
          SkillsCompanion.insert(
            id: skillId2,
            ownerId: ownerId,
            name: 'Deep Focus',
            level: 2,
            xpTotal: 100,
            versionHlc: '0:0:0',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  });

  tearDown(() async {
    GlobalActiveSessionController().discard();
    await db.close();
  });

  group('Wave 3: New Activity Creation & Validation', () {
    testWidgets('renders CreateActivityDialog with all form fields', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateActivityDialog(database: db, ownerId: ownerId),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('NEW ACTIVITY'), findsOneWidget);
      expect(find.text('ACTIVITY NAME *'), findsOneWidget);
      expect(find.text('LIFE AREA *'), findsOneWidget);
      expect(find.text('ACTIVITY CATEGORY'), findsOneWidget);
      expect(find.text('TARGET DURATION (OPTIONAL)'), findsOneWidget);
      expect(find.text('Create Activity'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('validates required fields: rejects empty name', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateActivityDialog(database: db, ownerId: ownerId),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Create Activity without entering name
      await tester.tap(find.text('Create Activity'));
      await tester.pumpAndSettle();

      expect(find.text('Activity name is required'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    test('creates and persists Activity with Life Area, Category, Skills, Target Duration & Outbox', () async {
      final repo = ActivityDashboardRepository(db);

      final actId = await repo.createActivity(
        ownerId: ownerId,
        name: 'Reading Fiction & History',
        lifeAreaId: lifeAreaId,
        categoryId: categoryId,
        description: 'Read 30-45 minutes of non-fiction book daily',
        targetDurationMinutes: 45,
        skillIds: [skillId1, skillId2],
      );

      // Verify row in Activities table
      final row = await (db.select(
        db.activities,
      )..where((a) => a.id.equals(actId))).getSingle();
      expect(row.name, 'Reading Fiction & History');
      expect(row.lifeAreaId, lifeAreaId);
      expect(row.categoryId, categoryId);
      expect(row.targetDurationMinutes, 45);
      expect(row.description, 'Read 30-45 minutes of non-fiction book daily');

      // Verify attachment links for skills
      final links = await (db.select(
        db.attachmentLinks,
      )..where((l) => l.entityId.equals(actId))).get();
      expect(links.length, 2);
      expect(links.map((l) => l.attachmentId).toSet(), {skillId1, skillId2});

      // Verify sync outbox
      final outbox = await (db.select(
        db.syncOutbox,
      )..where((o) => o.entityId.equals(actId))).getSingle();
      expect(outbox.entity, 'activities');
      expect(outbox.op, 'upsert');
      final payload = jsonDecode(outbox.payloadJson) as Map<String, dynamic>;
      expect(payload['name'], 'Reading Fiction & History');
      expect(payload['target_duration_minutes'], 45);
    });
  });

  group('Wave 4 & 5: Activity Dashboard & Activity Detail', () {
    testWidgets(
      'Activity Dashboard displays created activity and filters properly',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = ActivityDashboardRepository(db);
        await repo.createActivity(
          ownerId: ownerId,
          name: 'Weightlifting & Calisthenics',
          lifeAreaId: lifeAreaId,
          categoryId: categoryId,
          targetDurationMinutes: 60,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ActivitiesScreen(database: db, ownerId: ownerId),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        expect(find.text('ACTIVITIES'), findsOneWidget);
        expect(find.text('Weightlifting & Calisthenics'), findsOneWidget);
        expect(find.text('Learning & Growth'), findsWidgets);
        expect(find.text('Knowledge'), findsWidgets);
        expect(find.text('Target 1h'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Activity Detail renders header, time capture card, metrics, and recent sessions',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = ActivityDashboardRepository(db);
        final actId = await repo.createActivity(
          ownerId: ownerId,
          name: 'Coding Kata Practice',
          lifeAreaId: lifeAreaId,
          categoryId: categoryId,
          description: 'Practice algorithms and Flutter architecture',
          targetDurationMinutes: 45,
          skillIds: [skillId1],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ActivityDetailScreen(
              database: db,
              ownerId: ownerId,
              activityId: actId,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        expect(find.text('ACTIVITY DETAIL'), findsOneWidget);
        expect(find.text('Coding Kata Practice'), findsOneWidget);
        expect(find.text('TIME CAPTURE'), findsOneWidget);
        expect(find.text('START TIMER'), findsOneWidget);
        expect(find.text('ACTIVITY METRICS & STATS'), findsOneWidget);
        expect(find.text('RECENT SESSIONS'), findsOneWidget);
        expect(find.text('⚡ English Comprehension'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  });

  group('Wave 6 & 7: Universal Global Active Session & Time Capture', () {
    test('Session lifecycle: start, pause, resume, and critical completion test (Target 45m, Actual 31m)', () async {
      final repo = ActivityDashboardRepository(db);
      final actId = await repo.createActivity(
        ownerId: ownerId,
        name: 'Reading Philosophy',
        lifeAreaId: lifeAreaId,
        categoryId: categoryId,
        targetDurationMinutes: 45,
      );

      final controller = GlobalActiveSessionController();
      controller.bindDatabase(db, ownerId);

      // 1. Start Session with simulated 31 minutes start
      final thirtyOneMinsAgo = DateTime.now().toUtc().subtract(
        const Duration(minutes: 31),
      );
      controller.startSession(
        entityType: 'activity',
        entityId: actId,
        title: 'Reading Philosophy',
        lifeAreaId: lifeAreaId,
        lifeAreaName: 'Learning & Growth',
        categoryName: 'Knowledge',
        targetDurationMinutes: 45,
        startedAt: thirtyOneMinsAgo,
      );

      expect(controller.hasActiveSession, isTrue);
      expect(controller.currentState?.title, 'Reading Philosophy');
      expect(controller.currentState?.targetDurationSeconds, 45 * 60);

      // 2. Pause Session
      controller.pauseSession();
      expect(controller.currentState?.isPaused, isTrue);

      // 3. Resume Session
      controller.resumeSession();
      expect(controller.currentState?.isPaused, isFalse);

      // 4. Complete Session with exact 31m tracked
      final result = await controller.completeSession(
        database: db,
        ownerId: ownerId,
        note: 'Completed 31m philosophical reading sprint',
      );

      expect(result, isNotNull);
      expect(controller.hasActiveSession, isFalse);

      final sessId = result!['sessionId'] as String;

      // Verify Session row in SQLite
      final sessRow = await (db.select(
        db.sessions,
      )..where((s) => s.id.equals(sessId))).getSingle();
      expect(sessRow.activityId, actId);
      expect(sessRow.lifeAreaId, lifeAreaId);
      expect(sessRow.endedAt, isNotNull);
      expect(sessRow.durationMs! >= 1860000, isTrue); // 31 minutes in ms

      // Verify sync outbox
      final outbox = await (db.select(
        db.syncOutbox,
      )..where((o) => o.entityId.equals(sessId))).getSingle();
      expect(outbox.entity, 'sessions');
      expect(outbox.op, 'upsert');

      // Verify XP was written through XP Ledger
      final ledgerRows = await (db.select(
        db.xpLedger,
      )..where((l) => l.sourceId.equals(sessId))).get();
      expect(ledgerRows.isNotEmpty, isTrue);
      expect(ledgerRows.first.action, 'focus_completed');
      expect(ledgerRows.first.points, greaterThan(0));
    });

    testWidgets(
      'GlobalActiveSessionMiniPlayer renders active state and controls',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = GlobalActiveSessionController();
        controller.bindDatabase(db, ownerId);

        controller.startSession(
          entityType: 'activity',
          entityId: 'act_temp_01',
          title: 'Deep Meditation',
          lifeAreaId: lifeAreaId,
          lifeAreaName: 'Mental Health',
          targetDurationMinutes: 30,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  const Center(child: Text('Home Screen')),
                  GlobalActiveSessionMiniPlayer(database: db, ownerId: ownerId),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('DEEP MEDITATION'), findsOneWidget);
        expect(find.text('Mental Health'), findsOneWidget);
        expect(find.text('Pause'), findsOneWidget);
        expect(find.text('Complete'), findsOneWidget);

        // Tap Pause
        await tester.tap(find.text('Pause'));
        await tester.pumpAndSettle();

        expect(find.text('Resume'), findsOneWidget);

        controller.discard();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  });
}
