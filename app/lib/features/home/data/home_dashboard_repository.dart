import 'dart:async';

import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../domain/ids.dart';
import '../../levels/data/levels_dashboard_repository.dart';
import '../../profile/domain/profile_models.dart';
import '../../progression/domain/progression_calculator.dart';
import '../../progression/domain/global_progression.dart';
import '../../progression/domain/progression_models.dart';
import '../../streaks/domain/streak_models.dart';
import '../../streaks/domain/streak_config.dart';
import '../../streaks/data/streaks_dao.dart';
import '../domain/home_models.dart';

class HomeDashboardRepository {
  final AppDatabase database;
  final LevelsDashboardRepository _levelsRepo;

  HomeDashboardRepository(this.database)
    : _levelsRepo = LevelsDashboardRepository(database);

  /// Reactive stream yielding unified Home Dashboard state on any relevant table changes.
  Stream<HomeDashboardData> watchHomeDashboard(String ownerId) {
    final triggerStream = database
        .customSelect(
          'SELECT 1',
          readsFrom: {
            database.users,
            database.lifeAreas,
            database.xpLedger,
            database.xpAllocationLines,
            database.tasks,
            database.goals,
            database.projects,
            database.sessions,
            database.activities,
            database.userStreaks,
          },
        )
        .watch();

    // Drift's customSelect watcher does not guarantee an initial emission on
    // every executor/platform. Emit a real first snapshot so the dashboard
    // cannot remain on an indeterminate loading animation (and so consumers
    // receive the same contract on native and web).
    return (() async* {
      yield await getHomeDashboard(ownerId);
      yield* triggerStream.asyncMap((_) => getHomeDashboard(ownerId));
    })();
  }

  /// Calculates a snapshot of all Home data.
  Future<HomeDashboardData> getHomeDashboard(String ownerId) async {
    // 1. Profile data directly from users table
    final userRow = await (database.select(
      database.users,
    )..where((u) => u.id.equals(ownerId))).getSingleOrNull();

    final baseProfile = UserProfileData(
      userId: Id(ownerId),
      displayName: userRow?.displayName ?? 'Operative',
      caption: userRow?.caption,
      avatarUrl: userRow?.avatarUrl,
      email: userRow?.email,
      timezone: userRow?.timezone ?? 'UTC',
      createdAt: userRow?.createdAt ?? DateTime.now().toUtc(),
      primaryXpDomain: 'General',
      highestLevel: '',
      totalXp: 0,
    );

    // 2. Life Area Progression entries
    final progressions = await _levelsRepo.getProgressions(ownerId);

    // 3. Compute Aggregate XP and Range across active Life Areas
    final aggregateProgression = _computeAggregateProgression(progressions);
    final globalProgression = GlobalProgressionDefinitions.resolve(
      aggregateProgression.totalXp,
    );
    final profile = baseProfile.copyWith(
      primaryXpDomain: globalProgression.currentLevel.name,
      highestLevel:
          '${globalProgression.currentLevel.name} ${globalProgression.currentLevel.romanNumeral}',
      totalXp: aggregateProgression.totalXp,
    );

    // 4. Ending Today items (Tasks, Goals, Projects)
    final endingTodayItems = await _getEndingTodayItems(ownerId);

    // 5. Recent items (Tasks, Goals, Projects, Sessions)
    final recentItems = await _getRecentItems(ownerId);

    // 6. Streak info
    final streakInfo = await _getStreakInfo(ownerId);
    final workSummary = await _getWorkSummary(ownerId);

    return HomeDashboardData(
      profile: profile,
      aggregateProgression: aggregateProgression,
      lifeAreaEntries: progressions,
      endingTodayItems: endingTodayItems,
      recentItems: recentItems,
      streakInfo: streakInfo,
      workSummary: workSummary,
    );
  }

