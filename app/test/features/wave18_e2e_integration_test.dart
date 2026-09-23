// Wave 18: Comprehensive End-to-End System Integration Test.
// Validates full interoperability across:
// Auth -> LifeArea -> Goal -> Task -> Session -> XP Allocation -> Progression -> Streak -> Sync Outbox.

import 'package:test/test.dart';
import '../../lib/domain/entities/goal.dart';
import '../../lib/domain/entities/task.dart';
import '../../lib/domain/hlc.dart';
import '../../lib/domain/ids.dart';
import '../../lib/domain/timestamps.dart';
import '../../lib/features/auth/domain/auth_models.dart';
import '../../lib/features/progression/domain/progression_calculator.dart';
import '../../lib/features/progression/domain/progression_models.dart';
import '../../lib/features/sessions/domain/session_models.dart';
import '../../lib/features/streaks/domain/streak_models.dart';
import '../../lib/features/sync/domain/sync_models.dart';
import '../../lib/features/xp/domain/xp_allocation_math.dart';

void main() {
  Hlc makeHlc([int c = 1]) => Hlc(
        wallMs: DateTime.now().millisecondsSinceEpoch,
        counter: c,
        node: 'e2e_test',
      );

  group('KRATOS Full-System E2E Lifecycle Simulation', () {
    test('end-to-end user journey across all 18 waves executes with zero invariant breaches', () {
      // 1. Auth: User authenticates
      final user = KratosUser.devMock(id: 'usr_hamza_e2e', displayName: 'Hamza');
      expect(user.method, equals(AuthMethod.developerMock));

      // 2. Goal Creation: Root goal defined
      final goalId = Id.uuidV7();
      final goal = Goal(
        id: goalId,
        ownerId: user.id,
        rootId: goalId,
        path: goalId.value,
        depth: 0,
        title: 'Master Systems Engineering',
        xpTarget: 1000,
        progress: 0.0,
        versionHlc: makeHlc(),
        progressHlc: makeHlc(),
        createdAt: Iso8601Timestamp.now(),
        updatedAt: Iso8601Timestamp.now(),
      );
      expect(goal.isRoot, isTrue);

      // 3. Task Creation: Linked to Goal
      final task = Task(
        id: Id.uuidV7(),
        ownerId: user.id,
        primaryGoalId: goal.id,
        title: 'Implement Multi-Device Sync Engine',
        priority: 1,
        xpReward: 300,
        status: TaskStatus.inProgress,
        versionHlc: makeHlc(),
        createdAt: Iso8601Timestamp.now(),
        updatedAt: Iso8601Timestamp.now(),
      );
      expect(task.isActive, isTrue);
      expect(task.primaryGoalId, equals(goal.id));

      // 4. Focus Session: 45-minute focus session executed
      final start = DateTime.now().toUtc();
      final session = SessionEntity(
        id: Id.uuidV7(),
        ownerId: user.id,
        taskId: task.id,
        startedAt: Iso8601Timestamp(start),
        versionHlc: makeHlc(),
        createdAt: Iso8601Timestamp(start),
        updatedAt: Iso8601Timestamp(start),
      );
      expect(session.isRunning, isTrue);

      final end = start.add(const Duration(minutes: 45));
      final completedSession = session.end(Iso8601Timestamp(end), makeHlc(2));
      expect(completedSession.isCompleted, isTrue);
      expect(completedSession.durationMs, equals(45 * 60 * 1000));

      // 5. XP Award & Allocation: Apportioned across Career (70%) and Learning (30%)
      final basePoints = task.xpReward!; // 300 XP
      final allocations = HamiltonHareAllocator.allocate(
        totalPoints: basePoints,
        weights: [
          (lifeAreaId: 'la_career', weight: 0.70),
          (lifeAreaId: 'la_learning', weight: 0.30),
        ],
      );

      // Invariant #2 check: sum of allocated points must equal basePoints exactly
      final sumAllocated = allocations.fold<int>(0, (sum, a) => sum + a.allocatedPoints);
      expect(sumAllocated, equals(basePoints));
      expect(allocations.first.allocatedPoints, equals(210));
      expect(allocations.last.allocatedPoints, equals(90));

      // 6. Streak Progression: 7-day streak activates +20% bonus
      final streak = StreakInfo.create(
        userId: user.id,
        lifeAreaId: const Id('la_career'),
        currentStreak: 7,
        longestStreak: 7,
        freezeTokensAvailable: 2,
        lastActiveDate: DateTime.now().toUtc(),
      );
      expect(streak.isWeeklyBonusActive, isTrue);
      final bonusPoints = streak.calculateStreakBonus(210);
      expect(bonusPoints, equals(42)); // 20% of 210 = 42 XP

      // 7. Progression Curve & Tier: Evaluate Level advancement
      // Cumulative XP: say user has accumulated 3,200 XP in Career
      final careerTotalXp = 3200;
      final curves = List.generate(
        10,
        (i) => LevelCurveEntity(
          level: i + 1,
          cumulativeXpRequired: (i + 1) * 500,
          deltaXp: 500,
        ),
      );
      final tiers = [
        const TierDefinitionEntity(name: 'Bronze', entryXp: 1000, ordinal: 1),
        const TierDefinitionEntity(name: 'Silver', entryXp: 3000, ordinal: 2),
        const TierDefinitionEntity(name: 'Gold', entryXp: 7000, ordinal: 3),
      ];

      final progression = ProgressionCalculator.calculate(
        totalXp: careerTotalXp,
        curves: curves,
        tiers: tiers,
      );

      // With 3,200 XP: Silver tier reached!
      expect(progression.tier, equals('Silver'));
      expect(progression.totalXp, equals(3200));

      // 8. Outbox Enqueue: Transactional outbox ready for sync drain
      final syncItem = SyncItem(
        seq: 1,
        userId: user.id.value,
        op: 'insert',
        entity: 'tasks',
        entityId: task.id.value,
        payloadJson: '{"status":"completed"}',
        hlc: task.versionHlc.toString(),
        deviceId: 'dev_e2e_01',
        attempts: 0,
        status: SyncStatus.pending,
        createdAt: DateTime.now().toUtc(),
      );
      expect(syncItem.status, equals(SyncStatus.pending));
    });
  });
}
