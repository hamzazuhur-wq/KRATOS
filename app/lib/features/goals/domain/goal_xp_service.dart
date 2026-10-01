// ignore_for_file: public_member_api_docs
// Wave 8: Goal & Task XP Integration Service.
// Enforces the Main Goal completion bonus contract:
// +30% of positive descendant XP, one-time, no compounding, idempotent.

import 'dart:convert';
import 'package:drift/drift.dart' as drift;

import '../../../../data/drift/app_database.dart';
import '../../../../domain/hlc.dart';
import '../../../../domain/ids.dart';
import '../../streaks/domain/streak_service.dart';
import '../../xp/domain/completion_bonus_calculator.dart';
import '../../xp/data/xp_ledger_writer_impl.dart';
import '../../xp/domain/xp_allocation_math.dart';

class GoalXpService {
  final AppDatabase database;
  late final DriftXpLedgerWriter _xpWriter;
  late final StreakService _streakService;

  GoalXpService(this.database) {
    _xpWriter = DriftXpLedgerWriter(database);
    _streakService = StreakService(database);
  }

  /// Completes a task and awards category-governed XP through the immutable ledger.
  ///
  /// XP modifiers applied:
  ///   - Late penalty: −30% of baseXp when task.dueDate is past AND status ≠ 'cancelled'
  Future<int> completeTask({
    required Task task,
    required String ownerId,
    required String? lifeAreaId,
  }) async {
    if (task.status == 'done') return 0; // Already completed

    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id.uuidV7());

    // 1. Resolve base XP and rule version from Task Category
    int baseXp = task.xpReward ?? 50;
    String? ruleVersionId;

    if (task.categoryId != null) {
      final category = await database.categoriesDao.findById(task.categoryId!);
      if (category != null && category.baseXp > 0) {
        baseXp = category.baseXp;
        final ruleVer = await database.categoriesDao.activeRuleVersion(
          category.id,
        );
        ruleVersionId = ruleVer?.id;
      }
    }
    if (baseXp <= 0) {
      baseXp = task.xpReward ?? 50;
    }
    if (baseXp <= 0) baseXp = 50;

    // 2. Resolve Life Area thoroughly
    String effectiveAreaId = lifeAreaId ?? '';
    if (effectiveAreaId.isEmpty && task.lifeAreaId != null) {
      effectiveAreaId = task.lifeAreaId!;
    }
    if (effectiveAreaId.isEmpty && task.primaryGoalId != null) {
      final g =
          await (database.select(database.goals)
                ..where((goal) => goal.id.equals(task.primaryGoalId!)))
              .getSingleOrNull();
      if (g != null && g.lifeAreaId != null) {
        effectiveAreaId = g.lifeAreaId!;
      }
    }
    if (effectiveAreaId.isEmpty && task.projectId != null) {
      final p = await (database.select(
        database.projects,
      )..where((proj) => proj.id.equals(task.projectId!))).getSingleOrNull();
      if (p != null && p.lifeAreaId != null) {
        effectiveAreaId = p.lifeAreaId!;
      }
    }
    if (effectiveAreaId.isEmpty) {
      final areas =
          await (database.select(database.lifeAreas)
                ..where((l) => l.ownerId.equals(ownerId) & l.deletedAt.isNull())
                ..limit(1))
              .get();
      if (areas.isNotEmpty) {
        effectiveAreaId = areas.first.id;
      }
    }

    // 3. Mark task completed
    await (database.update(
      database.tasks,
    )..where((t) => t.id.equals(task.id))).write(
      TasksCompanion(
        status: const drift.Value('done'),
        completedAt: drift.Value(now),
        completedHlc: drift.Value(hlc.toString()),
        versionHlc: drift.Value(hlc.toString()),
        updatedAt: drift.Value(now),
      ),
    );

    // 4. Record XP Event via DriftXpLedgerWriter (Invariant #1, #2, #9, #15)
    final idempotencyKey = Id('xp_task_${task.id}');
    if (baseXp > 0) {
      // 4a. Late penalty: −30% when past due and not cancelled (Invariant #7)
      final latePenalty = LatePenaltyCalculator.calculate(
        dueDate: task.dueDate,
        status: task.status,
        basePoints: baseXp,
        now: now,
      );

      await _xpWriter.recordEvent(
        ownerId: Id(ownerId),
        idempotencyKey: idempotencyKey,
        sourceType: 'task',
        sourceId: Id(task.id),
        action: 'completed',
        basePoints: baseXp,
        latePenalty: latePenalty,
        allocationRatios: [
          AllocationRatio(lifeAreaId: Id(effectiveAreaId), percentage: 100.0),
        ],
        clock: hlc,
        deviceId: Id('local_device'),
        categoryRuleVersionId: ruleVersionId != null ? Id(ruleVersionId) : null,
      );

      // Streak XP is a separate, daily ledger event after the task's base XP.
      await _streakService.recordQualifyingCompletion(
        userId: Id(ownerId),
        sourceId: Id(task.id),
        lifeAreaId: Id(effectiveAreaId),
        completedAt: now,
        versionHlc: hlc.toString(),
        deviceId: Id('local_device'),
      );
    }