  Future<HomeWorkSummary> _getWorkSummary(String ownerId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toUtc();
    final end = start.add(const Duration(days: 1));
    final activeStatuses = const ['pending', 'in_progress', 'active', 'paused'];

    final tasks = await (database.select(database.tasks)
          ..where((t) => t.ownerId.equals(ownerId) & t.deletedAt.isNull()))
        .get();
    final goals = await (database.select(database.goals)
          ..where((g) => g.ownerId.equals(ownerId) & g.deletedAt.isNull()))
        .get();
    final projects = await (database.select(database.projects)
          ..where((p) => p.ownerId.equals(ownerId) & p.deletedAt.isNull()))
        .get();

    bool isCompleted(String status) =>
        status == 'completed' || status == 'done';
    bool isActive(String status) => activeStatuses.contains(status);

    return HomeWorkSummary(
      activeTasks: tasks.where((t) => isActive(t.status)).length,
      completedTasks: tasks.where((t) => isCompleted(t.status)).length,
      dueTodayTasks: tasks.where((t) {
        final due = t.dueDate;
        return isActive(t.status) &&
            due != null &&
            !due.isBefore(start) &&
            due.isBefore(end);
      }).length,
      overdueTasks: tasks.where((t) {
        final due = t.dueDate;
        return isActive(t.status) && due != null && due.isBefore(start);
      }).length,
      activeGoals: goals.where((g) => isActive(g.status)).length,
      completedGoals: goals.where((g) => isCompleted(g.status)).length,
      activeProjects: projects.where((p) => isActive(p.status)).length,
      completedProjects: projects.where((p) => isCompleted(p.status)).length,
    );
  }

  /// Derives the aggregate progression range according to the established KRATOS progression contract.
  HomeAggregateProgression _computeAggregateProgression(
    List<LevelsDashboardEntry> entries,
  ) {
    if (entries.isEmpty) {
      return HomeAggregateProgression.empty();
    }

    final curves = ProgressionCalculator.defaultCurves;
    int totalXp = 0;
    int minRangeXp = 0;
    int maxRangeXp = 0;

    for (final entry in entries) {
      final areaXp = entry.progression.totalXp;
      totalXp += areaXp;

      // Identify curve for entry level
      final currentLevel = entry.progression.level;
      LevelCurveSnapshot currentCurve = curves.first;
      LevelCurveSnapshot nextCurve = curves.length > 1
          ? curves[1]
          : curves.first;

      for (var i = 0; i < curves.length; i++) {
        if (curves[i].level == currentLevel) {
          currentCurve = curves[i];
          if (i + 1 < curves.length) {
            nextCurve = curves[i + 1];
          } else {
            nextCurve = curves[i];
          }
          break;
        }
      }

      minRangeXp += currentCurve.cumulativeXpRequired;
      maxRangeXp += nextCurve.cumulativeXpRequired;
    }

    double progressPct = 0.0;
    if (maxRangeXp > minRangeXp) {
      progressPct = ((totalXp - minRangeXp) / (maxRangeXp - minRangeXp) * 100.0)
          .clamp(0.0, 100.0);
    } else {
      progressPct = 100.0;
    }

    return HomeAggregateProgression(
      totalXp: totalXp,
      minRangeXp: minRangeXp,
      maxRangeXp: maxRangeXp,
      progressPct: progressPct,
    );
  }

