import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/levels/data/level_detail_repository.dart';
import 'package:kratos_app/features/levels/presentation/level_detail_screen.dart';

void main() {
  late AppDatabase database;
  late LevelDetailRepository repository;
  const ownerId = 'usr_level_e2e';
  final now = DateTime.utc(2026, 9, 25);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LevelDetailRepository(database);
  });

  tearDown(() => database.close());

  testWidgets('Wave 7: Full E2E Level Detail workflow with multi-life area linking and editing', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await database.progressionDao.ensureSeeded();

    // 1. Create Category
    await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            id: 'cat_engineering',
            ownerId: ownerId,
            name: 'Systems Engineering',
            categoryType: const Value('life_area'),
            baseXp: 120,
            isImmutable: false,
            sortOrder: 0,
            versionHlc: '0:0:1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // 2 & 3. Create/Configure Level 2 and assign Category
    await repository.updateLevel(
      level: 2,
      name: 'Bronze II - Apprentice Engineer',
      description: 'Foundational competence in architectural design.',
      categoryId: 'cat_engineering',
      tierName: 'Bronze',
      deltaXp: 150,
    );

    // 4, 5, 6, 7. Open Level Detail and verify Tier, Category, and XP Range
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: LevelDetailScreen(
          database: database,
          ownerId: ownerId,
          level: 2,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Bronze II - Apprentice Engineer'), findsOneWidget);
    expect(find.text('Systems Engineering'), findsWidgets);
    expect(find.text('Foundational competence in architectural design.'), findsOneWidget);
    expect(find.text('BRONZE'), findsWidgets);

    // 8 & 9. Create Life Area 1 and assign XP that places it at Level 2 (150 XP)
    await database.batch((batch) {
      batch.insert(
        database.lifeAreas,
        LifeAreasCompanion.insert(
          id: 'area_backend',
          ownerId: ownerId,
          name: 'Backend Architecture',
          categoryId: const Value('cat_engineering'),
          sortOrder: 0,
          versionHlc: '0:0:1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      batch.insert(
        database.xpLedger,
        XpLedgerCompanion.insert(
          id: 'ledger_backend_1',
          ownerId: ownerId,
          idempotencyKey: 'idem_backend_1',
          sourceType: 'task',
          sourceId: 'task_backend_1',
          action: 'complete',
          points: 150,
          versionHlc: '0:0:1',
          deviceId: 'dev_1',
          createdAt: Value(now),
        ),
      );
      batch.insert(
        database.xpAllocationLines,
        XpAllocationLinesCompanion.insert(
          id: 'line_backend_1',
          ledgerId: 'ledger_backend_1',
          lifeAreaId: 'area_backend',
          allocatedPoints: 150,
          percentage: 1,
          versionHlc: '0:0:1',
          createdAt: Value(now),
        ),
      );
    });

    // Pump to verify Life Area 1 appears
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('BACKEND ARCHITECTURE'), findsOneWidget);
    expect(find.text('150 XP'), findsOneWidget);

    // 13. Create second Life Area (Cloud Infrastructure) at Level 2 (180 XP)
    await database.batch((batch) {
      batch.insert(
        database.lifeAreas,
        LifeAreasCompanion.insert(
          id: 'area_cloud',
          ownerId: ownerId,
          name: 'Cloud Infrastructure',
          categoryId: const Value('cat_engineering'),
          sortOrder: 1,
          versionHlc: '0:0:1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      batch.insert(
        database.xpLedger,
        XpLedgerCompanion.insert(
          id: 'ledger_cloud_1',
          ownerId: ownerId,
          idempotencyKey: 'idem_cloud_1',
          sourceType: 'task',
          sourceId: 'task_cloud_1',
          action: 'complete',
          points: 180,
          versionHlc: '0:0:1',
          deviceId: 'dev_1',
          createdAt: Value(now),
        ),
      );
      batch.insert(
        database.xpAllocationLines,
        XpAllocationLinesCompanion.insert(
          id: 'line_cloud_1',
          ledgerId: 'ledger_cloud_1',
          lifeAreaId: 'area_cloud',
          allocatedPoints: 180,
          percentage: 1,
          versionHlc: '0:0:1',
          createdAt: Value(now),
        ),
      );
    });

    // 14. Verify both appear independently
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('BACKEND ARCHITECTURE'), findsOneWidget);
    expect(find.text('CLOUD INFRASTRUCTURE'), findsOneWidget);
    expect(find.text('2 Active'), findsOneWidget);

    // 15. Edit Level via UI
    expect(find.text('Edit'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('EDIT LEVEL DEFINITION'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Silver II - Senior Engineer');
    await tester.enterText(find.byType(TextField).last, 'Advanced technical leadership.');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Level Changes'));
    await tester.pumpAndSettle();

    // 16 & 17. Verify persisted changes
    expect(find.text('Silver II - Senior Engineer'), findsOneWidget);
    expect(find.text('Advanced technical leadership.'), findsOneWidget);

    // Verify database direct query
    final updatedCurve = await database.progressionDao.findLevel(2);
    expect(updatedCurve?.name, 'Silver II - Senior Engineer');
    expect(updatedCurve?.description, 'Advanced technical leadership.');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
