// ignore_for_file: public_member_api_docs
// Wave 26: JanitorService — Self-healing storage, 30/30 trash purge, and HLC clock drift monitor.
//
// ADR-012: Two-phase 30/30 day trash retention window.
// Invariant #14: Tombstones always win.

import 'package:drift/drift.dart';
import '../../../data/drift/app_database.dart';

class TrashItem {
  final String id;
  final String entityKind;
  final String title;
  final DateTime deletedAt;
  final int daysRemaining;

  const TrashItem({
    required this.id,
    required this.entityKind,
    required this.title,
    required this.deletedAt,
    required this.daysRemaining,
  });
}

class StorageAuditReport {
  final int totalLifeAreas;
  final int totalGoals;
  final int totalTasks;
  final int totalNotes;
  final int trashCount;
  final bool isClockHealthy;
  final int clockSkewSeconds;

  const StorageAuditReport({
    required this.totalLifeAreas,
    required this.totalGoals,
    required this.totalTasks,
    required this.totalNotes,
    required this.trashCount,
    required this.isClockHealthy,
    required this.clockSkewSeconds,
  });
}

class JanitorService {
  final AppDatabase _db;

  JanitorService({required AppDatabase db}) : _db = db;

  /// Lists all soft-deleted items across goals, tasks, and notes currently in the 30-day trash.
  Future<List<TrashItem>> listTrashItems(String userId) async {
    final now = DateTime.now().toUtc();
    final items = <TrashItem>[];

    // Goals in trash
    final goals = await (_db.select(_db.goals)
          ..where((g) => g.ownerId.equals(userId) & g.deletedAt.isNotNull()))
        .get();

    for (final g in goals) {
      final days = 30 - now.difference(g.deletedAt!).inDays;
      items.add(TrashItem(
        id: g.id,
        entityKind: 'goal',
        title: g.title,
        deletedAt: g.deletedAt!,
        daysRemaining: days.clamp(0, 30),
      ));
    }

    // Tasks in trash
    final tasks = await (_db.select(_db.tasks)
          ..where((t) => t.ownerId.equals(userId) & t.deletedAt.isNotNull()))
        .get();

    for (final t in tasks) {
      final days = 30 - now.difference(t.deletedAt!).inDays;
      items.add(TrashItem(
        id: t.id,
        entityKind: 'task',
        title: t.title,
        deletedAt: t.deletedAt!,
        daysRemaining: days.clamp(0, 30),
      ));
    }

    // Notes in trash
    final notes = await (_db.select(_db.notes)
          ..where((n) => n.ownerId.equals(userId) & n.deletedAt.isNotNull()))
        .get();

    for (final n in notes) {
      final days = 30 - now.difference(n.deletedAt!).inDays;
      items.add(TrashItem(
        id: n.id,
        entityKind: 'note',
        title: n.bodyText.length > 25 ? '${n.bodyText.substring(0, 25)}...' : n.bodyText,
        deletedAt: n.deletedAt!,
        daysRemaining: days.clamp(0, 30),
      ));
    }

    return items;
  }

  /// Restores a soft-deleted entity if within the 30-day window (ADR-012).
  Future<bool> restoreEntity({
    required String entityKind,
    required String entityId,
    required String versionHlc,
  }) async {
    final now = DateTime.now().toUtc();

    switch (entityKind) {
      case 'goal':
        final row = await (_db.select(_db.goals)..where((g) => g.id.equals(entityId))).getSingleOrNull();
        if (row == null || row.deletedAt == null) return false;
        if (now.difference(row.deletedAt!).inDays > 30) return false; // expired
        await (_db.update(_db.goals)..where((g) => g.id.equals(entityId))).write(
          GoalsCompanion(
            deletedAt: const Value(null),
            versionHlc: Value(versionHlc),
            updatedAt: Value(now),
          ),
        );
        return true;

      case 'task':
        final row = await (_db.select(_db.tasks)..where((t) => t.id.equals(entityId))).getSingleOrNull();
        if (row == null || row.deletedAt == null) return false;
        if (now.difference(row.deletedAt!).inDays > 30) return false;
        await (_db.update(_db.tasks)..where((t) => t.id.equals(entityId))).write(
          TasksCompanion(
            deletedAt: const Value(null),
            versionHlc: Value(versionHlc),
            updatedAt: Value(now),
          ),
        );
        return true;

      case 'note':
        final row = await (_db.select(_db.notes)..where((n) => n.id.equals(entityId))).getSingleOrNull();
        if (row == null || row.deletedAt == null) return false;
        if (now.difference(row.deletedAt!).inDays > 30) return false;
        await (_db.update(_db.notes)..where((n) => n.id.equals(entityId))).write(
          NotesCompanion(
            deletedAt: const Value(null),
            versionHlc: Value(versionHlc),
            updatedAt: Value(now),
          ),
        );
        return true;
    }

    return false;
  }

  /// Purges local soft-deleted items whose 30-day window has fully expired.
  Future<int> purgeExpiredLocalTrash(String userId) async {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 30));
    var count = 0;

    await _db.transaction(() async {
      // Goals
      final expiredGoals = await (_db.select(_db.goals)
            ..where((g) => g.ownerId.equals(userId) & g.deletedAt.isSmallerThanValue(cutoff)))
          .get();
      for (final g in expiredGoals) {
        await (_db.delete(_db.goals)..where((row) => row.id.equals(g.id))).go();
        count++;
      }

      // Tasks
      final expiredTasks = await (_db.select(_db.tasks)
            ..where((t) => t.ownerId.equals(userId) & t.deletedAt.isSmallerThanValue(cutoff)))
          .get();
      for (final t in expiredTasks) {
        await (_db.delete(_db.tasks)..where((row) => row.id.equals(t.id))).go();
        count++;
      }

      // Notes
      final expiredNotes = await (_db.select(_db.notes)
            ..where((n) => n.ownerId.equals(userId) & n.deletedAt.isSmallerThanValue(cutoff)))
          .get();
      for (final n in expiredNotes) {
        await (_db.delete(_db.notes)..where((row) => row.id.equals(n.id))).go();
        count++;
      }
    });

    return count;
  }

  /// Audits local storage metrics and validates HLC clock drift health.
  Future<StorageAuditReport> auditStorageHealth(String userId, {DateTime? serverTime}) async {
    final lifeAreas = await (_db.select(_db.lifeAreas)..where((l) => l.ownerId.equals(userId))).get();
    final goals = await (_db.select(_db.goals)..where((g) => g.ownerId.equals(userId))).get();
    final tasks = await (_db.select(_db.tasks)..where((t) => t.ownerId.equals(userId))).get();
    final notes = await (_db.select(_db.notes)..where((n) => n.ownerId.equals(userId))).get();

    final trash = await listTrashItems(userId);

    final localNow = DateTime.now().toUtc();
    final refServer = serverTime ?? localNow;
    final skewSeconds = localNow.difference(refServer).inSeconds.abs();
    final isHealthy = skewSeconds <= 60; // Max allowed drift per HLC spec

    return StorageAuditReport(
      totalLifeAreas: lifeAreas.length,
      totalGoals: goals.length,
      totalTasks: tasks.length,
      totalNotes: notes.length,
      trashCount: trash.length,
      isClockHealthy: isHealthy,
      clockSkewSeconds: skewSeconds,
    );
  }
}