  /// Queries all real actionable entities ending today in user's local timezone.
  Future<List<HomeEndingTodayItem>> _getEndingTodayItems(String ownerId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final startUtc = startOfDay.toUtc();
    final endUtc = endOfDay.toUtc();

    // Cache life areas for quick name lookup
    final lifeAreas = await (database.select(
      database.lifeAreas,
    )..where((a) => a.ownerId.equals(ownerId) & a.deletedAt.isNull())).get();
    final lifeAreaNames = {for (var la in lifeAreas) la.id: la.name};

    final items = <HomeEndingTodayItem>[];

    // 1. Tasks ending today
    final tasksQuery = database.select(database.tasks)
      ..where(
        (t) =>
            t.ownerId.equals(ownerId) &
            t.deletedAt.isNull() &
            t.dueDate.isBiggerOrEqualValue(startUtc) &
            t.dueDate.isSmallerThanValue(endUtc) &
            t.status.isNotIn(const ['completed', 'done']),
      );

    final tasks = await tasksQuery.get();
    for (final task in tasks) {
      items.add(
        HomeEndingTodayItem(
          id: task.id,
          title: task.title,
          type: EndingTodayType.task,
          typeLabel: 'Task',
          lifeAreaName: task.lifeAreaId != null
              ? lifeAreaNames[task.lifeAreaId]
              : null,
          dueDate: task.dueDate!.toLocal(),
        ),
      );
    }

    // 2. Goals ending today
    final goalsQuery = database.select(database.goals)
      ..where(
        (g) =>
            g.ownerId.equals(ownerId) &
            g.deletedAt.isNull() &
            g.dueDate.isBiggerOrEqualValue(startUtc) &
            g.dueDate.isSmallerThanValue(endUtc) &
            g.status.isNotIn(const ['completed', 'done']),
      );

    final goals = await goalsQuery.get();
    for (final goal in goals) {
      items.add(
        HomeEndingTodayItem(
          id: goal.id,
          title: goal.title,
          type: EndingTodayType.goal,
          typeLabel: 'Goal',
          lifeAreaName: goal.lifeAreaId != null
              ? lifeAreaNames[goal.lifeAreaId]
              : null,
          dueDate: goal.dueDate!.toLocal(),
        ),
      );
    }

    // 3. Projects ending today
    final projectsQuery = database.select(database.projects)
      ..where(
        (p) =>
            p.ownerId.equals(ownerId) &
            p.deletedAt.isNull() &
            p.dueDate.isBiggerOrEqualValue(startUtc) &
            p.dueDate.isSmallerThanValue(endUtc) &
            p.status.isNotIn(const ['completed', 'done']),
      );

    final projects = await projectsQuery.get();
    for (final project in projects) {
      items.add(
        HomeEndingTodayItem(
          id: project.id,
          title: project.title,
          type: EndingTodayType.project,
          typeLabel: 'Project',
          lifeAreaName: project.lifeAreaId != null
              ? lifeAreaNames[project.lifeAreaId]
              : null,
          dueDate: project.dueDate!.toLocal(),
        ),
      );
    }

    items.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return items;
  }

