// ignore_for_file: public_member_api_docs
// Wave 8: Skill & Tool domain entities.
// ADR-004: Tools are inventory items; Skills are XP-graded competencies.
// Invariant #4:  skill_id on xp_ledger is attribution metadata ONLY — XP belongs to LifeArea.
// Invariant #10: Soft-deleting a skill preserves historical XP audit chain.

import '../../../domain/errors.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../../../domain/timestamps.dart';

// ---------------------------------------------------------------------------
// ToolEntity — physical/digital inventory item (software, equipment, etc.)
// ---------------------------------------------------------------------------

/// Represents a reusable tool that can be linked to Skills and Tasks.
class ToolEntity {
  final Id id;
  final Id ownerId;
  final String name;
  final String? description;

  /// Arbitrary classification — e.g. "software", "hardware", "methodology".
  final String toolType;
  final Iso8601Timestamp? archivedAt;
  final Iso8601Timestamp? deletedAt;
  final Hlc versionHlc;
  final Iso8601Timestamp createdAt;
  final Iso8601Timestamp updatedAt;

  ToolEntity({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.toolType,
    required this.versionHlc,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.archivedAt,
    this.deletedAt,
  }) {
    if (name.trim().isEmpty) {
      throw ValidationError('name', 'Tool name must not be blank');
    }
  }

  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;
  bool get isActive => !isArchived && !isDeleted;

  ToolEntity rename(String newName, Hlc newHlc) {
    _requireActive();
    return ToolEntity(
      id: id,
      ownerId: ownerId,
      name: newName,
      description: description,
      toolType: toolType,
      archivedAt: archivedAt,
      deletedAt: deletedAt,
      versionHlc: newHlc,
      createdAt: createdAt,
      updatedAt: Iso8601Timestamp.now(),
    );
  }

  ToolEntity softDelete(Id deletedBy, Hlc newHlc) {
    if (isDeleted) throw ConflictError('Tool is already deleted');
    return ToolEntity(
      id: id,
      ownerId: ownerId,
      name: name,
      description: description,
      toolType: toolType,
      archivedAt: archivedAt,
      deletedAt: Iso8601Timestamp.now(),
      versionHlc: newHlc,
      createdAt: createdAt,
      updatedAt: Iso8601Timestamp.now(),
    );
  }

  void _requireActive() {
    if (isDeleted) throw ConflictError('Cannot modify a deleted Tool');
    if (isArchived) throw ConflictError('Cannot modify an archived Tool');
  }
}

// ---------------------------------------------------------------------------
// SkillEntity — XP-graded competency (not an XP owner itself)
// ---------------------------------------------------------------------------

/// Independent five-step Skill mastery contract. This is intentionally
/// separate from Life Area level/tier and from the XP attribution cache.
enum SkillMastery {
  beginner(1, 'BEGINNER', 'Ⅰ'),
  basic(2, 'BASIC', 'Ⅱ'),
  advanced(3, 'ADVANCED', 'Ⅲ'),
  expert(4, 'EXPERT', 'Ⅳ'),
  master(5, 'MASTER', 'Ⅴ');

  const SkillMastery(this.value, this.label, this.roman);
  final int value;
  final String label;
  final String roman;

  static SkillMastery fromValue(int value) => SkillMastery.values.firstWhere(
    (mastery) => mastery.value == value,
    orElse: () => throw ValidationError(
      'masteryLevel',
      'Mastery level must be between 1 and 5; got $value',
    ),
  );
}

/// Persistent classification for Skills. Groups are owned entities, not tags.
class SkillGroupEntity {
  final Id id;
  final Id ownerId;
  final String name;
  final String? description;
  final Iso8601Timestamp? archivedAt;
  final Iso8601Timestamp? deletedAt;
  final Hlc versionHlc;
  final Iso8601Timestamp createdAt;
  final Iso8601Timestamp updatedAt;

  SkillGroupEntity({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.versionHlc,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.archivedAt,
    this.deletedAt,
  }) {
    if (name.trim().isEmpty) {
      throw ValidationError('name', 'Skill group name must not be blank');
    }
  }

  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;
}

/// A skill represents a learned competency that earns XP attribution.
///
/// IMPORTANT (Invariant #4): `xpTotal` and `level` here are denormalized
/// caches for display only. The authoritative XP source is always
/// `xp_allocation_lines` grouped by `skill_id`. Never write XP directly
/// to a Skill row — always go through [XpLedgerWriter].
class SkillEntity {
  final Id id;
  final Id ownerId;
  final String name;
  final String? description;
  final Id? groupId;

