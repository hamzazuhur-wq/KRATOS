import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../domain/errors.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../../../domain/timestamps.dart';
import '../domain/skill_models.dart';
import 'skills_dao.dart';

abstract interface class SkillsRepository {
  Future<List<Skill>> listSkills(
    String ownerId, {
    String? query,
    String? groupId,
    int? masteryLevel,
    String? lifeAreaId,
  });
  Future<List<SkillGroup>> listGroups(
    String ownerId, {
    bool includeArchived = false,
  });
  Future<String> createSkill({
    required String ownerId,
    required String name,
    String? description,
    String? groupId,
    int masteryLevel = 1,
  });
  Future<void> updateSkill({
    required Skill skill,
    required String name,
    String? description,
    String? groupId,
    required int masteryLevel,
  });
  Future<void> archiveSkill(Skill skill);
  Future<void> restoreSkill(Skill skill);
  Future<void> createGroup({required String ownerId, required String name});
  Future<void> renameGroup({required SkillGroup group, required String name});
  Future<void> archiveGroup(SkillGroup group);
  Future<void> restoreGroup(SkillGroup group);
  Future<void> attachSkillToLifeArea({
    required String ownerId,
    required String skillId,
    required String lifeAreaId,
  });
  Future<void> removeSkillFromLifeArea(String skillId, String lifeAreaId);
}

class DriftSkillsRepository implements SkillsRepository {
  final AppDatabase database;
  final String deviceId;
  DriftSkillsRepository(this.database, {this.deviceId = 'local_device'});
  SkillsDao get _dao => database.skillsDao;

  @override
  Future<List<Skill>> listSkills(
    String ownerId, {
    String? query,
    String? groupId,
    int? masteryLevel,
    String? lifeAreaId,
  }) => _dao.listSkills(
    ownerId,
    query: query,
    groupId: groupId,
    masteryLevel: masteryLevel,
    lifeAreaId: lifeAreaId,
  );

  @override
  Future<List<SkillGroup>> listGroups(
    String ownerId, {
    bool includeArchived = false,
  }) => _dao.listGroups(ownerId, includeArchived: includeArchived);