  /// Cross-system snapshot of recently updated or completed items.
  Future<List<HomeRecentItem>> _getRecentItems(String ownerId) async {
    final recent = <HomeRecentItem>[];

    // 1. Recent Tasks (latest 3)
    final recentTasks =
        await (database.select(database.tasks)
              ..where((t) => t.ownerId.equals(ownerId) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
              ..limit(3))
            .get();

    for (final t in recentTasks) {
      final isComp = t.status == 'completed' || t.status == 'done';
      recent.add(
        HomeRecentItem(
          id: t.id,
          title: t.title,
          subtitle: isComp ? 'Completed Task' : 'Task in progress',
          type: HomeRecentType.task,
          timestamp: t.completedAt ?? t.updatedAt,
          isCompleted: isComp,
        ),
      );
    }

    // 2. Recent Goals (latest 3)
    final recentGoals =
        await (database.select(database.goals)
              ..where((g) => g.ownerId.equals(ownerId) & g.deletedAt.isNull())
              ..orderBy([(g) => OrderingTerm.desc(g.updatedAt)])
              ..limit(3))
            .get();

    for (final g in recentGoals) {
      final isComp = g.status == 'completed' || g.status == 'done';
      recent.add(
        HomeRecentItem(
          id: g.id,
          title: g.title,
          subtitle: isComp ? 'Achieved Goal' : 'Updated Goal',
          type: HomeRecentType.goal,
          timestamp: g.completedAt ?? g.updatedAt,
          isCompleted: isComp,
        ),
      );
    }

    // 3. Recent Projects (latest 3)
    final recentProjects =
        await (database.select(database.projects)
              ..where((p) => p.ownerId.equals(ownerId) & p.deletedAt.isNull())
              ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)])
              ..limit(3))
            .get();

    for (final p in recentProjects) {
      final isComp = p.status == 'completed' || p.status == 'done';
      recent.add(
        HomeRecentItem(
          id: p.id,
          title: p.title,
          subtitle: isComp ? 'Completed Project' : 'Project updated',
          type: HomeRecentType.project,
          timestamp: p.updatedAt,
          isCompleted: isComp,
        ),
      );
    }

    // 4. Recent Sessions (latest 3)
    final sessionsWithActivities =
        await (database.select(database.sessions).join([
                leftOuterJoin(
                  database.activities,
                  database.activities.id.equalsExp(
                    database.sessions.activityId,
                  ),
                ),
              ])
              ..where(
                database.sessions.ownerId.equals(ownerId) &
                    database.sessions.deletedAt.isNull(),
              )
              ..orderBy([OrderingTerm.desc(database.sessions.startedAt)])
              ..limit(3))
            .get();

    for (final row in sessionsWithActivities) {
      final session = row.readTable(database.sessions);
      final activity = row.readTableOrNull(database.activities);
      final title = activity?.name ?? session.note ?? 'Time Capture Session';
      final minutes = session.durationMs != null
          ? (session.durationMs! / 60000).round()
          : 0;

      recent.add(
        HomeRecentItem(
          id: session.id,
          title: title,
          subtitle: minutes > 0 ? '$minutes min session' : 'Live session',
          type: HomeRecentType.session,
          timestamp: session.startedAt,
          isCompleted: session.endedAt != null,
        ),
      );
    }

    final recentEvents = await (database.select(database.activityEvents)
          ..where((e) => e.ownerId.equals(ownerId))
          ..orderBy([(e) => OrderingTerm.desc(e.occurredAt)])
          ..limit(3))
        .get();
    for (final event in recentEvents) {
      recent.add(
        HomeRecentItem(
          id: event.id,
          title: event.entityType.isEmpty
              ? 'System activity'
              : event.entityType,
          subtitle: event.eventType,
          type: HomeRecentType.activityEvent,
          timestamp: event.occurredAt,
        ),
      );
    }

    // Sort all recent items by real persisted timestamp descending
    recent.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return recent;
  }

  /// Reads streak info from database streaksDao.
  Future<StreakInfo> _getStreakInfo(String ownerId) async {
    try {
      final streaks = await database.streaksDao.allStreaksForUser(ownerId);
      final global = streaks.where(
        (streak) => streak.lifeAreaId == StreaksDao.globalStreakKey,
      );
      final globalStreak = global.isEmpty ? null : global.first;
      final visibleStreaks = globalStreak == null ? streaks : [globalStreak];
      int currentStreak = 0;
      int longestStreak = 0;
      for (final s in visibleStreaks) {
        if (s.currentStreak > currentStreak) currentStreak = s.currentStreak;
        if (s.longestStreak > longestStreak) longestStreak = s.longestStreak;
      }
      final freezes = globalStreak == null
          ? StreakConfig.maxFreezes
          : await database.streaksDao.globalFreezesAvailable(ownerId);
      return StreakInfo.create(
        userId: Id(ownerId),
        lifeAreaId: const Id(StreaksDao.globalStreakKey),
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        freezeTokensAvailable: freezes,
      );
    } catch (_) {
      return StreakInfo.create(
        userId: Id(ownerId),
        lifeAreaId: const Id(StreaksDao.globalStreakKey),
        currentStreak: 0,
        longestStreak: 0,
        freezeTokensAvailable: StreakConfig.maxFreezes,
      );
    }
  }
}
