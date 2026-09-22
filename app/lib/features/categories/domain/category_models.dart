// ignore_for_file: public_member_api_docs
// Wave 8: Category domain entities.
// ADR-003: SCD Type 2 rule versioning — changing XP/actions never rewrites history.
// Invariant #9: Category rule changes create a new version; historical XP rows are immutable.

import 'dart:convert';

import '../../../domain/errors.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../../../domain/timestamps.dart';

// ---------------------------------------------------------------------------
// CategoryAction — a single XP action variant (e.g. "Quick practice +10%")
// ---------------------------------------------------------------------------

/// A time-bounded rule for a single action within a category.
/// Once [effectiveUntil] is set, this version is closed; create a new one.
class CategoryActionEntity {
  final Id id;
  final Id categoryId;
  final String actionName;

  /// Percent modifier applied ON TOP of the category base_xp.
  /// e.g. 0.10 = +10%.  Negative values represent penalties.
  final double modifierPercent;
  final Iso8601Timestamp effectiveFrom;
  final Iso8601Timestamp? effectiveUntil;

  const CategoryActionEntity({
    required this.id,
    required this.categoryId,
    required this.actionName,
    required this.modifierPercent,
    required this.effectiveFrom,
    this.effectiveUntil,
  });

  bool get isActive => effectiveUntil == null;

  /// Effective XP bonus/penalty in absolute points for [baseXp].
  int effectiveXpDelta(int baseXp) => (baseXp * modifierPercent).round();
}

// ---------------------------------------------------------------------------
// CategoryXpRuleSnapshot — immutable JSON snapshot stored in rule versions.
// ---------------------------------------------------------------------------

class CategoryXpRuleSnapshot {
  final int baseXp;
  final List<({String actionName, double modifierPercent})> actions;

  const CategoryXpRuleSnapshot({required this.baseXp, required this.actions});

  factory CategoryXpRuleSnapshot.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final rawActions = (map['actions'] as List<dynamic>? ?? []);
    return CategoryXpRuleSnapshot(
      baseXp: (map['base_xp'] as num).toInt(),
      actions: rawActions.map((a) {
        final am = a as Map<String, dynamic>;
        return (
          actionName: am['action_name'] as String,
          modifierPercent: (am['modifier_percent'] as num).toDouble(),
        );
      }).toList(),
    );
  }

  String toJson() => jsonEncode({
        'base_xp': baseXp,
        'actions': actions
            .map((a) => {
                  'action_name': a.actionName,
                  'modifier_percent': a.modifierPercent,
                })
            .toList(),
      });
}

// ---------------------------------------------------------------------------
// CategoryRuleVersionEntity — immutable audit row (Invariant #9)
// ---------------------------------------------------------------------------

class CategoryRuleVersionEntity {
  final Id id;
  final Id categoryId;
  final CategoryXpRuleSnapshot snapshot;
  final Iso8601Timestamp effectiveFrom;
  final Iso8601Timestamp? effectiveUntil;
  final Iso8601Timestamp createdAt;

  const CategoryRuleVersionEntity({
    required this.id,
    required this.categoryId,
    required this.snapshot,
    required this.effectiveFrom,
    required this.createdAt,
    this.effectiveUntil,
  });

  bool get isActive => effectiveUntil == null;
}

// ---------------------------------------------------------------------------
// Category — aggregate root
// ---------------------------------------------------------------------------

class Category {
  final Id id;
  final Id ownerId;
  final String name;
  final int baseXp;

  /// System-provided categories (e.g. "Health", "Work") cannot be deleted.
  final bool isImmutable;
  final int sortOrder;
  final Iso8601Timestamp? archivedAt;
  final Hlc versionHlc;
  final Iso8601Timestamp createdAt;
  final Iso8601Timestamp updatedAt;

  Category({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.baseXp,
    required this.isImmutable,
    required this.versionHlc,
    required this.createdAt,
    required this.updatedAt,
    this.sortOrder = 0,
    this.archivedAt,
  }) {
    if (baseXp < 0) {
      throw ValidationError('baseXp', 'baseXp must be >= 0; got $baseXp');
    }
  }

  bool get isArchived => archivedAt != null;
  bool get isActive => !isArchived;

  /// Archive a category — cannot archive immutable system categories.
  Category archive(Hlc newHlc) {
    if (isImmutable) {
      throw ConflictError('Cannot archive an immutable system Category');
    }
    if (isArchived) {
      throw ConflictError('Category is already archived');
    }
    return Category(
      id: id,
      ownerId: ownerId,
      name: name,
      baseXp: baseXp,
      isImmutable: isImmutable,
      sortOrder: sortOrder,
      archivedAt: Iso8601Timestamp.now(),
      versionHlc: newHlc,
      createdAt: createdAt,
      updatedAt: Iso8601Timestamp.now(),
    );
  }

  /// Rename — immutable categories CAN be renamed by their owner.
  Category rename(String newName, Hlc newHlc) {
    _requireActive();
    return Category(
      id: id,
      ownerId: ownerId,
      name: newName,
      baseXp: baseXp,
      isImmutable: isImmutable,
      sortOrder: sortOrder,
      archivedAt: archivedAt,
      versionHlc: newHlc,
      createdAt: createdAt,
      updatedAt: Iso8601Timestamp.now(),
    );
  }

  /// Changing baseXp publishes a new rule version (ADR-003).
  /// The caller is responsible for calling [CategoriesDao.publishNewRuleVersion].
  Category updateBaseXp(int newBaseXp, Hlc newHlc) {
    _requireActive();
    if (newBaseXp < 0) {
      throw ValidationError('baseXp', 'baseXp must be >= 0; got $newBaseXp');
    }
    return Category(
      id: id,
      ownerId: ownerId,
      name: name,
      baseXp: newBaseXp,
      isImmutable: isImmutable,
      sortOrder: sortOrder,
      archivedAt: archivedAt,
      versionHlc: newHlc,
      createdAt: createdAt,
      updatedAt: Iso8601Timestamp.now(),
    );
  }

  void _requireActive() {
    if (isArchived) {
      throw ConflictError('Cannot modify an archived Category');
    }
  }
}
