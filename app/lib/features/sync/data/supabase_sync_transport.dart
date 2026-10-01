import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/drift/app_database.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../../notifications/data/notifications_dao.dart';
import '../../notifications/domain/notification_models.dart';
import '../domain/sync_models.dart';

class SupabaseSyncTransport implements SyncTransport {
  final SupabaseClient _client;
  final bool verifyAuthSession;

  SupabaseSyncTransport(this._client, {this.verifyAuthSession = true});

  @override
  Future<List<SyncAcknowledgement>> pushBatch({
    required String userId,
    required String deviceId,
    required List<SyncItem> items,
  }) async {
    if (verifyAuthSession) {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw const SyncTransportException(
          message: 'No active Supabase authentication session.',
          code: 'unauthenticated',
          retryable: false,
        );
      }
      if (currentUser.id != userId) {
        throw SyncTransportException(
          message: 'Authentication session mismatch: current session (${currentUser.id}) does not match sync user ($userId)',
          code: 'auth_mismatch',
          retryable: false,
        );
      }
    }
    try {
      final response = await _client.rpc(
        'apply_sync_batch',
        params: {
          'p_user_id': userId,
          'p_device_id': deviceId,
          'p_changes': items.map((item) => item.toBatchPayload()).toList(),
        },
      );
      if (response is! Map || response['status'] != 'success') {
        throw const SyncTransportException(
          message: 'The server did not confirm the sync batch.',
          code: 'invalid_acknowledgement',
          retryable: true,
        );
      }
      final rawResults = response['results'];
      if (rawResults is! List) {
        throw const SyncTransportException(
          message:
              'The server response contains no per-operation acknowledgements.',
          code: 'missing_acknowledgements',
          retryable: true,
        );
      }
      final acknowledgements = rawResults
          .map((raw) {
            if (raw is! Map || raw['seq'] is! num || raw['status'] is! String) {
              throw const SyncTransportException(
                message: 'The server returned a malformed operation acknowledgement.',
                code: 'malformed_acknowledgement',
                retryable: true,
              );
            }
            return SyncAcknowledgement(
              seq: (raw['seq'] as num).toInt(),
              status: raw['status'] as String,
            );
          })
          .toList(growable: false);
      final expected = items.map((item) => item.seq).toSet();
      final actual = acknowledgements.map((item) => item.seq).toSet();
      if (actual.length != acknowledgements.length ||
          actual.length != expected.length ||
          !actual.containsAll(expected) ||
          acknowledgements.any(
            (a) => !{'applied', 'skipped', 'duplicate'}.contains(a.status),
          )) {
        throw const SyncTransportException(
          message:
              'The server acknowledgement does not match the submitted batch.',
          code: 'incomplete_acknowledgement',
          retryable: true,
        );
      }
      return acknowledgements;
    } on SyncTransportException {
      rethrow;
    } on PostgrestException catch (error) {
      final code = error.code ?? 'postgrest_error';
      final permanent =
          code.startsWith('22') ||
          code.startsWith('23') ||
          code.startsWith('0A') ||
          code == 'P0001';
      throw SyncTransportException(
        message: error.message,
        code: code,
        retryable: !permanent,
      );
    } catch (error) {
      throw SyncTransportException(
        message: error.toString(),
        code: 'transport_error',
        retryable: true,
      );
    }
  }

  @override
  Future<void> pullChanges({
    required String userId,
    required String deviceId,
    required AppDatabase database,
  }) async {
    if (verifyAuthSession) {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw const SyncTransportException(
          message: 'No active Supabase authentication session.',
          code: 'unauthenticated',
          retryable: false,
        );
      }
      if (currentUser.id != userId) {
        throw SyncTransportException(
          message: 'Authentication session mismatch: current session (${currentUser.id}) does not match sync user ($userId)',
          code: 'auth_mismatch',
          retryable: false,
        );
      }
    }
    try {
      // 1. Pull remote tombstones first (Tombstone always wins, Invariant #14)
      final remoteTombstones = await _client
          .from('sync_tombstones')
          .select()
          .eq('user_id', userId);

      for (final t in (remoteTombstones as List)) {
        final id = (t['id'] as String?) ?? (t['entity_id'] as String);
        final entity = t['entity'] as String;
        final entityId = t['entity_id'] as String;
        final deletedAt = DateTime.parse(t['deleted_at'] as String);
        final deletedHlc = t['deleted_hlc'] as String;
        final deletedBy = t['deleted_by'] as String?;
        final reason = t['reason'] as String?;

        await database.into(database.syncTombstones).insertOnConflictUpdate(
          SyncTombstonesCompanion(
            id: Value(id),
            userId: Value(userId),
            entity: Value(entity),
            entityId: Value(entityId),
            deletedAt: Value(deletedAt),
            deletedHlc: Value(deletedHlc),
            deletedBy: Value(deletedBy),
            reason: Value(reason),
          ),
        );

        // Delete from local table if present
        switch (entity) {
          case 'tasks':
            await (database.delete(database.tasks)..where((r) => r.id.equals(entityId))).go();
            break;
          case 'goals':
            await (database.delete(database.goals)..where((r) => r.id.equals(entityId))).go();
            break;
          case 'projects':
            await (database.delete(database.projects)..where((r) => r.id.equals(entityId))).go();
            break;
          case 'activities':
            await (database.delete(database.activities)..where((r) => r.id.equals(entityId))).go();
            break;
          case 'sessions':
            await (database.delete(database.sessions)..where((r) => r.id.equals(entityId))).go();
            break;
          case 'categories':
            await (database.delete(database.categories)..where((r) => r.id.equals(entityId))).go();
            break;
          case 'life_areas':
            await (database.delete(database.lifeAreas)..where((r) => r.id.equals(entityId))).go();
            break;
          case 'skills':
            await (database.delete(database.skills)..where((r) => r.id.equals(entityId))).go();
            break;
          case 'decisions':
            await (database.delete(database.decisions)..where((r) => r.id.equals(entityId))).go();
            break;
        }
      }

      // Collect active tombstone keys and pending outbox entity keys to protect local state
      final localTombstones = await (database.select(database.syncTombstones)
            ..where((t) => t.userId.equals(userId)))
          .get();
      final tombstonedKeys = localTombstones.map((t) => '${t.entity}:${t.entityId}').toSet();

      final pendingOutbox = await database.syncDao.getPendingItems(userId, limit: 500);
      final pendingKeys = pendingOutbox.map((item) => '${item.entity}:${item.entityId}').toSet();

      // 2. Tasks
      final remoteTasks = await _client.from('tasks').select().eq('owner_id', userId);
      for (final row in (remoteTasks as List)) {
        final id = row['id'] as String;
        final key = 'tasks:$id';
        if (tombstonedKeys.contains(key) || pendingKeys.contains(key)) continue;
        final remoteHlc = row['version_hlc'] as String;
        final local = await (database.select(database.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (local != null && Hlc.parse(remoteHlc).compareTo(Hlc.parse(local.versionHlc)) <= 0) {
          continue;
        }
        await database.into(database.tasks).insertOnConflictUpdate(
          TasksCompanion(
            id: Value(id),
            ownerId: Value(row['owner_id'] as String),
            projectId: Value(row['project_id'] as String?),
            primaryGoalId: Value(row['primary_goal_id'] as String?),
            title: Value(row['title'] as String),
            notes: Value(row['notes'] as String?),
            dueDate: Value(row['due_date'] != null ? DateTime.parse(row['due_date'] as String) : null),
            priority: Value((row['priority'] as num?)?.toInt() ?? 0),
            status: Value(row['status'] as String? ?? 'open'),
            sortOrder: Value((row['sort_order'] as num?)?.toInt() ?? 0),
            xpReward: Value((row['xp_reward'] as num?)?.toInt()),
            recurringRule: Value(row['recurring_rule'] as String?),
            completedAt: Value(row['completed_at'] != null ? DateTime.parse(row['completed_at'] as String) : null),
            completedHlc: Value(row['completed_hlc'] as String?),
            deletedAt: Value(row['deleted_at'] != null ? DateTime.parse(row['deleted_at'] as String) : null),
            versionHlc: Value(remoteHlc),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
            updatedAt: Value(DateTime.parse(row['updated_at'] as String)),
          ),
        );
      }

      // 3. Goals
      final remoteGoals = await _client.from('goals').select().eq('owner_id', userId);
      for (final row in (remoteGoals as List)) {
        final id = row['id'] as String;
        final key = 'goals:$id';
        if (tombstonedKeys.contains(key) || pendingKeys.contains(key)) continue;
        final remoteHlc = row['version_hlc'] as String;
        final local = await (database.select(database.goals)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (local != null && Hlc.parse(remoteHlc).compareTo(Hlc.parse(local.versionHlc)) <= 0) {
          continue;
        }
        await database.into(database.goals).insertOnConflictUpdate(
          GoalsCompanion(
            id: Value(id),
            ownerId: Value(row['owner_id'] as String),
            parentId: Value(row['parent_id'] as String?),
            rootId: Value((row['root_id'] as String?) ?? id),
            path: Value((row['path'] as String?) ?? id),
            depth: Value((row['depth'] as num?)?.toInt() ?? 0),
            title: Value(row['title'] as String),
            description: Value(row['description'] as String?),
            lifeAreaId: Value(row['life_area_id'] as String?),
            categoryId: Value(row['category_id'] as String?),
            status: Value(row['status'] as String? ?? 'active'),
            xpTarget: Value((row['xp_target'] as num?)?.toInt()),
            progress: Value((row['progress'] as num?)?.toDouble() ?? 0.0),
            dueDate: Value(row['target_date'] != null ? DateTime.parse(row['target_date'] as String) : null),
            completedAt: Value(row['completed_at'] != null ? DateTime.parse(row['completed_at'] as String) : null),
            deletedAt: Value(row['deleted_at'] != null ? DateTime.parse(row['deleted_at'] as String) : null),
            versionHlc: Value(remoteHlc),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
            updatedAt: Value(DateTime.parse(row['updated_at'] as String)),
          ),
        );
      }

      // 4. Projects
      final remoteProjects = await _client.from('projects').select().eq('owner_id', userId);
      for (final row in (remoteProjects as List)) {
        final id = row['id'] as String;
        final key = 'projects:$id';
        if (tombstonedKeys.contains(key) || pendingKeys.contains(key)) continue;
        final remoteHlc = row['version_hlc'] as String;
        final local = await (database.select(database.projects)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (local != null && Hlc.parse(remoteHlc).compareTo(Hlc.parse(local.versionHlc)) <= 0) {
          continue;
        }
        await database.into(database.projects).insertOnConflictUpdate(
          ProjectsCompanion(
            id: Value(id),
            ownerId: Value(row['owner_id'] as String),
            goalId: Value(row['goal_id'] as String?),
            lifeAreaId: Value(row['life_area_id'] as String?),
            title: Value(row['title'] as String),
            description: Value(row['description'] as String?),
            status: Value(row['status'] as String? ?? 'active'),
            dueDate: Value(row['due_date'] != null ? DateTime.parse(row['due_date'] as String) : null),
            memberIds: Value(row['member_ids'] is String ? row['member_ids'] as String : jsonEncode(row['member_ids'] ?? [])),
            deletedAt: Value(row['deleted_at'] != null ? DateTime.parse(row['deleted_at'] as String) : null),
            versionHlc: Value(remoteHlc),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
            updatedAt: Value(DateTime.parse(row['updated_at'] as String)),
          ),
        );
      }

      // 5. Activities
      final remoteActivities = await _client.from('activities').select().eq('owner_id', userId);
      for (final row in (remoteActivities as List)) {
        final id = row['id'] as String;
        final key = 'activities:$id';
        if (tombstonedKeys.contains(key) || pendingKeys.contains(key)) continue;
        final remoteHlc = row['version_hlc'] as String;
        final local = await (database.select(database.activities)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (local != null && Hlc.parse(remoteHlc).compareTo(Hlc.parse(local.versionHlc)) <= 0) {
          continue;
        }
        await database.into(database.activities).insertOnConflictUpdate(
          ActivitiesCompanion(
            id: Value(id),
            ownerId: Value(row['owner_id'] as String),
            lifeAreaId: Value(row['life_area_id'] as String?),
            categoryId: Value(row['category_id'] as String?),
            projectId: Value(row['project_id'] as String?),
            name: Value(row['name'] as String),
            description: Value(row['description'] as String?),
            targetDurationMinutes: Value((row['target_duration_minutes'] as num?)?.toInt()),
            difficulty: Value((row['difficulty'] as num?)?.toInt() ?? 5),
            deletedAt: Value(row['deleted_at'] != null ? DateTime.parse(row['deleted_at'] as String) : null),
            versionHlc: Value(remoteHlc),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
            updatedAt: Value(DateTime.parse(row['updated_at'] as String)),
          ),
        );
      }

      // 6. Sessions
      final remoteSessions = await _client.from('sessions').select().eq('owner_id', userId);
      for (final row in (remoteSessions as List)) {
        final id = row['id'] as String;
        final key = 'sessions:$id';
        if (tombstonedKeys.contains(key) || pendingKeys.contains(key)) continue;
        final remoteHlc = row['version_hlc'] as String;
        final local = await (database.select(database.sessions)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (local != null && Hlc.parse(remoteHlc).compareTo(Hlc.parse(local.versionHlc)) <= 0) {
          continue;
        }
        await database.into(database.sessions).insertOnConflictUpdate(
          SessionsCompanion(
            id: Value(id),
            ownerId: Value(row['owner_id'] as String),
            taskId: Value(row['task_id'] as String?),
            activityId: Value(row['activity_id'] as String?),
            startedAt: Value(DateTime.parse(row['started_at'] as String)),
            endedAt: Value(row['ended_at'] != null ? DateTime.parse(row['ended_at'] as String) : null),
            durationMs: Value((row['duration_ms'] as num?)?.toInt()),
            note: Value(row['note'] as String?),
            lifeAreaId: Value(row['life_area_id'] as String?),
            deletedAt: Value(row['deleted_at'] != null ? DateTime.parse(row['deleted_at'] as String) : null),
            versionHlc: Value(remoteHlc),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
            updatedAt: Value(DateTime.parse(row['updated_at'] as String)),
          ),
        );
      }

      // 7. Categories
      final remoteCategories = await _client.from('categories').select().eq('owner_id', userId);
      for (final row in (remoteCategories as List)) {
        final id = row['id'] as String;
        final key = 'categories:$id';
        if (tombstonedKeys.contains(key) || pendingKeys.contains(key)) continue;
        final remoteHlc = row['version_hlc'] as String;
        final local = await (database.select(database.categories)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (local != null && Hlc.parse(remoteHlc).compareTo(Hlc.parse(local.versionHlc)) <= 0) {
          continue;
        }
        await database.into(database.categories).insertOnConflictUpdate(
          CategoriesCompanion(
            id: Value(id),
            ownerId: Value(row['owner_id'] as String),
            name: Value(row['name'] as String),
            categoryType: Value(row['category_type'] as String? ?? 'goal'),
            description: Value(row['description'] as String?),
            icon: Value(row['icon'] as String?),
            baseXp: Value((row['base_xp'] as num?)?.toInt() ?? 0),
            isImmutable: Value(row['is_immutable'] as bool? ?? false),
            sortOrder: Value((row['sort_order'] as num?)?.toInt() ?? 0),
            archivedAt: Value(row['archived_at'] != null ? DateTime.parse(row['archived_at'] as String) : null),
            versionHlc: Value(remoteHlc),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
            updatedAt: Value(DateTime.parse(row['updated_at'] as String)),
          ),
        );
      }

      // 8. Life Areas
      final remoteLifeAreas = await _client.from('life_areas').select().eq('owner_id', userId);
      for (final row in (remoteLifeAreas as List)) {
        final id = row['id'] as String;
        final key = 'life_areas:$id';
        if (tombstonedKeys.contains(key) || pendingKeys.contains(key)) continue;
        final remoteHlc = row['version_hlc'] as String;
        final local = await (database.select(database.lifeAreas)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (local != null && Hlc.parse(remoteHlc).compareTo(Hlc.parse(local.versionHlc)) <= 0) {
          continue;
        }
        await database.into(database.lifeAreas).insertOnConflictUpdate(
          LifeAreasCompanion(
            id: Value(id),
            ownerId: Value(row['owner_id'] as String),
            name: Value(row['name'] as String),
            description: Value(row['description'] as String?),
            color: Value(row['color'] as String?),
            icon: Value(row['icon'] as String?),
            sortOrder: Value((row['sort_order'] as num?)?.toInt() ?? 0),
            archivedAt: Value(row['archived_at'] != null ? DateTime.parse(row['archived_at'] as String) : null),
            deletedAt: Value(row['deleted_at'] != null ? DateTime.parse(row['deleted_at'] as String) : null),
            versionHlc: Value(remoteHlc),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
            updatedAt: Value(DateTime.parse(row['updated_at'] as String)),
          ),
        );
      }

      // 9. Skills
      final remoteSkills = await _client.from('skills').select().eq('owner_id', userId);
      for (final row in (remoteSkills as List)) {
        final id = row['id'] as String;
        final key = 'skills:$id';
        if (tombstonedKeys.contains(key) || pendingKeys.contains(key)) continue;
        final remoteHlc = row['version_hlc'] as String;
        final local = await (database.select(database.skills)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (local != null && Hlc.parse(remoteHlc).compareTo(Hlc.parse(local.versionHlc)) <= 0) {
          continue;
        }
        await database.into(database.skills).insertOnConflictUpdate(
          SkillsCompanion(
            id: Value(id),
            ownerId: Value(row['owner_id'] as String),
            name: Value(row['name'] as String),
            description: Value(row['description'] as String?),
            groupId: Value(row['group_id'] as String?),
            xpTotal: Value((row['xp_total'] as num?)?.toInt() ?? 0),
            level: Value((row['level'] as num?)?.toInt() ?? 1),
            masteryLevel: Value((row['mastery_level'] as num?)?.toInt() ?? 1),
            icon: Value(row['icon'] as String?),
            archivedAt: Value(row['archived_at'] != null ? DateTime.parse(row['archived_at'] as String) : null),
            deletedAt: Value(row['deleted_at'] != null ? DateTime.parse(row['deleted_at'] as String) : null),
            versionHlc: Value(remoteHlc),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
            updatedAt: Value(DateTime.parse(row['updated_at'] as String)),
          ),
        );
      }

      // 10. XP Ledger (Append-only)
      final remoteLedger = await _client.from('xp_ledger').select().eq('owner_id', userId);
      for (final row in (remoteLedger as List)) {
        final id = row['id'] as String;
        final idempotencyKey = row['idempotency_key'] as String;
        final existing = await (database.select(database.xpLedger)
              ..where((t) => t.id.equals(id) | t.idempotencyKey.equals(idempotencyKey)))
            .getSingleOrNull();
        if (existing != null) continue;
        await database.into(database.xpLedger).insertOnConflictUpdate(
          XpLedgerCompanion(
            id: Value(id),
            ownerId: Value(row['owner_id'] as String),
            idempotencyKey: Value(idempotencyKey),
            sourceType: Value(row['source_type'] as String),
            sourceId: Value(row['source_id'] as String),
            action: Value(row['action'] as String),
            points: Value((row['points'] as num).toInt()),
            basePoints: Value((row['base_points'] as num?)?.toInt()),
            bonusPoints: Value((row['bonus_points'] as num?)?.toInt() ?? 0),
            latePenalty: Value((row['late_penalty'] as num?)?.toInt() ?? 0),
            streakBonus: Value((row['streak_bonus'] as num?)?.toInt() ?? 0),
            categoryRuleVersionId: Value(row['category_rule_version_id'] as String?),
            reversalEventId: Value(row['reversal_event_id'] as String?),
            versionHlc: Value(row['version_hlc'] as String),
            deviceId: Value(row['device_id'] as String),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
          ),
        );
      }

      // 11. Decisions
      final remoteDecisions = await _client.from('decisions').select().eq('owner_id', userId);
      for (final row in (remoteDecisions as List)) {
        final id = row['id'] as String;
        final key = 'decisions:$id';
        if (tombstonedKeys.contains(key) || pendingKeys.contains(key)) continue;
        final remoteHlc = row['version_hlc'] as String;
        final local = await (database.select(database.decisions)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (local != null && Hlc.parse(remoteHlc).compareTo(Hlc.parse(local.versionHlc)) <= 0) {
          continue;
        }
        await database.into(database.decisions).insertOnConflictUpdate(
          DecisionsCompanion(
            id: Value(id),
            ownerId: Value(row['owner_id'] as String),
            title: Value(row['title'] as String),
            content: Value(row['content'] as String?),
            status: Value(row['status'] as String? ?? 'pending'),
            goalId: Value(row['goal_id'] as String?),
            projectId: Value(row['project_id'] as String?),
            lifeAreaId: Value(row['life_area_id'] as String?),
            categoryId: Value(row['category_id'] as String?),
            resolvedAt: Value(row['resolved_at'] != null ? DateTime.parse(row['resolved_at'] as String) : null),
            deletedAt: Value(row['deleted_at'] != null ? DateTime.parse(row['deleted_at'] as String) : null),
            deletedBy: Value(row['deleted_by'] as String?),
            deletedReason: Value(row['deleted_reason'] as String?),
            versionHlc: Value(remoteHlc),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
            updatedAt: Value(DateTime.parse(row['updated_at'] as String)),
          ),
        );
      }

      // 12. Activity Events (Generic lifecycle event stream)
      final remoteActivityEvents = await _client.from('activity_events').select().eq('owner_id', userId);
      for (final row in (remoteActivityEvents as List)) {
        final id = row['id'] as String;
        final existing = await (database.select(database.activityEvents)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (existing != null) continue;
        await database.into(database.activityEvents).insertOnConflictUpdate(
          ActivityEventsCompanion(
            id: Value(id),
            ownerId: Value(row['owner_id'] as String),
            eventType: Value(row['event_type'] as String),
            entityType: Value(row['entity_type'] as String),
            entityId: Value(row['entity_id'] as String?),
            lifeAreaId: Value(row['life_area_id'] as String?),
            metadata: Value(row['metadata'] is String ? row['metadata'] as String : jsonEncode(row['metadata'] ?? {})),
            occurredAt: Value(DateTime.parse(row['occurred_at'] as String)),
            versionHlc: Value(row['version_hlc'] as String),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
          ),
        );
      }

      // 13. XP Ledger (Append-only immutable point transactions)
      final remoteXpLedger = await _client.from('xp_ledger').select().eq('owner_id', userId);
      for (final row in (remoteXpLedger as List)) {
        final id = row['id'] as String;
        final existing = await (database.select(database.xpLedger)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (existing != null) continue;
        await database.into(database.xpLedger).insertOnConflictUpdate(
          XpLedgerCompanion(
            id: Value(id),
            ownerId: Value(row['owner_id'] as String),
            idempotencyKey: Value(row['idempotency_key'] as String),
            sourceType: Value(row['source_type'] as String),
            sourceId: Value(row['source_id'] as String),
            action: Value(row['action'] as String),
            points: Value((row['points'] as num).toInt()),
            basePoints: Value(row['base_points'] != null ? (row['base_points'] as num).toInt() : null),
            bonusPoints: Value((row['bonus_points'] as num?)?.toInt() ?? 0),
            latePenalty: Value((row['late_penalty'] as num?)?.toInt() ?? 0),
            streakBonus: Value((row['streak_bonus'] as num?)?.toInt() ?? 0),
            categoryRuleVersionId: Value(row['category_rule_version_id'] as String?),
            reversalEventId: Value(row['reversal_event_id'] as String?),
            versionHlc: Value(row['version_hlc'] as String),
            deviceId: Value(row['device_id'] as String),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
          ),
        );
      }

      // 14. XP Allocation Lines (Per-life-area allocations)
      final remoteAllocationLines = await _client.from('xp_allocation_lines').select();
      for (final row in (remoteAllocationLines as List)) {
        final id = row['id'] as String;
        final existing = await (database.select(database.xpAllocationLines)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (existing != null) continue;
        await database.into(database.xpAllocationLines).insertOnConflictUpdate(
          XpAllocationLinesCompanion(
            id: Value(id),
            ledgerId: Value(row['ledger_id'] as String),
            lifeAreaId: Value(row['life_area_id'] as String),
            allocatedPoints: Value((row['allocated_points'] as num).toInt()),
            percentage: Value((row['percentage'] as num).toDouble()),
            versionHlc: Value(row['version_hlc'] as String),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
          ),
        );
      }

      // 15. User Streaks (Per-life-area streak projections)
      final remoteStreaks = await _client.from('user_streaks').select().eq('user_id', userId);
      for (final row in (remoteStreaks as List)) {
        final lifeAreaId = row['life_area_id'] as String;
        await database.into(database.userStreaks).insertOnConflictUpdate(
          UserStreaksCompanion(
            userId: Value(row['user_id'] as String),
            lifeAreaId: Value(lifeAreaId),
            currentStreak: Value((row['current_streak'] as num).toInt()),
            longestStreak: Value((row['longest_streak'] as num).toInt()),
            lastActiveDate: Value(row['last_active_date'] != null ? DateTime.parse(row['last_active_date'] as String) : null),
            lastActiveHlc: Value(row['last_active_hlc'] as String?),
            updatedAt: Value(DateTime.parse(row['updated_at'] as String)),
          ),
        );
      }

      // 16. Notifications (Phase 7 in-app alerts and notifications)
      try {
        final remoteNotifications = await _client.from('notifications').select().eq('owner_id', userId);
        final notifDao = NotificationsDao(database);
        await notifDao.ensureTableExists();

        for (final row in (remoteNotifications as List)) {
          final id = row['id'] as String;
          final remoteHlc = row['version_hlc'] as String;
          final local = await notifDao.getById(id);
          if (local != null && Hlc.parse(remoteHlc).compareTo(Hlc.parse(local.versionHlc)) <= 0) {
            continue;
          }
          await notifDao.upsertNotification(
            NotificationRecord.fromJson(row as Map<String, dynamic>),
            enqueueOutbox: false,
          );
        }
      } catch (_) {}

      // Update cursor watermark
      await database.syncDao.updateCursor(
        userId,
        deviceId,
        'global',
        Hlc.now(Id(deviceId)).toString(),
      );
    } on PostgrestException catch (error) {
      final code = error.code ?? 'postgrest_error';
      throw SyncTransportException(
        message: error.message,
        code: code,
        retryable: true,
      );
    } catch (error) {
      if (error is SyncTransportException) rethrow;
      throw SyncTransportException(
        message: error.toString(),
        code: 'transport_error',
        retryable: true,
      );
    }
  }
}
