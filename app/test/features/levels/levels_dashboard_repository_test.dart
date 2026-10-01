import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/levels/data/levels_dashboard_repository.dart';

void main() {
  late AppDatabase database;
  const ownerId = 'usr_levels_test';
  final now = DateTime.utc(2026, 9, 25);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('maps persisted categories and independent XP progressions', () async {
    await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(
            id: 'cat_professional',
            ownerId: ownerId,
            name: 'Business',
            categoryType: const Value('life_area'),
            baseXp: 100,
            isImmutable: false,
            sortOrder: 0,
            versionHlc: '0:0:1',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(
            id: 'cat_learning',
            ownerId: ownerId,
            name: 'Education',
            categoryType: const Value('life_area'),
            baseXp: 100,
            isImmutable: false,
            sortOrder: 1,
            versionHlc: '0:0:1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.batch((batch) {
      batch.insert(
        database.lifeAreas,
        LifeAreasCompanion.insert(
          id: 'area_professional',
          ownerId: ownerId,
          name: 'Professional',
          categoryId: const Value('cat_professional'),
          sortOrder: 0,
          versionHlc: '0:0:1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      batch.insert(
        database.lifeAreas,
        LifeAreasCompanion.insert(
          id: 'area_learning',
          ownerId: ownerId,
          name: 'Learning',
          categoryId: const Value('cat_learning'),
          sortOrder: 1,
          versionHlc: '0:0:1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      batch.insert(
        database.xpLedger,
        XpLedgerCompanion.insert(
          id: 'ledger_professional',
          ownerId: ownerId,
          idempotencyKey: 'idem_professional',
          sourceType: 'task',
          sourceId: 'task_professional',
          action: 'complete',
          points: 7000,
          versionHlc: '0:0:1',
          deviceId: 'device_1',
          createdAt: Value(now),
        ),
      );
      batch.insert(
        database.xpAllocationLines,
        XpAllocationLinesCompanion.insert(
          id: 'line_professional',
          ledgerId: 'ledger_professional',
          lifeAreaId: 'area_professional',
          allocatedPoints: 7000,
          percentage: 1,
          versionHlc: '0:0:1',
          createdAt: Value(now),
        ),
      );
      batch.insert(
        database.xpLedger,
        XpLedgerCompanion.insert(
          id: 'ledger_learning',
          ownerId: ownerId,
          idempotencyKey: 'idem_learning',
          sourceType: 'task',
          sourceId: 'task_learning',
          action: 'complete',
          points: 3000,
          versionHlc: '0:0:1',
          deviceId: 'device_1',
          createdAt: Value(now),
        ),
      );
      batch.insert(
        database.xpAllocationLines,
        XpAllocationLinesCompanion.insert(
          id: 'line_learning',
          ledgerId: 'ledger_learning',
          lifeAreaId: 'area_learning',
          allocatedPoints: 3000,
          percentage: 1,
          versionHlc: '0:0:1',
          createdAt: Value(now),
        ),
      );
    });

    final entries = await LevelsDashboardRepository(database)
        .watchProgressions(ownerId)
        .first;

    expect(entries, hasLength(2));
    expect(entries[0].category?.name, 'Business');
    expect(entries[0].progression.tier, 'Gold');
    expect(entries[0].progression.totalXp, 7000);
    expect(entries[1].category?.name, 'Education');
    expect(entries[1].progression.tier, 'Silver');
    expect(entries[1].progression.totalXp, 3000);
  });

  test('emits the empty active Life Area collection', () async {
    final entries = await LevelsDashboardRepository(database)
        .watchProgressions(ownerId)
        .first;

    expect(entries, isEmpty);
  });
}
