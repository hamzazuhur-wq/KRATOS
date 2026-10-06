import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/app/kratos_theme.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/projects/data/projects_repository.dart';
import 'package:kratos_app/features/projects/presentation/project_detail_screen.dart';
import 'package:kratos_app/features/xp/data/xp_ledger_writer_impl.dart';

void main() {
  testWidgets('renders redesigned ProjectDetailScreen with Manus tokens on desktop', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const ownerId = 'user_preview_01';
    final now = DateTime.now().toUtc();

    await database.into(database.users).insert(
          UsersCompanion.insert(
            id: ownerId,
            deviceId: 'dev_preview',
            displayName: const drift.Value('Operative Leader'),
            timezone: 'UTC',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final repository = ProjectsRepository(
      database: database,
      xpLedgerWriter: DriftXpLedgerWriter(database),
    );

    // Create project using repository
    final projectId = await repository.createProject(
      ownerId: ownerId,
      title: 'Neural Architecture Engine',
      description: 'High-throughput distributed neural synchronization pipeline with deterministic state outbox guarantees.',
      difficulty: 8,
    );

    // Create 2 phases
    final phase1Id = await repository.createPhase(
      ownerId: ownerId,
      projectId: projectId,
      name: 'Phase 01: Core Ingestion Protocol',
      description: 'Establish low-latency UDP packet deserialization and ring buffers.',
      sortOrder: 0,
    );
    final phase2Id = await repository.createPhase(
      ownerId: ownerId,
      projectId: projectId,
      name: 'Phase 02: Consensus Mesh Synchronization',
      description: 'Deploy Raft consensus engine over WebRTC channels with sub-millisecond heartbeat.',
      sortOrder: 1,
    );

    // Seed tasks
    await database.into(database.tasks).insert(
          TasksCompanion.insert(
            id: 'task_01',
            ownerId: ownerId,
            projectId: drift.Value(projectId),
            phaseId: drift.Value(phase1Id),
            title: 'Implement SIMD vector parser',
            status: 'completed',
            priority: 2,
            sortOrder: 0,
            versionHlc: '0000000000000-0000-000000000000',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database.into(database.tasks).insert(
          TasksCompanion.insert(
            id: 'task_02',
            ownerId: ownerId,
            projectId: drift.Value(projectId),
            phaseId: drift.Value(phase2Id),
            title: 'Stress-test peer election leader churn',
            status: 'active',
            priority: 1,
            sortOrder: 1,
            versionHlc: '0000000000000-0000-000000000000',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database.into(database.tasks).insert(
          TasksCompanion.insert(
            id: 'task_03',
            ownerId: ownerId,
            projectId: drift.Value(projectId),
            phaseId: drift.Value(phase2Id),
            title: 'Verify snapshot truncation invariants',
            status: 'pending',
            priority: 3,
            sortOrder: 2,
            versionHlc: '0000000000000-0000-000000000000',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await repository.recalculateProjectProgress(projectId);

    await tester.pumpWidget(
      MaterialApp(
        theme: KratosTheme.darkTheme,
        home: ProjectDetailScreen(
          database: database,
          ownerId: ownerId,
          projectId: projectId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify key Manus elements render correctly
    expect(find.text('PROJECTS / NEURAL ARCHITECTURE ENGINE'), findsOneWidget);
    expect(find.text('Neural Architecture Engine'), findsOneWidget);
    expect(find.text('PROJECT OVERVIEW // CORE SPEC'), findsOneWidget);
    expect(find.text('ALIGNMENT & ARCHITECTURE'), findsOneWidget);
    expect(find.text('ROADMAP & PHASES'), findsOneWidget);
    expect(find.text('TASKS // WORK UNITS'), findsOneWidget);
    expect(find.text('Implement SIMD vector parser'), findsOneWidget);
    expect(find.text('Stress-test peer election leader churn'), findsOneWidget);

    // Verify Phase card navigation works
    await tester.ensureVisible(find.byKey(Key('project_phase_tile_$phase2Id')));
    await tester.tap(find.byKey(Key('project_phase_tile_$phase2Id')));
    await tester.pumpAndSettle();

    expect(find.text('ROADMAP / PHASE 02'), findsOneWidget);
    expect(find.text('Phase 02: Consensus Mesh Synchronization'), findsOneWidget);
    expect(find.text('PHASE CHECKLIST'), findsOneWidget);
    expect(find.text('Stress-test peer election leader churn'), findsOneWidget);
    expect(find.text('Verify snapshot truncation invariants'), findsOneWidget);
  });

  testWidgets('renders ProjectDetailScreen on mobile viewport (390x844)', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const ownerId = 'user_preview_02';
    final now = DateTime.now().toUtc();

    await database.into(database.users).insert(
          UsersCompanion.insert(
            id: ownerId,
            deviceId: 'dev_preview_mobile',
            displayName: const drift.Value('Mobile Operative'),
            timezone: 'UTC',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final repository = ProjectsRepository(
      database: database,
      xpLedgerWriter: DriftXpLedgerWriter(database),
    );

    final projectId = await repository.createProject(
      ownerId: ownerId,
      title: 'Mobile Core Engine',
      description: 'Responsive mobile project workspace.',
      difficulty: 4,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: KratosTheme.darkTheme,
        home: ProjectDetailScreen(
          database: database,
          ownerId: ownerId,
          projectId: projectId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mobile Core Engine'), findsOneWidget);
    expect(find.text('PROJECT OVERVIEW // CORE SPEC'), findsOneWidget);
  });
}