  /// Denormalized XP cache — updated by XpLedgerWriter after allocation.
  final int xpTotal;

  /// Denormalized skill level — derived from [xpTotal] using progression curves.
  final int level;
  final int masteryLevel;
  final String? icon;
  final Iso8601Timestamp? archivedAt;
  final Iso8601Timestamp? deletedAt;
  final Hlc versionHlc;
  final Iso8601Timestamp createdAt;
  final Iso8601Timestamp updatedAt;

  SkillEntity({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.xpTotal,
    required this.level,
    this.masteryLevel = 1,
    this.groupId,
    required this.versionHlc,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.icon,
    this.archivedAt,
    this.deletedAt,
  }) {
    if (name.trim().isEmpty) {
      throw ValidationError('name', 'Skill name must not be blank');
    }
    if (xpTotal < 0) {
      throw ValidationError('xpTotal', 'xpTotal must be >= 0; got $xpTotal');
    }
    if (level < 0) {
      throw ValidationError('level', 'Skill level must be >= 0; got $level');
    }
    SkillMastery.fromValue(masteryLevel);
  }

  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;
  bool get isActive => !isArchived && !isDeleted;
  SkillMastery get mastery => SkillMastery.fromValue(masteryLevel);

  SkillEntity rename(String newName, Hlc newHlc) {
    _requireActive();
    return SkillEntity(
      id: id,
      ownerId: ownerId,
      name: newName,
      description: description,
      groupId: groupId,
      xpTotal: xpTotal,
      level: level,
      masteryLevel: masteryLevel,
      icon: icon,
      archivedAt: archivedAt,
      deletedAt: deletedAt,
      versionHlc: newHlc,
      createdAt: createdAt,
      updatedAt: Iso8601Timestamp.now(),
    );
  }

  SkillEntity changeMastery(SkillMastery next, Hlc newHlc) {
    _requireActive();
    return SkillEntity(
      id: id,
      ownerId: ownerId,
      name: name,
      description: description,
      groupId: groupId,
      xpTotal: xpTotal,
      level: level,
      masteryLevel: next.value,
      icon: icon,
      archivedAt: archivedAt,
      deletedAt: deletedAt,
      versionHlc: newHlc,
      createdAt: createdAt,
      updatedAt: Iso8601Timestamp.now(),
    );
  }

  SkillEntity archive(Hlc newHlc) {
    _requireNotDeleted();
    if (isArchived) throw ConflictError('Skill is already archived');
    return SkillEntity(
      id: id,
      ownerId: ownerId,
      name: name,
      description: description,
      groupId: groupId,
      xpTotal: xpTotal,
      level: level,
      masteryLevel: masteryLevel,
      icon: icon,
      archivedAt: Iso8601Timestamp.now(),
      deletedAt: deletedAt,
      versionHlc: newHlc,
      createdAt: createdAt,
      updatedAt: Iso8601Timestamp.now(),
    );
  }

  SkillEntity restore(Hlc newHlc) {
    _requireNotDeleted();
    if (!isArchived) throw ConflictError('Skill is not archived');
    return SkillEntity(
      id: id,
      ownerId: ownerId,
      name: name,
      description: description,
      groupId: groupId,
      xpTotal: xpTotal,
      level: level,
      masteryLevel: masteryLevel,
      icon: icon,
      deletedAt: deletedAt,
      versionHlc: newHlc,
      createdAt: createdAt,
      updatedAt: Iso8601Timestamp.now(),
    );
  }

  /// Soft-delete preserves XP audit rows (Invariant #10).
  SkillEntity softDelete(Id deletedBy, Hlc newHlc) {
    if (isDeleted) throw ConflictError('Skill is already deleted');
    return SkillEntity(
      id: id,
      ownerId: ownerId,
      name: name,
      description: description,
      groupId: groupId,
      xpTotal: xpTotal,
      level: level,
      masteryLevel: masteryLevel,
      icon: icon,
      archivedAt: archivedAt,
      deletedAt: Iso8601Timestamp.now(),
      versionHlc: newHlc,
      createdAt: createdAt,
      updatedAt: Iso8601Timestamp.now(),
    );
  }

  void _requireActive() {
    if (isDeleted) throw ConflictError('Cannot modify a deleted Skill');
    if (isArchived) throw ConflictError('Cannot modify an archived Skill');
  }

  void _requireNotDeleted() {
    if (isDeleted) throw ConflictError('Cannot modify a deleted Skill');
  }
}
