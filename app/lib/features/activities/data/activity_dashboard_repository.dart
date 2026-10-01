// ignore_for_file: public_member_api_docs
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../../../data/drift/app_database.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../../sessions/domain/session_models.dart';
import '../../streaks/domain/streak_service.dart';
import '../../xp/data/xp_ledger_writer_impl.dart';
import '../../xp/domain/xp_allocation_math.dart';
import '../domain/activity_models.dart';
import '../domain/activity_xp_calculator.dart';

class ActivityDashboardRepository {
  final AppDatabase _db;

  ActivityDashboardRepository(this._db);

  static Duration _clampDuration(Duration value) {
    if (value < Duration.zero) return Duration.zero;
    const max = Duration(hours: 12);
    if (value > max) return max;
    return value;
  }

  Stream<List<ActivityDashboardItem>> watchActivitiesDashboard({
    required String ownerId,
    String? lifeAreaId,
    String? categoryId,
    required ActivityDashboardTime time,
    DateTimeRange? customRange,
  }) {
    // Watch activities table and dependent tables
    final activitiesQuery =
        (_db.select(_db.activities)
              ..where(
                (a) =>
                    a.ownerId.equals(ownerId) &
                    a.deletedAt.isNull() &
                    a.archivedAt.isNull() &
                    (lifeAreaId != null
                        ? a.lifeAreaId.equals(lifeAreaId)
                        : const Constant(true)) &
                    (categoryId != null
                        ? a.categoryId.equals(categoryId)
                        : const Constant(true)),
              )
              ..orderBy([(a) => OrderingTerm.asc(a.name)]))
            .watch();

    return activitiesQuery.asyncMap((activities) async {
      if (activities.isEmpty) return <ActivityDashboardItem>[];

      final range = _dateRange(time, customRange);
      final items = <ActivityDashboardItem>[];

      for (final act in activities) {
        // 1. Life Area Name
        String? lifeAreaName;
        if (act.lifeAreaId != null) {
          final la = await (_db.select(
            _db.lifeAreas,
          )..where((l) => l.id.equals(act.lifeAreaId!))).getSingleOrNull();
          lifeAreaName = la?.name;
        }

        // 2. Category Name
        String? categoryName;
        if (act.categoryId != null) {
          final cat = await (_db.select(
            _db.categories,
          )..where((c) => c.id.equals(act.categoryId!))).getSingleOrNull();
          categoryName = cat?.name;
        }

        // 3. Linked Skills via AttachmentLinks
        final skillLinks =
            await (_db.select(_db.attachmentLinks)..where(
                  (l) =>
                      l.entityId.equals(act.id) &
                      l.entityKind.equals('activity') &
                      l.attachmentKind.equals('skill'),
                ))
                .get();
        final skillNames = <String>[];
        for (final sl in skillLinks) {
          final s = await (_db.select(
            _db.skills,
          )..where((sk) => sk.id.equals(sl.attachmentId))).getSingleOrNull();
          if (s != null) skillNames.add(s.name);
        }

        // 4. Period Sessions
        final periodSessions =
            await (_db.select(_db.sessions)..where(
                  (s) =>
                      s.activityId.equals(act.id) &
                      s.ownerId.equals(ownerId) &
                      s.deletedAt.isNull() &
                      s.startedAt.isBiggerOrEqualValue(range.start.toUtc()) &
                      s.startedAt.isSmallerThanValue(range.end.toUtc()),
                ))
                .get();

        int periodDuration = 0;
        int periodXp = 0;
        final actDifficulty = act.difficulty.clamp(1, 10);
        for (final s in periodSessions) {
          final dur = s.durationMs ?? 0;
          periodDuration += dur;
          // Phase 2: compute XP using ActivityXpCalculator
          periodXp += ActivityXpCalculator.calculateActivityXp(
            actDifficulty,
            _clampDuration(Duration(milliseconds: dur)),
          );
        }

        // 5. Total Sessions
        final allSessions =
            await (_db.select(_db.sessions)
                  ..where(
                    (s) =>
                        s.activityId.equals(act.id) &
                        s.ownerId.equals(ownerId) &
                        s.deletedAt.isNull(),
                  )
                  ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
                .get();

        int totalDuration = 0;
        int totalXp = 0;
        DateTime? lastSession;
        if (allSessions.isNotEmpty) {
          lastSession = allSessions.first.startedAt;
        }

        for (final s in allSessions) {
          final dur = s.durationMs ?? 0;
          totalDuration += dur;
          totalXp += ActivityXpCalculator.calculateActivityXp(
            actDifficulty,
            _clampDuration(Duration(milliseconds: dur)),
          );
        }

        items.add(
          ActivityDashboardItem(
            id: act.id,
            name: act.name,
            description: act.description,
            lifeAreaId: act.lifeAreaId,
            lifeAreaName: lifeAreaName,
            categoryId: act.categoryId,
            categoryName: categoryName,
            targetDurationMinutes: act.targetDurationMinutes,
            difficulty: actDifficulty,
            xpRule: act.xpRule,
            periodSessionCount: periodSessions.length,
            periodTrackedDurationMs: periodDuration,
            periodXpEarned: periodXp,
            totalSessionCount: allSessions.length,
            totalTrackedDurationMs: totalDuration,
            totalXpEarned: totalXp,
            lastSessionAt: lastSession,
            skillNames: skillNames,
          ),
        );
      }

      return items;
    });
  }

  Stream<ActivityDetailData?> watchActivityDetail({
    required String ownerId,
    required String activityId,
  }) {
    final activityStream = (_db.select(
      _db.activities,
    )..where((a) => a.id.equals(activityId))).watchSingleOrNull();

    return activityStream.asyncMap((act) async {
      if (act == null) return null;

      // 1. Life Area Name
      String? lifeAreaName;
      if (act.lifeAreaId != null) {
        final la = await (_db.select(
          _db.lifeAreas,
        )..where((l) => l.id.equals(act.lifeAreaId!))).getSingleOrNull();
        lifeAreaName = la?.name;
      }

      // 2. Category Name
      String? categoryName;
      if (act.categoryId != null) {
        final cat = await (_db.select(
          _db.categories,
        )..where((c) => c.id.equals(act.categoryId!))).getSingleOrNull();
        categoryName = cat?.name;
      }

      // 3. Linked Skills via AttachmentLinks
      final skillLinks =
          await (_db.select(_db.attachmentLinks)..where(
                (l) =>
                    l.entityId.equals(act.id) &
                    l.entityKind.equals('activity') &
                    l.attachmentKind.equals('skill'),
              ))
              .get();
      final skillNames = <String>[];
      for (final sl in skillLinks) {
        final s = await (_db.select(
          _db.skills,
        )..where((sk) => sk.id.equals(sl.attachmentId))).getSingleOrNull();
        if (s != null) skillNames.add(s.name);
      }

      // 4. Total Sessions
      final allSessions =
          await (_db.select(_db.sessions)
                ..where(
                  (s) =>
                      s.activityId.equals(act.id) &
                      s.ownerId.equals(ownerId) &
                      s.deletedAt.isNull(),
                )
                ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
              .get();

      int totalDuration = 0;
      int totalXp = 0;
      DateTime? lastSession;
      if (allSessions.isNotEmpty) {
        lastSession = allSessions.first.startedAt;
      }

      final actDifficulty = act.difficulty.clamp(1, 10);
      for (final s in allSessions) {
        final dur = s.durationMs ?? 0;
        totalDuration += dur;
        totalXp += ActivityXpCalculator.calculateActivityXp(
          actDifficulty,
          _clampDuration(Duration(milliseconds: dur)),
        );
      }

      final avgDuration = allSessions.isNotEmpty
          ? (totalDuration ~/ allSessions.length)
          : 0;

      return ActivityDetailData(
        id: act.id,
        ownerId: act.ownerId,
        name: act.name,
        description: act.description,
        lifeAreaId: act.lifeAreaId,
        lifeAreaName: lifeAreaName,
        categoryId: act.categoryId,
        categoryName: categoryName,
        targetDurationMinutes: act.targetDurationMinutes,
        difficulty: actDifficulty,
        xpRule: act.xpRule,
        totalSessions: allSessions.length,
        totalDurationMs: totalDuration,
        averageDurationMs: avgDuration,
        totalXpEarned: totalXp,
        lastSessionAt: lastSession,
        skillNames: skillNames,
      );
    });
  }

  Stream<List<ActivitySessionLogItem>> watchRecentSessions({
    required String activityId,
    int limit = 30,
  }) {
    final query =
        (_db.select(_db.sessions)
              ..where(
                (s) => s.activityId.equals(activityId) & s.deletedAt.isNull(),
              )
              ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
              ..limit(limit))
            .watch();

    return query.asyncMap((rows) async {
      final act = await (_db.select(
        _db.activities,
      )..where((a) => a.id.equals(activityId))).getSingleOrNull();
      final difficulty = act?.difficulty.clamp(1, 10) ?? 5;
      return rows
          .map((row) {
            final dur = row.durationMs ?? 0;
            final xp = ActivityXpCalculator.calculateActivityXp(
              difficulty,
              _clampDuration(Duration(milliseconds: dur)),
            );
            return ActivitySessionLogItem(
              id: row.id,
              startedAt: row.startedAt,
              endedAt: row.endedAt,
              durationMs: dur,
              note: row.note,
              xpEarned: xp,
            );
          })
          .toList(growable: false);
    });
  }

  Future<String> createActivity({
    required String ownerId,
    required String name,
    required String lifeAreaId,
    String? categoryId,
    String? description,
    int? targetDurationMinutes,
    int difficulty = 5,
    List<String> skillIds = const [],
    ActivityXpRule? xpRule,
  }) async {
    final activityId = Id.uuidV7().value;
    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id(ownerId));
    final clampedDifficulty = difficulty.clamp(1, 10);

    await _db.transaction(() async {
      // 1. Insert Activities row
      await _db
          .into(_db.activities)
          .insert(
            ActivitiesCompanion.insert(
              id: activityId,
              ownerId: ownerId,
              name: name.trim(),
              lifeAreaId: Value(lifeAreaId),
              categoryId: Value(categoryId),
              description: Value(description),
              targetDurationMinutes: Value(targetDurationMinutes),
              difficulty: Value(clampedDifficulty),
              xpRule: Value(xpRule?.toJson()),
              versionHlc: hlc.toString(),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 2. Insert Skill attachments in attachment_links
      for (final skillId in skillIds) {
        await _db.attachmentLinksDao.upsertSkillLink(
          ownerId: ownerId,
          entityId: activityId,
          entityKind: 'activity',
          skillId: skillId,
          versionHlc: hlc.toString(),
        );
      }

      // 3. Enqueue to sync outbox
      await _db
          .into(_db.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              userId: ownerId,
              op: 'upsert',
              entity: 'activities',
              entityId: activityId,
              payloadJson: jsonEncode({
                'id': activityId,
                'owner_id': ownerId,
                'name': name.trim(),
                'life_area_id': lifeAreaId,
                'category_id': categoryId,
                'description': description,
                'target_duration_minutes': targetDurationMinutes,
                'difficulty': clampedDifficulty,
                'xp_rule': xpRule?.toJson(),
                'created_at': now.toIso8601String(),
              }),
              hlc: hlc.toString(),
              deviceId: 'local_device',
            ),
          );

      // 4. Award initial habit-creation XP to Life Area
      final basePoints = xpRule?.flatXp ?? 50;
      if (basePoints > 0) {
        final writer = DriftXpLedgerWriter(_db);
        final idempotencyKey = Id('xp_act_create_$activityId');
        await writer.recordEvent(
          ownerId: Id(ownerId),
          idempotencyKey: idempotencyKey,
          sourceType: 'activity',
          sourceId: Id(activityId),
          action: 'activity_created',
          basePoints: basePoints,
          allocationRatios: [
            AllocationRatio(lifeAreaId: Id(lifeAreaId), percentage: 100.0),
          ],
          clock: hlc,
          deviceId: Id('local_device'),
        );
      }
    });

    return activityId;
  }

  Future<int> quickLogSession({
    required String activityId,
    required String ownerId,
    int durationMinutes = 30,
    String? note,
  }) async {
    final act = await (_db.select(
      _db.activities,
    )..where((a) => a.id.equals(activityId))).getSingle();
    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id(ownerId));
    final durationMs = durationMinutes * 60 * 1000;
    final sessionId = Id.uuidV7().value;

    // Phase 2: use ActivityXpCalculator (same formula as timer path)
    final difficulty = act.difficulty.clamp(1, 10);
    int xpPoints = ActivityXpCalculator.calculateActivityXp(
      difficulty,
      _clampDuration(Duration(minutes: durationMinutes)),
    );
    if (xpPoints < 1) xpPoints = 1;
    final effectiveArea = act.lifeAreaId;

    await _db.transaction(() async {
      await _db
          .into(_db.sessions)
          .insert(
            SessionsCompanion.insert(
              id: sessionId,
              ownerId: ownerId,
              activityId: Value(activityId),
              lifeAreaId: Value(effectiveArea),
              startedAt: now.subtract(
                _clampDuration(Duration(minutes: durationMinutes)),
              ),
              endedAt: Value(now),
              durationMs: Value(durationMs),
              note: Value(note ?? 'Completed focus on ${act.name}'),
              versionHlc: hlc.toString(),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _db
          .into(_db.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              userId: ownerId,
              op: 'upsert',
              entity: 'sessions',
              entityId: sessionId,
              payloadJson: jsonEncode({
                'id': sessionId,
                'owner_id': ownerId,
                'activity_id': activityId,
                'life_area_id': effectiveArea,
                'started_at': now
                    .subtract(
                      _clampDuration(Duration(minutes: durationMinutes)),
                    )
                    .toIso8601String(),
                'ended_at': now.toIso8601String(),
                'duration_ms': durationMs,
              }),
              hlc: hlc.toString(),
              deviceId: 'local_device',
            ),
          );

      if (effectiveArea != null && effectiveArea.isNotEmpty && xpPoints > 0) {
        final writer = DriftXpLedgerWriter(_db);
        final idempotencyKey = Id('xp_sess_$sessionId');
        final streakService = StreakService(_db);

        await writer.recordEvent(
          ownerId: Id(ownerId),
          idempotencyKey: idempotencyKey,
          sourceType: 'session',
          sourceId: Id(sessionId),
          action: 'focus_completed',
          basePoints: xpPoints,
          allocationRatios: [
            AllocationRatio(lifeAreaId: Id(effectiveArea), percentage: 100.0),
          ],
          clock: hlc,
          deviceId: Id('local_device'),
        );

        await streakService.recordQualifyingCompletion(
          userId: Id(ownerId),
          sourceId: Id(sessionId),
          lifeAreaId: Id(effectiveArea),
          completedAt: now,
          versionHlc: hlc.toString(),
          deviceId: Id('local_device'),
        );
      }
    });

    return xpPoints;
  }

  Future<void> updateActivity({
    required String activityId,
    required String ownerId,
    required String name,
    required String lifeAreaId,
    String? categoryId,
    String? description,
    int? targetDurationMinutes,
    int? difficulty,
    List<String> skillIds = const [],
    ActivityXpRule? xpRule,
  }) async {
    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id(ownerId));

    await _db.transaction(() async {
      await (_db.update(
        _db.activities,
      )..where((a) => a.id.equals(activityId))).write(
        ActivitiesCompanion(
          name: Value(name.trim()),
          lifeAreaId: Value(lifeAreaId),
          categoryId: Value(categoryId),
          description: Value(description),
          targetDurationMinutes: Value(targetDurationMinutes),
          difficulty: difficulty != null
              ? Value(difficulty.clamp(1, 10))
              : const Value.absent(),
          xpRule: Value(xpRule?.toJson()),
          versionHlc: Value(hlc.toString()),
          updatedAt: Value(now),
        ),
      );

      // Refresh skill attachments
      await _db.attachmentLinksDao.removeSkillLinksForEntity(
        ownerId: ownerId,
        entityId: activityId,
        entityKind: 'activity',
        versionHlc: hlc.toString(),
      );

      for (final skillId in skillIds) {
        await _db.attachmentLinksDao.upsertSkillLink(
          ownerId: ownerId,
          entityId: activityId,
          entityKind: 'activity',
          skillId: skillId,
          versionHlc: hlc.toString(),
        );
      }

      await _db
          .into(_db.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              userId: ownerId,
              op: 'upsert',
              entity: 'activities',
              entityId: activityId,
              payloadJson: jsonEncode({
                'id': activityId,
                'owner_id': ownerId,
                'name': name.trim(),
                'life_area_id': lifeAreaId,
                'category_id': categoryId,
                'description': description,
                'target_duration_minutes': targetDurationMinutes,
                if (difficulty != null) 'difficulty': difficulty.clamp(1, 10),
                'xp_rule': xpRule?.toJson(),
                'updated_at': now.toIso8601String(),
              }),
              hlc: hlc.toString(),
              deviceId: 'local_device',
            ),
          );
    });
  }

