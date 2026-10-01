// Phase 5: XP & Progression Engine Comprehensive Test Suite
// Verifies deterministic XP calculation, idempotency guarantees, atomicity,
// append-only ledger & reversals, per-life-area levels & tiers, streak logic,
// offline outbox queueing, and activity_events integration without feedback loops.

import 'dart:convert';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/domain/hlc.dart';
import 'package:kratos_app/domain/ids.dart';
import 'package:kratos_app/features/activities/domain/activity_xp_calculator.dart';
import 'package:kratos_app/features/goals/domain/goal_xp_service.dart';
import 'package:kratos_app/features/progression/domain/progression_calculator.dart';
import 'package:kratos_app/features/projects/domain/project_models.dart';
import 'package:kratos_app/features/streaks/domain/streak_service.dart';
import 'package:kratos_app/features/xp/data/xp_ledger_writer_impl.dart';
import 'package:kratos_app/features/xp/domain/xp_allocation_math.dart';

void main() {
  late AppDatabase db;
  late DriftXpLedgerWriter writer;
  late GoalXpService goalXpService;
  late StreakService streakService;

  const testUserId = 'usr_phase5_hero';
  const testDeviceId = 'dev_win_desktop_01';
  const lifeAreaHealthId = 'la_health_01';
  const lifeAreaCareerId = 'la_career_02';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    writer = DriftXpLedgerWriter(db);
    goalXpService = GoalXpService(db);
    streakService = StreakService(db);

    // Seed test life areas
    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id(testDeviceId)).toString();
    await db.into(db.lifeAreas).insert(
      LifeAreasCompanion.insert(
        id: lifeAreaHealthId,
        ownerId: testUserId,
        name: 'Health & Vitality',
        sortOrder: 0,
        versionHlc: hlc,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.into(db.lifeAreas).insert(
      LifeAreasCompanion.insert(
        id: lifeAreaCareerId,
        ownerId: testUserId,
        name: 'Career & Mastery',
        sortOrder: 1,
        versionHlc: hlc,
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('1. Deterministic XP Calculations & Invariants', () {
    test('Hamilton-Hare allocation exact sum invariant (Invariant #2)', () {
      final ratios = [
        AllocationRatio(lifeAreaId: Id(lifeAreaHealthId), percentage: 60.0),
        AllocationRatio(lifeAreaId: Id(lifeAreaCareerId), percentage: 40.0),
      ];

      final allocations = HamiltonHareAllocator.allocate(
        totalPoints: 100,
        ratios: ratios,
      );

      final totalSum = allocations.fold<int>(0, (sum, a) => sum + a.points);
      expect(totalSum, equals(100));
      expect(allocations.first.points, equals(60));
      expect(allocations.last.points, equals(40));
    });

    test('Late penalty applies -30% strictly when overdue and not cancelled (Invariant #7 & #8)', () {
      final now = DateTime.utc(2026, 9, 27, 12, 0, 0);
      final overdue = DateTime.utc(2026, 9, 26, 12, 0, 0);
      final futureDate = DateTime.utc(2026, 9, 28, 12, 0, 0);

      // Past due
      final penalty = LatePenaltyCalculator.calculate(
        dueDate: overdue,
        status: 'open',
        basePoints: 100,
        now: now,
      );
      expect(penalty, equals(30)); // 30% of 100

      // Not overdue
      final noPenalty = LatePenaltyCalculator.calculate(
        dueDate: futureDate,
        status: 'open',
        basePoints: 100,
        now: now,
      );
      expect(noPenalty, equals(0));

      // Cancelled task has zero penalty
      final cancelledPenalty = LatePenaltyCalculator.calculate(
        dueDate: overdue,
        status: 'cancelled',
        basePoints: 100,
        now: now,
      );
      expect(cancelledPenalty, equals(0));
    });

    test('Activity duration XP engine scales with duration and difficulty (Phase 2)', () {
      const difficulty = 5;

      // 30 minutes
      final xp30Min = ActivityXpCalculator.calculateActivityXp(
        difficulty,
        const Duration(minutes: 30),
      );
      expect(xp30Min, greaterThanOrEqualTo(1));

      // 2 hours vs 4 hours
      final xp2h = ActivityXpCalculator.calculateActivityXp(
        difficulty,
        const Duration(hours: 2),
      );
      final xp4h = ActivityXpCalculator.calculateActivityXp(
        difficulty,
        const Duration(hours: 4),
      );
      expect(xp4h, greaterThan(xp2h));
      expect(xp4h, lessThanOrEqualTo(30)); // Max Activity XP is 30
    });

    test('Project completion calculates deterministic XP by difficulty', () {
      final easy = ProjectDifficultyXpCalculator.calculateXp(difficulty: 2);
      final hard = ProjectDifficultyXpCalculator.calculateXp(difficulty: 9);

      expect(hard.totalXp, greaterThan(easy.totalXp));
    });

    test('Main Goal awards +30% completion bonus without compounding (Invariant #6)', () async {
      final mainGoalId = Id.uuidV7().value;
      final hlc = Hlc.now(Id(testDeviceId)).toString();
      final now = DateTime.now().toUtc();

      // Create main goal (root)
      await db.into(db.goals).insert(
        GoalsCompanion.insert(
          id: mainGoalId,
          ownerId: testUserId,
          rootId: mainGoalId,
          path: 'root_goal',
          depth: 0,
          title: 'Master Flutter',
          progress: 0.0,
          lifeAreaId: Value(lifeAreaCareerId),
          status: 'active',
          versionHlc: hlc,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Create a task contributing to this goal
      final taskId = Id.uuidV7().value;
      await db.into(db.tasks).insert(
        TasksCompanion.insert(
          id: taskId,
          ownerId: testUserId,
          title: 'Build Drift Layer',
          primaryGoalId: Value(mainGoalId),
          lifeAreaId: Value(lifeAreaCareerId),
          xpReward: const Value(100),
          priority: 1,
          sortOrder: 0,
          status: 'open',
          versionHlc: hlc,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.into(db.taskGoalLinks).insert(
        TaskGoalLinksCompanion.insert(
          taskId: taskId,
          goalId: mainGoalId,
          role: 'contributes_to',
          sortOrder: 0,
          versionHlc: hlc,
          createdAt: now,
        ),
      );

      // Complete task
      final taskRow = await (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingle();
      await goalXpService.completeTask(
        task: taskRow,
        ownerId: testUserId,
        lifeAreaId: lifeAreaCareerId,
      );

      // Complete main goal
      final goalRow = await (db.select(db.goals)..where((g) => g.id.equals(mainGoalId))).getSingle();
      final bonusXp = await goalXpService.completeGoal(
        goal: goalRow,
        ownerId: testUserId,
      );

      // Bonus should be exactly 30% of descendant XP (100 * 0.30 = 30)
      expect(bonusXp, equals(30));
    });
  });

  group('2. Idempotency & Replay Protection (Critical Rule)', () {
    test('Identical idempotency key returns existing row without double awarding', () async {
      final key = Id('test_idemp_key_1001');
      final clock = Hlc.now(Id(testDeviceId));

      final firstEvent = await writer.recordEvent(
        ownerId: Id(testUserId),
        idempotencyKey: key,
        sourceType: 'task',
        sourceId: Id.uuidV7(),
        action: 'completed',
        basePoints: 50,
        allocationRatios: [
          AllocationRatio(lifeAreaId: Id(lifeAreaHealthId), percentage: 100.0),
        ],
        clock: clock,
        deviceId: Id(testDeviceId),
      );

      expect(firstEvent.points, equals(50));

      // Replay identical event
      final replayedEvent = await writer.recordEvent(
        ownerId: Id(testUserId),
        idempotencyKey: key,
        sourceType: 'task',
        sourceId: firstEvent.sourceId,
        action: 'completed',
        basePoints: 50,
        allocationRatios: [
          AllocationRatio(lifeAreaId: Id(lifeAreaHealthId), percentage: 100.0),
        ],
        clock: clock,
        deviceId: Id(testDeviceId),
      );

      expect(replayedEvent.id, equals(firstEvent.id));

      // Verify database total points is still strictly 50, not 100
      final totalQuery = db.selectOnly(db.xpAllocationLines)
        ..addColumns([db.xpAllocationLines.allocatedPoints.sum()])
        ..where(db.xpAllocationLines.lifeAreaId.equals(lifeAreaHealthId));
      final row = await totalQuery.getSingle();
      final totalXp = row.read(db.xpAllocationLines.allocatedPoints.sum());
      expect(totalXp, equals(50));
    });
  });

  group('3. Atomicity & Offline Outbox Enqueuing (Invariant #13)', () {
    test('XP award atomically writes ledger + allocation lines + outbox + activity_events', () async {
      final key = Id('atomic_test_key_01');
      final clock = Hlc.now(Id(testDeviceId));

      await writer.recordEvent(
        ownerId: Id(testUserId),
        idempotencyKey: key,
        sourceType: 'task',
        sourceId: Id.uuidV7(),
        action: 'completed',
        basePoints: 75,
        allocationRatios: [
          AllocationRatio(lifeAreaId: Id(lifeAreaHealthId), percentage: 100.0),
        ],
        clock: clock,
        deviceId: Id(testDeviceId),
      );

      // Ledger has 1 entry
      final ledgerRows = await db.select(db.xpLedger).get();
      expect(ledgerRows, hasLength(1));
      expect(ledgerRows.first.points, equals(75));

      // Allocation lines has 1 entry with 75 points
      final lineRows = await db.select(db.xpAllocationLines).get();
      expect(lineRows, hasLength(1));
      expect(lineRows.first.allocatedPoints, equals(75));

      // Outbox has 1 entry for xp_ledger
      final outboxRows = await db.select(db.syncOutbox).get();
      expect(outboxRows, hasLength(1));
      expect(outboxRows.first.entity, equals('xp_ledger'));

      // Activity events has 1 entry for xp_earned
      final activityRows = await db.select(db.activityEvents).get();
      expect(activityRows.any((a) => a.eventType == 'xp_earned'), isTrue);
    });
  });

  group('4. Append-Only Ledger & Compensating Reversals (Invariant #1)', () {
    test('Reversal creates compensating negative event without mutating original row', () async {
      final clock = Hlc.now(Id(testDeviceId));
      final originalKey = Id('orig_award_key');

      final original = await writer.recordEvent(
        ownerId: Id(testUserId),
        idempotencyKey: originalKey,
        sourceType: 'task',
        sourceId: Id.uuidV7(),
        action: 'completed',
        basePoints: 100,
        allocationRatios: [
          AllocationRatio(lifeAreaId: Id(lifeAreaCareerId), percentage: 100.0),
        ],
        clock: clock,
        deviceId: Id(testDeviceId),
      );

      // Reverse event
      final reversalKey = Id('reversal_key_01');
      final reversal = await writer.reverse(
        originalEventId: original.id,
        reason: 'Task reopened by mistake',
        clock: clock,
        deviceId: Id(testDeviceId),
        idempotencyKey: reversalKey,
      );

      expect(reversal.points, equals(-100));
      expect(reversal.action, equals('reversal'));
      expect(reversal.reversalEventId, equals(original.id));

      // Original row still exists and unchanged (append-only)
      final originalCheck = await (db.select(db.xpLedger)..where((l) => l.id.equals(original.id.value))).getSingle();
      expect(originalCheck.points, equals(100));

      // Net XP in life area is now exactly 0
      final totalQuery = db.selectOnly(db.xpAllocationLines)
        ..addColumns([db.xpAllocationLines.allocatedPoints.sum()])
        ..where(db.xpAllocationLines.lifeAreaId.equals(lifeAreaCareerId));
      final row = await totalQuery.getSingle();
      final netXp = row.read(db.xpAllocationLines.allocatedPoints.sum());
      expect(netXp, equals(0));

      // Reversal recorded in activity_events
      final events = await db.select(db.activityEvents).get();
      expect(events.any((e) => e.eventType == 'xp_reversed'), isTrue);
    });
  });

  group('5. Levels, Tiers & Level-Up Events (Invariant #3)', () {
    test('ProgressionCalculator resolves Level, Tier, and next level thresholds', () {
      final info = ProgressionCalculator.calculate(totalXp: 3500);

      expect(info.tier, equals('Silver'));
      expect(info.level, greaterThan(1));
      expect(info.xpInLevel, greaterThan(0));
      expect(info.xpToNext, greaterThan(0));
      expect(info.progressPct, inInclusiveRange(0.0, 100.0));
    });

    test('Crossing level threshold emits level_up activity_event', () async {
      final clock = Hlc.now(Id(testDeviceId));

      // Level 1 threshold is 100 XP. Awarding 150 XP promotes to Level 2.
      await writer.recordEvent(
        ownerId: Id(testUserId),
        idempotencyKey: Id('promote_to_lvl2'),
        sourceType: 'task',
        sourceId: Id.uuidV7(),
        action: 'completed',
        basePoints: 150,
        allocationRatios: [
          AllocationRatio(lifeAreaId: Id(lifeAreaHealthId), percentage: 100.0),
        ],
        clock: clock,
        deviceId: Id(testDeviceId),
      );

      final events = await db.select(db.activityEvents).get();
      final levelUpEvents = events.where((e) => e.eventType == 'level_up').toList();

      expect(levelUpEvents, hasLength(1));
      final metadata = jsonDecode(levelUpEvents.first.metadata) as Map<String, dynamic>;
      expect(metadata['to_level'], greaterThan(1));
      expect(metadata['life_area_id'], equals(lifeAreaHealthId));
    });
  });

  group('6. Streaks & Daily Rewards', () {
    test('Qualifying completion advances streak and emits streak_extended', () async {
      final hlc = Hlc.now(Id(testDeviceId)).toString();
      final now = DateTime.now().toUtc();

      final result = await streakService.recordQualifyingCompletion(
        userId: Id(testUserId),
        sourceId: Id.uuidV7(),
        lifeAreaId: Id(lifeAreaHealthId),
        completedAt: now,
        versionHlc: hlc,
        deviceId: Id(testDeviceId),
      );

      expect(result.streakDay, equals(1));
      expect(result.advancedToday, isTrue);

      final events = await db.select(db.activityEvents).get();
      expect(events.any((e) => e.eventType == 'streak_extended'), isTrue);

      // Repeat completion on the same calendar day does not advance streak a second time
      final repeatResult = await streakService.recordQualifyingCompletion(
        userId: Id(testUserId),
        sourceId: Id.uuidV7(),
        lifeAreaId: Id(lifeAreaHealthId),
        completedAt: now,
        versionHlc: hlc,
        deviceId: Id(testDeviceId),
      );

      expect(repeatResult.advancedToday, isFalse);
    });
  });
}