    // 5. Update linked Goal progress
    if (task.primaryGoalId != null) {
      await recalculateGoalProgress(task.primaryGoalId!);
    }

    return baseXp;
  }

  /// Recalculates goal progress based on descendant tasks.
  Future<void> recalculateGoalProgress(String goalId) async {
    final goal = await database.goalsDao.findById(goalId);
    if (goal == null || goal.status == 'completed') return;

    // Get all tasks linked to this goal
    final links = await database.taskGoalLinksDao.forGoal(goalId);
    final taskIds = links.map((l) => l.taskId).toList();

    // Also get tasks where primaryGoalId is this goal
    final directTasks =
        await (database.select(database.tasks)..where(
              (t) => t.primaryGoalId.equals(goalId) & t.deletedAt.isNull(),
            ))
            .get();

    final allTaskIds = {...taskIds, ...directTasks.map((t) => t.id)}.toList();
    if (allTaskIds.isEmpty) return;

    final tasks = await (database.select(
      database.tasks,
    )..where((t) => t.id.isIn(allTaskIds) & t.deletedAt.isNull())).get();

    final completedCount = tasks.where((t) => t.status == 'done').length;
    final progress = tasks.isEmpty ? 0.0 : completedCount / tasks.length;

    final hlc = Hlc.now(Id.uuidV7()).toString();
    await database.goalsDao.updateProgress(
      goalId: goalId,
      progress: progress,
      progressHlc: hlc,
      versionHlc: hlc,
    );
  }

  /// Completes a goal.
  /// If [goal] is a Main Goal (parentId == null), awards the +30% descendant XP bonus (one-time).
  /// Sub-goals do NOT receive the completion bonus (Invariant #6).
  Future<int> completeGoal({
    required Goal goal,
    required String ownerId,
  }) async {
    final existing = await database.goalsDao.findById(goal.id);
    if ((existing != null && existing.status == 'completed') ||
        goal.status == 'completed') {
      return 0; // Already completed
    }

    final hlc = Hlc.now(Id.uuidV7());

    // 1. Mark goal completed
    await database.goalsDao.completeGoal(
      goalId: goal.id,
      versionHlc: hlc.toString(),
    );

    // Record immutable activity_event for goal_completed (Phase 7)
    final now = DateTime.now().toUtc();
    await database.into(database.activityEvents).insert(
      ActivityEventsCompanion.insert(
        id: Id.uuidV7().value,
        ownerId: ownerId,
        eventType: 'goal_completed',
        entityType: 'goal',
        entityId: drift.Value(goal.id),
        lifeAreaId: drift.Value(goal.lifeAreaId),
        metadata: drift.Value(
          jsonEncode({
            'title': goal.title,
            'root_id': goal.rootId,
            'is_main_goal': goal.parentId == null,
          }),
        ),
        occurredAt: now,
        versionHlc: hlc.toString(),
        createdAt: now,
      ),
    );

    var streakAreaId = goal.lifeAreaId ?? '';
    if (streakAreaId.isEmpty) {
      final areas =
          await (database.select(database.lifeAreas)
                ..where((l) => l.ownerId.equals(ownerId) & l.deletedAt.isNull())
                ..limit(1))
              .get();
      if (areas.isNotEmpty) streakAreaId = areas.first.id;
    }
    if (streakAreaId.isNotEmpty) {
      await _streakService.recordQualifyingCompletion(
        userId: Id(ownerId),
        sourceId: Id(goal.id),
        lifeAreaId: Id(streakAreaId),
        completedAt: DateTime.now(),
        versionHlc: hlc.toString(),
        deviceId: Id('local_device'),
      );
    }

    // 2. Only Main Goals (root goals) receive the +30% completion bonus!
    final isMainGoal = goal.parentId == null;
    if (!isMainGoal) {
      return 0; // Sub-goals do not receive completion bonus
    }

    // Only XP events actually awarded to child work are eligible. Completion
    // bonuses are excluded so they cannot recursively compound.
    final eligibleChildXp = await eligibleAwardedChildXp(goal.id);
    final bonusPoints = CompletionBonusCalculator.calculate(eligibleChildXp);

    if (bonusPoints > 0) {
      final idempotencyKey = Id('goal_completion_bonus_${goal.id}');
      final alreadyAwarded = await _xpWriter.isIdempotencyKeyProcessed(
        idempotencyKey,
      );

      if (alreadyAwarded) {
        return 0;
      }

      String? effectiveAreaId = goal.lifeAreaId;
      if (effectiveAreaId == null || effectiveAreaId.isEmpty) {
        final areas =
            await (database.select(database.lifeAreas)
                  ..where(
                    (l) => l.ownerId.equals(ownerId) & l.deletedAt.isNull(),
                  )
                  ..limit(1))
                .get();
        effectiveAreaId = areas.isNotEmpty ? areas.first.id : null;
      }
      if (effectiveAreaId == null) return 0;

      await _xpWriter.recordEvent(
        ownerId: Id(ownerId),
        idempotencyKey: idempotencyKey,
        sourceType: 'goal',
        sourceId: Id(goal.id),
        action: 'goal_completion_bonus',
        basePoints: 0,
        bonusPoints: bonusPoints,
        allocationRatios: [
          AllocationRatio(lifeAreaId: Id(effectiveAreaId), percentage: 100.0),
        ],
        clock: hlc,
        deviceId: Id('local_device'),
      );
    }

    return bonusPoints;
  }

  /// Sum net XP awarded for completed Tasks and Sub-goals under a Main Goal.
  /// Reversals reduce the original eligible event; completion bonuses never
  /// become child XP.
  Future<int> eligibleAwardedChildXp(String goalId) async {
    final goal = await database.goalsDao.findById(goalId);
    if (goal == null || goal.parentId != null) return 0;

    final goalTree = await database.goalsDao.descendantsOfRoot(goal.rootId);
    final childGoalIds = goalTree
        .where((child) => child.id != goal.id && child.status == 'completed')
        .map((child) => child.id)
        .toSet();
    final goalIds = {...childGoalIds, goal.id};

    final linkedTasks = await (database.select(
      database.taskGoalLinks,
    )..where((link) => link.goalId.isIn(goalIds))).get();
    final linkedTaskIds = linkedTasks.map((link) => link.taskId).toSet();
    final linkedTaskRows = linkedTaskIds.isEmpty
        ? <Task>[]
        : await (database.select(database.tasks)..where(
                (task) =>
                    task.id.isIn(linkedTaskIds) &
                    task.ownerId.equals(goal.ownerId) &
                    task.deletedAt.isNull(),
              ))
              .get();
    final directTasks =
        await (database.select(database.tasks)..where(
              (task) =>
                  task.primaryGoalId.isIn(goalIds) &
                  task.ownerId.equals(goal.ownerId) &
                  task.deletedAt.isNull(),
            ))
            .get();
    final taskIds = {
      ...linkedTaskRows.map((task) => task.id),
      ...directTasks.map((task) => task.id),
    };

    final eligibleEvents = <XpLedgerData>[];
    if (taskIds.isNotEmpty) {
      eligibleEvents.addAll(
        await (database.select(database.xpLedger)..where(
              (event) =>
                  event.ownerId.equals(goal.ownerId) &
                  event.sourceType.equals('task') &
                  event.sourceId.isIn(taskIds) &
                  event.action.equals('completed'),
            ))
            .get(),
      );
    }
    if (childGoalIds.isNotEmpty) {
      eligibleEvents.addAll(
        await (database.select(database.xpLedger)..where(
              (event) =>
                  event.ownerId.equals(goal.ownerId) &
                  event.sourceType.equals('goal') &
                  event.sourceId.isIn(childGoalIds) &
                  event.action.isNotValue('goal_completion_bonus'),
            ))
            .get(),
      );
    }

    if (eligibleEvents.isEmpty) return 0;
    final eventIds = eligibleEvents.map((event) => event.id).toSet();
    final reversals =
        await (database.select(database.xpLedger)..where(
              (event) =>
                  event.ownerId.equals(goal.ownerId) &
                  event.sourceType.equals('reversal') &
                  event.reversalEventId.isIn(eventIds),
            ))
            .get();
    final netAwardedXp =
        eligibleEvents.fold<int>(0, (sum, event) => sum + event.points) +
        reversals.fold<int>(0, (sum, event) => sum + event.points);
    return netAwardedXp < 0 ? 0 : netAwardedXp;
  }
}