  Future<void> softDeleteActivity(String activityId, String ownerId) async {
    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id(ownerId));

    await _db.transaction(() async {
      await (_db.update(
        _db.activities,
      )..where((a) => a.id.equals(activityId))).write(
        ActivitiesCompanion(
          deletedAt: Value(now),
          deletedBy: Value(ownerId),
          versionHlc: Value(hlc.toString()),
          updatedAt: Value(now),
        ),
      );

      await _db
          .into(_db.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              userId: ownerId,
              op: 'delete',
              entity: 'activities',
              entityId: activityId,
              payloadJson: jsonEncode({
                'id': activityId,
                'deleted_at': now.toIso8601String(),
                'deleted_by': ownerId,
              }),
              hlc: hlc.toString(),
              deviceId: 'local_device',
            ),
          );
    });
  }

  static DateTimeRange _dateRange(
    ActivityDashboardTime time,
    DateTimeRange? custom,
  ) {
    if (time == ActivityDashboardTime.custom) {
      if (custom == null) {
        throw ArgumentError('Custom time requires a date range.');
      }
      final start = DateTime(
        custom.start.year,
        custom.start.month,
        custom.start.day,
      );
      final end = DateTime(
        custom.end.year,
        custom.end.month,
        custom.end.day,
      ).add(const Duration(days: 1));
      return DateTimeRange(start: start, end: end);
    }
    final now = DateTime.now();
    final start = switch (time) {
      ActivityDashboardTime.today => DateTime(now.year, now.month, now.day),
      ActivityDashboardTime.week => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1)),
      ActivityDashboardTime.month => DateTime(now.year, now.month),
      ActivityDashboardTime.custom => throw StateError('unreachable'),
    };
    final end = switch (time) {
      ActivityDashboardTime.today => start.add(const Duration(days: 1)),
      ActivityDashboardTime.week => start.add(const Duration(days: 7)),
      ActivityDashboardTime.month => DateTime(start.year, start.month + 1),
      ActivityDashboardTime.custom => throw StateError('unreachable'),
    };
    return DateTimeRange(start: start, end: end);
  }
}
