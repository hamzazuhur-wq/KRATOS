import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/levels/data/level_detail_repository.dart';

void main() {
  late AppDatabase database;
  late LevelDetailRepository repository;
  const ownerId = 'usr_level_detail_test';
  final now = DateTime.utc(2026, 9, 25);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LevelDetailRepository(database);
  });

  tearDown(() => database.close());

  test('retrieves level details with accurate curve boundaries and default tier', () async {
    final detail = await repository.getLevelDetail(
      level: 1,
      ownerId: ownerId,
    );

    expect(detail.level, 1);
    expect(detail.lowerXp, 0);
    expect(detail.deltaXp, 100);
    expect(detail.upperXp, 100);
    expect(detail.linkedLifeAreas, isEmpty);
  });

  test('resolves persisted category relationship and updates level metadata', () async {
    // 1. Create real category
    await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            id: 'cat_leadership',
            ownerId: ownerId,
            name: 'Leadership & Strategy',
            categoryType: const Value('life_area'),
            baseXp: 150,
            isImmutable: false,
            sortOrder: 1,
            versionHlc: '0:0:1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // 2. Update level 3 with name, description, category, and tier
    await repository.updateLevel(
      level: 3,
      name: 'Gold II - Master Strategist',
      description: 'Executes complex domain strategy with high efficacy.',
      categoryId: 'cat_leadership',
      tierName: 'Gold',
      deltaXp: 500,
    );

    // 3. Fetch detail
    final detail = await repository.getLevelDetail(
      level: 3,
      ownerId: ownerId,
    );

    expect(detail.level, 3);
    expect(detail.name, 'Gold II - Master Strategist');
    expect(detail.description, 'Executes complex domain strategy with high efficacy.');
    expect(detail.category?.name, 'Leadership & Strategy');
    expect(detail.tier, 'Gold');
  });

  test('links active Life Areas currently sitting at the level', () async {
    // 1. Create Category and Life Area
    await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            id: 'cat_pro',
            ownerId: ownerId,
            name: 'Professional',
            categoryType: const Value('life_area'),
            baseXp: 100,
            isImmutable: false,
            sortOrder: 0,
            versionHlc: '0:0:1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.lifeAreas).insert(
          LifeAreasCompanion.insert(
            id: 'area_dev',
            ownerId: ownerId,
            name: 'Software Engineering',
            categoryId: const Value('cat_pro'),
            sortOrder: 0,
            versionHlc: '0:0:1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // 2. Award XP to put Software Engineering at Level 1 (e.g. 50 XP)
    await database.into(database.xpLedger).insert(
          XpLedgerCompanion.insert(
            id: 'ledger_dev',
            ownerId: ownerId,
            idempotencyKey: 'idem_dev',
            sourceType: 'task',
            sourceId: 'task_dev',
            action: 'complete',
            points: 50,
            versionHlc: '0:0:1',
            deviceId: 'dev_1',
            createdAt: Value(now),
          ),
        );

    await database.into(database.xpAllocationLines).insert(
          XpAllocationLinesCompanion.insert(
            id: 'line_dev',
            ledgerId: 'ledger_dev',
            lifeAreaId: 'area_dev',
            allocatedPoints: 50,
            percentage: 1,
            versionHlc: '0:0:1',
            createdAt: Value(now),
          ),
        );

    final detail = await repository.getLevelDetail(
      level: 1,
      ownerId: ownerId,
    );

    expect(detail.linkedLifeAreas, hasLength(1));
    expect(detail.linkedLifeAreas.first.area.name, 'Software Engineering');
    expect(detail.linkedLifeAreas.first.progression.totalXp, 50);
    expect(detail.linkedLifeAreas.first.progression.level, 1);
  });
}
