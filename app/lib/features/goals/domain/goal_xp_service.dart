// ignore_for_file: public_member_api_docs
// Wave 8: Goal & Task XP Integration Service.
// Enforces the Main Goal completion bonus contract:
// +30% of positive descendant XP, one-time, no compounding, idempotent.

import 'package:drift/drift.dart' as drift;

import '../../../../data/drift/app_database.dart';
import '../../../../domain/hlc.dart';
import '../../../../domain/ids.dart';
import '../../streaks/domain/streak_service.dart';
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
  /// XP modifiers applied (per ADR-005, Invariants #6, #7, #8):
  ///   - Late penalty: −30% of baseXp when task.dueDate is past AND status ≠ 'cancelled'
  ///   - Streak bonus: +20% of baseXp when the life area has a 7+ day streak
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
      if (category != null) {
        baseXp = category.baseXp;
        final ruleVer = await database.categoriesDao.activeRuleVersion(category.id);
        ruleVersionId = ruleVer?.id;
      }
    }

    // 2. Resolve Life Area
    String effectiveAreaId = lifeAreaId ?? '';
    if (effectiveAreaId.isEmpty) {
      final areas = await (database.select(database.lifeAreas)
            ..where((l) => l.ownerId.equals(ownerId) & l.deletedAt.isNull())
            ..limit(1))
          .get();
      if (areas.isNotEmpty) {
        effectiveAreaId = areas.first.id;
      } else {
        effectiveAreaId = 'la_default';
      }
    }

    // 3. Mark task completed
    await (database.update(database.tasks)..where((t) => t.id.equals(task.id))).write(
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

      // 4b. Streak bonus: +20% when life area streak >= 7 days (ADR-005)
      final streakInfo = await _streakService.getStreakForLifeArea(
        userId: Id(ownerId),
        lifeAreaId: Id(effectiveAreaId),
      );
      final streakBonus = streakInfo.calculateStreakBonus(baseXp);

      await _xpWriter.recordEvent(
        ownerId: Id(ownerId),
        idempotencyKey: idempotencyKey,
        sourceType: 'task',
        sourceId: Id(task.id),
        action: 'completed',
        basePoints: baseXp,
        latePenalty: latePenalty,
        streakBonus: streakBonus,
        allocationRatios: [
          AllocationRatio(lifeAreaId: Id(effectiveAreaId), percentage: 100.0),
        ],
        clock: hlc,
        deviceId: Id('local_device'),
        categoryRuleVersionId: ruleVersionId != null ? Id(ruleVersionId) : null,
      );

      // 4c. Log streak activity so streak counter advances (ADR-005)
      await _streakService.logActivity(
        userId: Id(ownerId),
        lifeAreaId: Id(effectiveAreaId),
        activityDate: now,
        versionHlc: hlc.toString(),
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
    final directTasks = await (database.select(database.tasks)
          ..where((t) => t.primaryGoalId.equals(goalId) & t.deletedAt.isNull()))
        .get();

    final allTaskIds = {...taskIds, ...directTasks.map((t) => t.id)}.toList();
    if (allTaskIds.isEmpty) return;

    final tasks = await (database.select(database.tasks)
          ..where((t) => t.id.isIn(allTaskIds) & t.deletedAt.isNull()))
        .get();

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
    if ((existing != null && existing.status == 'completed') || goal.status == 'completed') {
      return 0; // Already completed
    }

    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id.uuidV7());

    // 1. Mark goal completed
    await database.goalsDao.completeGoal(
      goalId: goal.id,
      versionHlc: hlc.toString(),
    );

    // 2. Only Main Goals (root goals) receive the +30% completion bonus!
    final isMainGoal = goal.parentId == null;
    if (!isMainGoal) {
      return 0; // Sub-goals do not receive completion bonus
    }

    // 3. Compute all positive descendant XP
    // Descendants include tasks under this root goal and all sub-goals of this root
    final allDescendantGoals = await database.goalsDao.descendantsOfRoot(goal.rootId);
    final allGoalIds = allDescendantGoals.map((g) => g.id).toList();

    // Find all tasks linked to any of these goals
    final links = await (database.select(database.taskGoalLinks)
          ..where((l) => l.goalId.isIn(allGoalIds)))
        .get();
    final directTasks = await (database.select(database.tasks)
          ..where((t) => t.primaryGoalId.isIn(allGoalIds) & t.deletedAt.isNull()))
        .get();

    final allTaskIds = {
      ...links.map((l) => l.taskId),
      ...directTasks.map((t) => t.id),
    }.toList();

    int descendantXpTotal = 0;
    if (allTaskIds.isNotEmpty) {
      final ledgerRows = await (database.select(database.xpLedger)
            ..where((r) =>
                r.sourceType.equals('task') &
                r.sourceId.isIn(allTaskIds) &
                r.points.isBiggerThanValue(0)))
          .get();

      descendantXpTotal = ledgerRows.fold(0, (sum, r) => sum + r.points);
    }

    // Contract: +30% of positive descendant XP (one time, no compounding)
    // If no tasks were completed yet, use 30% of target XP or minimum base
    final bonusPoints = descendantXpTotal > 0
        ? (descendantXpTotal * 0.30).round()
        : ((goal.xpTarget ?? 500) * 0.30).round();

    if (bonusPoints > 0) {
      final idempotencyKey = Id('xp_main_goal_bonus_${goal.id}');
      final alreadyAwarded = await _xpWriter.isIdempotencyKeyProcessed(idempotencyKey);

      if (alreadyAwarded) {
        return 0;
      }

      String effectiveAreaId = goal.lifeAreaId ?? '';
      if (effectiveAreaId.isEmpty) {
        final areas = await (database.select(database.lifeAreas)
              ..where((l) => l.ownerId.equals(ownerId) & l.deletedAt.isNull())
              ..limit(1))
            .get();
        effectiveAreaId = areas.isNotEmpty ? areas.first.id : 'la_default';
      }

      await _xpWriter.recordEvent(
        ownerId: Id(ownerId),
        idempotencyKey: idempotencyKey,
        sourceType: 'goal',
        sourceId: Id(goal.id),
        action: 'goal_completion_bonus',
        basePoints: bonusPoints,
        allocationRatios: [
          AllocationRatio(lifeAreaId: Id(effectiveAreaId), percentage: 100.0),
        ],
        clock: hlc,
        deviceId: Id('local_device'),
      );
    }

    return bonusPoints;
  }
}
