import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/levels/data/level_detail_repository.dart';
import 'package:kratos_app/features/levels/presentation/create_level_screen.dart';
import 'package:kratos_app/features/life_areas/presentation/life_areas_screen.dart';

void main() {
  late AppDatabase database;
  const ownerId = 'usr_create_level_test';
  final now = DateTime.utc(2026, 9, 25);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  testWidgets('renders CreateLevelScreen with all form fields and liquid glass header', (tester) async {
    await database.progressionDao.ensureSeeded();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: CreateLevelScreen(
          database: database,
          ownerId: ownerId,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('NEW LEVEL DEFINITION'), findsOneWidget);
    expect(find.text('TIER *'), findsOneWidget);
    expect(find.text('LEVEL NAME *'), findsOneWidget);
    expect(find.text('LIFE AREA CATEGORY *'), findsOneWidget);
    expect(find.text('EXPERIENCE RANGE SPECIFICATION'), findsOneWidget);
    expect(find.text('CREATE LEVEL'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('creates a Level Definition and persists it to SQLite LevelCurves table', (tester) async {
    await database.progressionDao.ensureSeeded();

    // Insert a life area category
    await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            id: 'cat_warrior',
            ownerId: ownerId,
            name: 'Warrior Discipline',
            categoryType: const Value('life_area'),
            baseXp: 100,
            isImmutable: false,
            sortOrder: 0,
            versionHlc: '0:0:1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final repo = LevelDetailRepository(database);

    final created = await repo.createLevel(
      ownerId: ownerId,
      level: 15,
      name: 'Titan V',
      tierName: 'Titan',
      minXp: 15000,
      maxXp: 25000,
      description: 'The pinnacle of warrior discipline',
      categoryId: 'cat_warrior',
    );

    expect(created.level, 15);
    expect(created.name, 'Titan V');
    expect(created.tier, 'Titan');
    expect(created.lowerXp, 15000);
    expect(created.upperXp, 25000);
    expect(created.category?.id, 'cat_warrior');

    // Verify database query
    final rows = await (database.select(database.levelCurves)
          ..where((l) => l.level.equals(15)))
        .get();
    expect(rows.length, 1);
    expect(rows.first.name, 'Titan V');
    expect(rows.first.description, 'The pinnacle of warrior discipline');
    expect(rows.first.cumulativeXpRequired, 15000);
    expect(rows.first.deltaXp, 10000);
  });

  testWidgets('creates a new Life Area Category inline and returns it', (tester) async {
    final repo = LevelDetailRepository(database);

    final category = await repo.createLifeAreaCategory(
      ownerId: ownerId,
      name: 'Mindset & Clarity',
    );

    expect(category.id, isNotEmpty);
    expect(category.name, 'Mindset & Clarity');
    expect(category.categoryType, 'life_area');

    // Verify category in DB
    final saved = await (database.select(database.categories)
          ..where((c) => c.ownerId.equals(ownerId) & c.id.equals(category.id)))
        .getSingle();
    expect(saved.name, 'Mindset & Clarity');
    expect(saved.categoryType, 'life_area');
  });

  testWidgets('Life Area creation with starting Level Definition awards initial XP', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await database.progressionDao.ensureSeeded();

    // Create a level definition
    final repo = LevelDetailRepository(database);
    await repo.createLevel(
      ownerId: ownerId,
      level: 5,
      name: 'Gold I',
      tierName: 'Gold',
      categoryId: null,
      minXp: 5000,
      maxXp: 8000,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: LifeAreasScreen(
          database: database,
          ownerId: ownerId,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Tap NEW DOMAIN FAB
    await tester.tap(find.text('NEW DOMAIN'));
    await tester.pumpAndSettle();

    // Enter Domain Name
    await tester.enterText(find.byKey(const Key('life_area_name_input')), 'Financial Freedom');
    await tester.pump();

    // Tap starting level picker
    await tester.tap(find.byKey(const Key('starting_level_picker')));
    await tester.pumpAndSettle();

    // Pick Gold I
    expect(find.text('Gold I'), findsOneWidget);
    await tester.tap(find.text('Gold I'));
    await tester.pumpAndSettle();

    // Verify starting XP slider shows up with minXp = 5000
    expect(find.text('STARTING XP'), findsOneWidget);
    expect(find.text('5000 XP'), findsWidgets);

    // Tap Save / Create Domain
    await tester.tap(find.byKey(const Key('save_life_area_button')));
    await tester.pumpAndSettle();

    // Verify life area was created
    final lifeAreas = await (database.select(database.lifeAreas)
          ..where((a) => a.ownerId.equals(ownerId)))
        .get();
    expect(lifeAreas.length, 1);
    expect(lifeAreas.first.name, 'Financial Freedom');

    // Verify initial XP ledger entry was created
    final ledgerEntries = await (database.select(database.xpLedger)
          ..where((x) => x.ownerId.equals(ownerId) & x.sourceId.equals(lifeAreas.first.id)))
        .get();
    expect(ledgerEntries.length, 1);
    expect(ledgerEntries.first.points, 5000);
    expect(ledgerEntries.first.sourceId, lifeAreas.first.id);

    // Verify XP allocation line
    final lines = await (database.select(database.xpAllocationLines)
          ..where((l) => l.ledgerId.equals(ledgerEntries.first.id)))
        .get();
    expect(lines.length, 1);
    expect(lines.first.allocatedPoints, 5000);
    expect(lines.first.lifeAreaId, lifeAreas.first.id);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
