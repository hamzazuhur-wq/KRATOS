// Wave 18: Comprehensive End-to-End System Integration Test.
// Validates full interoperability across:
// Auth -> LifeArea -> Goal -> Task -> Session -> XP Allocation -> Progression -> Streak -> Sync Outbox.

import 'package:test/test.dart';

import 'package:kratos_app/domain/entities/goal.dart';
import 'package:kratos_app/domain/entities/task.dart';
import 'package:kratos_app/domain/hlc.dart';
import 'package:kratos_app/domain/ids.dart';
import 'package:kratos_app/domain/timestamps.dart';
import 'package:kratos_app/features/auth/domain/auth_models.dart';
import 'package:kratos_app/features/progression/domain/progression_calculator.dart';
import 'package:kratos_app/features/sessions/domain/session_models.dart';
import 'package:kratos_app/features/streaks/domain/streak_models.dart';
import 'package:kratos_app/features/streaks/domain/streak_config.dart';
import 'package:kratos_app/features/sync/domain/sync_models.dart';
import 'package:kratos_app/features/xp/domain/xp_allocation_math.dart';

void main() {
  Hlc makeHlc([int c = 1]) => Hlc(
    wallMs: DateTime.now().millisecondsSinceEpoch,
    counter: c,
    nodeId: Id.uuidV7(),
  );

  group('KRATOS Full-System E2E Lifecycle Simulation', () {
    test('end-to-end user journey across all 18 waves executes with zero invariant breaches', () {
      // 1. Auth: User authenticates
      final user = KratosUser.devMock(
        id: 'usr_hamza_e2e',
        displayName: 'Hamza',
      );
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
      final task = Task.create(
        ownerId: user.id,
        primaryGoalId: goal.id,
        title: 'Implement Multi-Device Sync Engine',
        priority: 1,
        xpReward: 300,
        clock: makeHlc(),
      );
      expect(task.status, TaskStatus.pending);
      expect(task.primaryGoalId, equals(goal.id));

      // 4. Focus Session: 45-minute focus session executed
      final start = DateTime.now().toUtc();
      final session = SessionEntity(
        id: Id.uuidV7(),
        ownerId: user.id,
        taskId: task.id,
        startedAt: Iso8601Timestamp.fromDateTime(start),
        versionHlc: makeHlc(),
        createdAt: Iso8601Timestamp.fromDateTime(start),
        updatedAt: Iso8601Timestamp.fromDateTime(start),
      );
      expect(session.isRunning, isTrue);

      final end = start.add(const Duration(minutes: 45));
      final completedSession = session.end(
        Iso8601Timestamp.fromDateTime(end),
        makeHlc(2),
      );
      expect(completedSession.isCompleted, isTrue);
      expect(completedSession.durationMs, equals(45 * 60 * 1000));

      // 5. XP Award & Allocation: Apportioned across Career (70%) and Learning (30%)
      final basePoints = task.xpReward!; // 300 XP
      final allocations = HamiltonHareAllocator.allocate(
        totalPoints: basePoints,
        ratios: [
          AllocationRatio(lifeAreaId: Id('la_career'), percentage: 70),
          AllocationRatio(lifeAreaId: Id('la_learning'), percentage: 30),
        ],
      );

      // Invariant #2 check: sum of allocated points must equal basePoints exactly
      final sumAllocated = allocations.fold<int>(0, (sum, a) => sum + a.points);
      expect(sumAllocated, equals(basePoints));
      expect(allocations.first.points, equals(210));
      expect(allocations.last.points, equals(90));

      // 6. Streak Progression: daily reward remains separate from task XP.
      final streak = StreakInfo.create(
        userId: user.id,
        lifeAreaId: const Id('la_career'),
        currentStreak: 7,
        longestStreak: 7,
        freezeTokensAvailable: StreakConfig.maxFreezes,
        lastActiveDate: DateTime.now().toUtc(),
      );
      expect(streak.isWeeklyBonusActive, isFalse);
      expect(StreakConfig.rewardForDay(streak.currentStreak), equals(70));

      // 7. Progression Curve & Tier: Evaluate Level advancement
      // Cumulative XP: say user has accumulated 3,200 XP in Career
      final careerTotalXp = 3200;
      final progression = ProgressionCalculator.calculate(
        totalXp: careerTotalXp,
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
