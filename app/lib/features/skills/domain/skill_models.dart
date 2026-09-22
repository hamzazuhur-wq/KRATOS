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

  /// Denormalized XP cache — updated by XpLedgerWriter after allocation.
  final int xpTotal;

  /// Denormalized skill level — derived from [xpTotal] using progression curves.
  final int level;
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
  }

  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;
  bool get isActive => !isArchived && !isDeleted;

  SkillEntity rename(String newName, Hlc newHlc) {
    _requireActive();
    return SkillEntity(
      id: id,
      ownerId: ownerId,
      name: newName,
      description: description,
      xpTotal: xpTotal,
      level: level,
      icon: icon,
      archivedAt: archivedAt,
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
      xpTotal: xpTotal,
      level: level,
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
}
