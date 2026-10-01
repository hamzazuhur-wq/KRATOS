import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/levels/presentation/level_detail_screen.dart';

void main() {
  late AppDatabase database;
  const ownerId = 'usr_level_screen_test';
  final now = DateTime.utc(2026, 9, 25);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  testWidgets('renders level details, specification, and empty linked life areas state', (tester) async {
    await database.progressionDao.ensureSeeded();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: LevelDetailScreen(
          database: database,
          ownerId: ownerId,
          level: 1,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('LEVEL DETAIL'), findsOneWidget);
    expect(find.text('LEVEL SPECIFICATION'), findsOneWidget);
    expect(find.text('XP RANGE'), findsOneWidget);
    expect(find.text('PROGRESSION BRACKET'), findsOneWidget);
    expect(find.text('LIFE AREAS USING THIS LEVEL'), findsOneWidget);
    expect(find.text('NO ACTIVE LIFE AREAS'), findsOneWidget);
    expect(find.text('No Life Areas are currently using this Level.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('renders active linked Life Areas with real XP progress', (tester) async {
    await database.progressionDao.ensureSeeded();

    // 1. Insert category
    await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            id: 'cat_growth',
            ownerId: ownerId,
            name: 'Personal Growth',
            categoryType: const Value('life_area'),
            baseXp: 100,
            isImmutable: false,
            sortOrder: 0,
            versionHlc: '0:0:1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // 2. Insert Life Area
    await database.into(database.lifeAreas).insert(
          LifeAreasCompanion.insert(
            id: 'area_mindset',
            ownerId: ownerId,
            name: 'Mindset & Focus',
            categoryId: const Value('cat_growth'),
            sortOrder: 0,
            versionHlc: '0:0:1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // 3. Award XP
    await database.into(database.xpLedger).insert(
          XpLedgerCompanion.insert(
            id: 'ledger_mindset',
            ownerId: ownerId,
            idempotencyKey: 'idem_mindset',
            sourceType: 'task',
            sourceId: 'task_mindset',
            action: 'complete',
            points: 75,
            versionHlc: '0:0:1',
            deviceId: 'dev_1',
            createdAt: Value(now),
          ),
        );

    await database.into(database.xpAllocationLines).insert(
          XpAllocationLinesCompanion.insert(
            id: 'line_mindset',
            ledgerId: 'ledger_mindset',
            lifeAreaId: 'area_mindset',
            allocatedPoints: 75,
            percentage: 1,
            versionHlc: '0:0:1',
            createdAt: Value(now),
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: LevelDetailScreen(
          database: database,
          ownerId: ownerId,
          level: 1,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('MINDSET & FOCUS'), findsOneWidget);
    expect(find.text('75 XP'), findsOneWidget);
    expect(find.text('Personal Growth'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('opens edit level sheet and updates level definition metadata', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await database.progressionDao.ensureSeeded();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: LevelDetailScreen(
          database: database,
          ownerId: ownerId,
          level: 1,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Tap edit button
    expect(find.text('Edit'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('EDIT LEVEL DEFINITION'), findsOneWidget);

    // Enter new name and description
    await tester.enterText(find.byType(TextField).first, 'Master Initiate');
    await tester.enterText(find.byType(TextField).last, 'First steps in mastery.');
    await tester.pumpAndSettle();

    // Tap Save
    await tester.tap(find.text('Save Level Changes'));
    await tester.pumpAndSettle();

    // Verify updated header & description
    expect(find.text('Master Initiate'), findsOneWidget);
    expect(find.text('First steps in mastery.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