  @override
  Future<String> createSkill({
    required String ownerId,
    required String name,
    String? description,
    String? groupId,
    int masteryLevel = 1,
  }) async {
    final id = Id.uuidV7();
    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(id);
    final entity = SkillEntity(
      id: id,
      ownerId: Id.fromString(ownerId),
      name: name,
      description: description,
      groupId: groupId == null ? null : Id.fromString(groupId),
      xpTotal: 0,
      level: 1,
      masteryLevel: masteryLevel,
      versionHlc: hlc,
      createdAt: Iso8601Timestamp.fromDateTime(now),
      updatedAt: Iso8601Timestamp.fromDateTime(now),
    );
    await _dao.upsert(
      SkillsCompanion.insert(
        id: entity.id.value,
        ownerId: entity.ownerId.value,
        name: entity.name,
        description: Value(entity.description),
        groupId: Value(entity.groupId?.value),
        xpTotal: 0,
        level: 1,
        masteryLevel: Value(entity.masteryLevel),
        icon: const Value(null),
        versionHlc: hlc.toString(),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _enqueue(
      ownerId: ownerId,
      op: 'insert',
      entity: 'skills',
      entityId: id.value,
      hlc: hlc,
      payload: {
        'name': name,
        'description': description,
        'group_id': groupId,
        'xp_total': 0,
        'level': 1,
        'mastery_level': masteryLevel,
        'created_at': now.toIso8601String(),
      },
    );
    return id.value;
  }

  @override
  Future<void> updateSkill({
    required Skill skill,
    required String name,
    String? description,
    String? groupId,
    required int masteryLevel,
  }) async {
    final hlc = Hlc.now(Id.uuidV7());
    await _dao.upsert(
      skill
          .toCompanion(true)
          .copyWith(
            name: Value(name.trim()),
            description: Value(description),
            groupId: Value(groupId),
            masteryLevel: Value(masteryLevel),
            versionHlc: Value(hlc.toString()),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
    );
    await _enqueue(
      ownerId: skill.ownerId,
      op: 'update',
      entity: 'skills',
      entityId: skill.id,
      hlc: hlc,
      payload: {
        'name': name.trim(),
        'description': description,
        'group_id': groupId,
        'mastery_level': masteryLevel,
      },
    );
  }

  @override
  Future<void> archiveSkill(Skill skill) async {
    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id.uuidV7());
    await (database.update(
      database.skills,
    )..where((s) => s.id.equals(skill.id))).write(
      SkillsCompanion(
        archivedAt: Value(now),
        versionHlc: Value(hlc.toString()),
        updatedAt: Value(now),
      ),
    );
    await _enqueue(
      ownerId: skill.ownerId,
      op: 'update',
      entity: 'skills',
      entityId: skill.id,
      hlc: hlc,
      payload: {'archived_at': now.toIso8601String()},
    );
  }

  @override
  Future<void> restoreSkill(Skill skill) async {
    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id.uuidV7());
    await (database.update(
      database.skills,
    )..where((s) => s.id.equals(skill.id))).write(
      SkillsCompanion(
        archivedAt: const Value(null),
        versionHlc: Value(hlc.toString()),
        updatedAt: Value(now),
      ),
    );
    await _enqueue(
      ownerId: skill.ownerId,
      op: 'update',
      entity: 'skills',
      entityId: skill.id,
      hlc: hlc,
      payload: {'archived_at': null},
    );
  }

  @override
  Future<void> createGroup({
    required String ownerId,
    required String name,
  }) async {
    final id = Id.uuidV7();
    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(id);
    await _dao.upsertGroup(
      SkillGroupsCompanion.insert(
        id: id.value,
        ownerId: ownerId,
        name: name.trim(),
        versionHlc: hlc.toString(),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _enqueue(
      ownerId: ownerId,
      op: 'insert',
      entity: 'skill_groups',
      entityId: id.value,
      hlc: hlc,
      payload: {'name': name.trim(), 'created_at': now.toIso8601String()},
    );
  }

  @override
  Future<void> renameGroup({
    required SkillGroup group,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ValidationError('name', 'Group name is required');
    }
    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id.uuidV7());
    await _dao.upsertGroup(
      group
          .toCompanion(true)
          .copyWith(
            name: Value(trimmed),
            versionHlc: Value(hlc.toString()),
            updatedAt: Value(now),
          ),
    );
    await _enqueue(
      ownerId: group.ownerId,
      op: 'update',
      entity: 'skill_groups',
      entityId: group.id,
      hlc: hlc,
      payload: {'name': trimmed},
    );
  }

  @override
  Future<void> archiveGroup(SkillGroup group) async {
    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id.uuidV7());
    await _dao.archiveGroup(group.id, hlc.toString());
    await _enqueue(
      ownerId: group.ownerId,
      op: 'update',
      entity: 'skill_groups',
      entityId: group.id,
      hlc: hlc,
      payload: {'archived_at': now.toIso8601String()},
    );
  }

  @override
  Future<void> restoreGroup(SkillGroup group) async {
    final hlc = Hlc.now(Id.uuidV7());
    await _dao.restoreGroup(group.id, hlc.toString());
    await _enqueue(
      ownerId: group.ownerId,
      op: 'update',
      entity: 'skill_groups',
      entityId: group.id,
      hlc: hlc,
      payload: {'archived_at': null},
    );
  }

  @override
  Future<void> attachSkillToLifeArea({
    required String ownerId,
    required String skillId,
    required String lifeAreaId,
  }) async {
    final hlc = Hlc.now(Id.uuidV7());
    await _dao.attachToLifeArea(
      ownerId: ownerId,
      skillId: skillId,
      lifeAreaId: lifeAreaId,
      versionHlc: hlc.toString(),
    );
    await _enqueue(
      ownerId: ownerId,
      op: 'insert',
      entity: 'skill_life_area_links',
      entityId: skillId,
      hlc: hlc,
      payload: {'skill_id': skillId, 'life_area_id': lifeAreaId},
    );
  }

  @override
  Future<void> removeSkillFromLifeArea(
    String skillId,
    String lifeAreaId,
  ) async {
    await _dao.removeFromLifeArea(skillId, lifeAreaId);
    final skill = await _dao.findById(skillId);
    if (skill != null) {
      await _enqueue(
        ownerId: skill.ownerId,
        op: 'delete',
        entity: 'skill_life_area_links',
        entityId: skillId,
        hlc: Hlc.now(Id.uuidV7()),
        payload: {'skill_id': skillId, 'life_area_id': lifeAreaId},
      );
    }
  }

  Future<void> _enqueue({
    required String ownerId,
    required String op,
    required String entity,
    required String entityId,
    required Hlc hlc,
    required Map<String, Object?> payload,
  }) async {
    await database
        .into(database.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            userId: ownerId,
            op: op,
            entity: entity,
            entityId: entityId,
            payloadJson: jsonEncode(payload),
            hlc: hlc.toString(),
            deviceId: deviceId,
          ),
        );
  }
}
